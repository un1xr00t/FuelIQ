import 'package:flutter/cupertino.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/photo_picker.dart';
import '../../design_system/record_controls.dart';
import 'vehicle_photo.dart';

class GaragePage extends StatelessWidget {
  const GaragePage({super.key, required this.store});

  final FuelStore store;

  void _edit(BuildContext context, [Vehicle? vehicle]) =>
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(
          builder: (_) => _VehicleEditor(store: store, vehicle: vehicle),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final data = store.data;
      return FuelPage(
        title: 'My Garage',
        children: [
          if (data.vehicles.isEmpty)
            const FuelEmptyState(
              icon: CupertinoIcons.car_detailed,
              title: 'No vehicles yet',
              message: 'Add a vehicle to start tracking its fuel.',
            ),
          for (final vehicle in data.vehicles) ...[
            RecordRow(
              title: vehicle.name,
              detail: [
                if (vehicle.id == data.primaryId) 'Primary',
                if (vehicle.trim.isNotEmpty) vehicle.trim,
                dollars(
                  data.fillUps
                      .where((entry) => entry.vehicleId == vehicle.id)
                      .fold(0, (sum, entry) => sum + entry.total),
                ),
              ].join(' · '),
              icon: CupertinoIcons.car_detailed,
              thumbnail: vehicle.photo == null
                  ? null
                  : VehiclePhoto(vehicle.photo!, size: 44),
              onPressed: () => _edit(context, vehicle),
            ),
            const SizedBox(height: FuelTheme.gap),
          ],
          CupertinoButton(
            onPressed: () => _edit(context),
            child: const Text('Add vehicle'),
          ),
        ],
      );
    },
  );
}

class _VehicleEditor extends StatefulWidget {
  const _VehicleEditor({required this.store, this.vehicle});
  final FuelStore store;
  final Vehicle? vehicle;

  @override
  State<_VehicleEditor> createState() => _VehicleEditorState();
}

class _VehicleEditorState extends State<_VehicleEditor> {
  late final _year = TextEditingController(
    text: widget.vehicle?.year.toString(),
  );
  late final _make = TextEditingController(text: widget.vehicle?.make);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _trim = TextEditingController(text: widget.vehicle?.trim);
  late String? _photo = widget.vehicle?.photo;
  late bool _primary =
      widget.vehicle?.id == widget.store.data.primaryId &&
      widget.vehicle != null;
  bool _busy = false;

  @override
  void dispose() {
    _year.dispose();
    _make.dispose();
    _model.dispose();
    _trim.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      final file = await showPhotoPicker(context, title: 'Vehicle photo');
      if (file == null) return;
      try {
        if (!mounted) return;
        final photo = await prepareVehiclePhoto(file);
        if (mounted) setState(() => _photo = photo);
      } finally {
        await discardPickedPhoto(file);
      }
    } on FormatException catch (error) {
      if (mounted) await showRecordError(context, error.message);
    } catch (_) {
      if (mounted) {
        await showRecordError(
          context,
          'Could not open the photo. Check camera access or choose another image.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final year = int.tryParse(_year.text.trim());
    if (year == null ||
        year < 1886 ||
        year > DateTime.now().year + 1 ||
        _make.text.trim().isEmpty ||
        _model.text.trim().isEmpty) {
      await showRecordError(context, 'Enter a valid year, make, and model.');
      return;
    }
    await _persist(
      () => widget.store.saveVehicle(
        id: widget.vehicle?.id,
        year: year,
        make: _make.text,
        model: _model.text,
        trim: _trim.text,
        photo: _photo,
        primary: _primary,
      ),
    );
  }

  Future<void> _delete() async {
    final id = widget.vehicle!.id;
    if (widget.store.data.fillUps.any((entry) => entry.vehicleId == id)) {
      await showRecordError(
        context,
        'Delete this vehicle’s fill-ups before deleting the vehicle.',
      );
      return;
    }
    final confirmed = await confirmRecordAction(
      context,
      title: 'Delete vehicle?',
      message: 'This removes its profile and photo from FuelIQ.',
      action: 'Delete',
      destructive: true,
    );
    if (mounted && confirmed) {
      await _persist(() => widget.store.deleteVehicle(id));
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
    final isPrimary =
        widget.vehicle != null &&
        widget.vehicle!.id == widget.store.data.primaryId;
    return FuelPage(
      title: widget.vehicle == null ? 'Add vehicle' : 'Edit vehicle',
      children: [
        RecordField(
          label: 'Year',
          controller: _year,
          keyboardType: TextInputType.number,
          maxLength: 4,
        ),
        RecordField(label: 'Make', controller: _make, maxLength: 60),
        RecordField(label: 'Model', controller: _model, maxLength: 60),
        RecordField(label: 'Trim (optional)', controller: _trim, maxLength: 60),
        if (widget.store.data.vehicles.isNotEmpty)
          CupertinoFormRow(
            padding: EdgeInsets.zero,
            prefix: const Text('Primary vehicle'),
            child: CupertinoSwitch(
              value: _primary,
              onChanged: _busy || isPrimary
                  ? null
                  : (value) => setState(() => _primary = value),
            ),
          ),
        if (_photo case final photo?)
          Center(child: VehiclePhoto(photo, size: 104)),
        CupertinoButton(
          onPressed: _busy ? null : _pick,
          child: Text(_photo == null ? 'Choose photo' : 'Replace photo'),
        ),
        if (_photo != null)
          CupertinoButton(
            onPressed: _busy ? null : () => setState(() => _photo = null),
            child: const Text('Remove photo'),
          ),
        CupertinoButton.filled(
          onPressed: _busy ? null : _save,
          child: const Text('Save vehicle'),
        ),
        if (widget.vehicle != null)
          CupertinoButton(
            onPressed: _busy ? null : _delete,
            foregroundColor: FuelTheme.resolve(
              context,
              CupertinoColors.systemRed,
            ),
            child: const Text('Delete vehicle'),
          ),
      ],
    );
  }
}
