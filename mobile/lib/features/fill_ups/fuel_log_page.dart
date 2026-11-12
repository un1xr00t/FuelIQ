import 'package:flutter/cupertino.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/record_controls.dart';

class FuelLogPage extends StatelessWidget {
  const FuelLogPage({super.key, required this.store, required this.openGarage});

  final FuelStore store;
  final VoidCallback openGarage;

  void _edit(BuildContext context, [FillUp? entry]) =>
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(
          builder: (_) => _FillUpEditor(store: store, entry: entry),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final data = store.data;
      final dates = CupertinoLocalizations.of(context);
      return FuelPage(
        title: 'Fuel Log',
        children: [
          if (data.fillUps.isEmpty)
            FuelEmptyState(
              icon: CupertinoIcons.drop,
              title: 'No fill-ups yet',
              message: data.vehicles.isEmpty
                  ? 'Add a vehicle in Garage before logging fuel.'
                  : 'Log your first fill-up to start building your history.',
            ),
          const SizedBox(height: FuelTheme.gap),
          CupertinoButton(
            onPressed: data.vehicles.isEmpty
                ? openGarage
                : () => _edit(context),
            child: Text(data.vehicles.isEmpty ? 'Open Garage' : 'Log fill-up'),
          ),
          for (final entry in data.fillUps) ...[
            RecordRow(
              title: '${dollars(entry.total)} · ${fixed(entry.volume, 3)} gal',
              detail: [
                data.vehicle(entry.vehicleId)!.name,
                dates.datePickerMediumDate(entry.date.toLocal()),
                entry.full ? 'Full tank' : 'Partial tank',
                if (entry.hasDiscrepancy) 'Total differs',
              ].join(' · '),
              icon: CupertinoIcons.drop,
              onPressed: () => _edit(context, entry),
            ),
            const SizedBox(height: FuelTheme.gap),
          ],
        ],
      );
    },
  );
}

class _FillUpEditor extends StatefulWidget {
  const _FillUpEditor({required this.store, this.entry});
  final FuelStore store;
  final FillUp? entry;

  @override
  State<_FillUpEditor> createState() => _FillUpEditorState();
}

class _FillUpEditorState extends State<_FillUpEditor> {
  late final _volume = TextEditingController(
    text: widget.entry == null ? '' : fixed(widget.entry!.volume, 3),
  );
  late final _price = TextEditingController(
    text: widget.entry == null ? '' : fixed(widget.entry!.price, 3),
  );
  late final _total = TextEditingController(
    text: widget.entry == null ? '' : fixed(widget.entry!.total, 2),
  );
  late final _odometer = TextEditingController(
    text: widget.entry?.odometer?.toString(),
  );
  late int _vehicleId = widget.entry?.vehicleId ?? widget.store.data.primaryId!;
  late DateTime _date = widget.entry?.date.toLocal() ?? DateTime.now();
  late bool _full = widget.entry?.full ?? true;
  bool _showDate = false;
  bool _busy = false;

  @override
  void dispose() {
    _volume.dispose();
    _price.dispose();
    _total.dispose();
    _odometer.dispose();
    super.dispose();
  }

  Future<void> _chooseVehicle() async {
    final id = await showCupertinoModalPopup<int>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Vehicle'),
        actions: [
          for (final vehicle in widget.store.data.vehicles)
            CupertinoActionSheetAction(
              isDefaultAction: vehicle.id == _vehicleId,
              onPressed: () => Navigator.pop(context, vehicle.id),
              child: Text(vehicle.name),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (mounted && id != null) setState(() => _vehicleId = id);
  }

  Future<void> _save() async {
    final volume = parseFixed(_volume.text, 3, maximum: 999999);
    final price = parseFixed(_price.text, 3, maximum: 99999);
    final total = parseFixed(_total.text, 2, maximum: 999999);
    final miles = _odometer.text.trim();
    final odometer = RegExp(r'^\d{1,7}$').hasMatch(miles)
        ? int.parse(miles)
        : null;
    if (volume == null ||
        volume <= 0 ||
        price == null ||
        price <= 0 ||
        total == null ||
        total <= 0 ||
        (miles.isNotEmpty && odometer == null)) {
      await showRecordError(
        context,
        'Enter positive gallons, price per gallon, and total paid. Use up to three decimal places for gallons and price, two for total, and whole miles for odometer.',
      );
      return;
    }
    final candidate = FillUp(
      id: 0,
      vehicleId: _vehicleId,
      date: _date,
      volume: volume,
      price: price,
      total: total,
      full: _full,
      odometer: odometer,
    );
    if (candidate.hasDiscrepancy) {
      final confirmed = await confirmRecordAction(
        context,
        title: 'Total differs',
        message:
            'Gallons × price comes to ${dollars(candidate.expectedTotal)}. You entered ${dollars(total)}.',
        action: 'Save entered total',
      );
      if (!mounted || !confirmed) return;
    }
    await _persist(
      () => widget.store.saveFillUp(
        id: widget.entry?.id,
        vehicleId: candidate.vehicleId,
        date: candidate.date,
        volume: volume,
        price: price,
        total: total,
        full: candidate.full,
        odometer: odometer,
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await confirmRecordAction(
      context,
      title: 'Delete fill-up?',
      message: 'This removes it from fuel history and spending totals.',
      action: 'Delete',
      destructive: true,
    );
    if (mounted && confirmed) {
      await _persist(() => widget.store.deleteFillUp(widget.entry!.id));
    }
  }

  Future<void> _persist(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        await showRecordError(
          context,
          'Could not save this change. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.store.data.vehicle(_vehicleId)!;
    final dateLabel = CupertinoLocalizations.of(
      context,
    ).datePickerMediumDate(_date);
    const decimal = TextInputType.numberWithOptions(decimal: true);
    return FuelPage(
      title: widget.entry == null ? 'Log fill-up' : 'Edit fill-up',
      children: [
        RecordRow(
          title: 'Vehicle',
          detail: vehicle.name,
          icon: CupertinoIcons.car_detailed,
          onPressed: _chooseVehicle,
        ),
        const SizedBox(height: FuelTheme.gap),
        RecordRow(
          title: 'Date',
          detail: dateLabel,
          icon: CupertinoIcons.calendar,
          onPressed: () => setState(() => _showDate = !_showDate),
        ),
        if (_showDate)
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _date,
              maximumDate: DateTime.now(),
              onDateTimeChanged: (date) => setState(() => _date = date),
            ),
          ),
        const SizedBox(height: FuelTheme.inset),
        RecordField(
          label: 'Gallons (US)',
          controller: _volume,
          keyboardType: decimal,
        ),
        RecordField(
          label: 'Price per gallon (USD)',
          controller: _price,
          keyboardType: decimal,
        ),
        RecordField(
          label: 'Total paid (USD)',
          controller: _total,
          keyboardType: decimal,
        ),
        RecordField(
          label: 'Odometer (mi, optional)',
          controller: _odometer,
          keyboardType: TextInputType.number,
          maxLength: 7,
        ),
        CupertinoFormRow(
          padding: EdgeInsets.zero,
          prefix: const Text('Full tank'),
          child: CupertinoSwitch(
            value: _full,
            onChanged: _busy ? null : (value) => setState(() => _full = value),
          ),
        ),
        const SizedBox(height: FuelTheme.gap),
        CupertinoButton.filled(
          onPressed: _busy ? null : _save,
          child: const Text('Save fill-up'),
        ),
        if (widget.entry != null)
          CupertinoButton(
            foregroundColor: FuelTheme.resolve(
              context,
              CupertinoColors.systemRed,
            ),
            onPressed: _busy ? null : _delete,
            child: const Text('Delete fill-up'),
          ),
      ],
    );
  }
}
