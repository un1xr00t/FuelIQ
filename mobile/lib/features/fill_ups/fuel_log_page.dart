import 'package:flutter/cupertino.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/photo_picker.dart';
import '../../design_system/record_controls.dart';
import 'fuel_photo_parser.dart';
import 'fuel_photo_scanner.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class FuelLogPage extends StatelessWidget {
  const FuelLogPage({super.key, required this.store, required this.openGarage});

  final FuelStore store;
  final VoidCallback openGarage;

  void _edit(BuildContext context, {FillUp? entry, bool startScan = false}) =>
      Navigator.of(context, rootNavigator: true).push(
        CupertinoPageRoute<void>(
          builder: (_) =>
              _FillUpEditor(store: store, entry: entry, startScan: startScan),
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      final data = store.data;
      final dates = CupertinoLocalizations.of(context);
      final months = <DateTime, List<FillUp>>{};
      for (final entry in data.fillUps) {
        final day = entry.date.toLocal();
        (months[DateTime(day.year, day.month)] ??= []).add(entry);
      }
      return FuelPage(
        title: 'Fuel Log',
        header: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: FuelTheme.pearl,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${dollars(data.spending)} total',
                style: FuelTheme.rowTitle.copyWith(color: FuelTheme.pearlInk),
              ),
            ),
          ),
        ),
        children: [
          if (data.fillUps.isEmpty)
            FuelEmptyState(
              icon: CupertinoIcons.drop,
              title: 'No fill-ups yet',
              message: data.vehicles.isEmpty
                  ? 'Add a vehicle in Garage before logging fuel.'
                  : 'Log your first fill-up to start building your history.',
            ),
          if (data.vehicles.isEmpty)
            CupertinoButton(
              onPressed: openGarage,
              child: const Text('Open Garage'),
            ),
          for (final month in months.entries) ...[
            FuelSurface(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        '${dates.datePickerMonth(month.key.month)} ${dates.datePickerYear(month.key.year)}',
                        style: FuelTheme.heading,
                      ),
                    ),
                    for (final (index, entry) in month.value.indexed) ...[
                      if (index > 0)
                        Container(
                          height: 1,
                          color: FuelTheme.resolve(context, FuelTheme.border),
                        ),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: FuelTheme.resolve(
                          context,
                          FuelTheme.ink,
                        ),
                        onPressed: () => _edit(context, entry: entry),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              dates.datePickerMediumDate(entry.date.toLocal()),
                              style: FuelTheme.body.copyWith(
                                color: FuelTheme.resolve(
                                  context,
                                  FuelTheme.muted,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(
                                  flex: 2,
                                  child: Text(
                                    data.vehicle(entry.vehicleId)!.name,
                                    style: FuelTheme.rowTitle,
                                  ),
                                ),
                                const SizedBox(width: FuelTheme.compact),
                                Flexible(
                                  child: Text(
                                    dollars(entry.total),
                                    textAlign: TextAlign.end,
                                    style: FuelTheme.rowTitle,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                '${fixed(entry.volume, 3)} gal',
                                entry.full ? 'Full tank' : 'Partial tank',
                                if (entry.octane != null) '${entry.octane} AKI',
                                if (entry.hasDiscrepancy) 'Total differs',
                              ].join(' · '),
                              style: FuelTheme.body.copyWith(
                                color: FuelTheme.resolve(
                                  context,
                                  FuelTheme.muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: FuelTheme.gap),
          ],
          const SizedBox(height: FuelTheme.gap),
          if (data.vehicles.isNotEmpty) ...[
            FuelSurface(
              glow: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FuelAction(
                      label: 'Scan a fill-up',
                      onPressed: () => _edit(context, startScan: true),
                    ),
                    CupertinoButton(
                      onPressed: () => _edit(context),
                      child: const Text('Enter manually'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: FuelTheme.gap),
          ],
        ],
      );
    },
  );
}

class _FillUpEditor extends StatefulWidget {
  const _FillUpEditor({
    required this.store,
    this.entry,
    this.startScan = false,
  });
  final FuelStore store;
  final FillUp? entry;
  final bool startScan;

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
  late final _octane = TextEditingController(
    text: widget.entry?.octane?.toString(),
  );
  late int _vehicleId = widget.entry?.vehicleId ?? widget.store.data.primaryId!;
  late DateTime _date = widget.entry?.date.toLocal() ?? DateTime.now();
  late bool _full = widget.entry?.full ?? true;
  bool _showDate = false;
  bool _busy = false;
  bool _scanning = false;
  int _photoNumber = 0;
  int _photoCount = 0;
  bool _pickingPhoto = false;
  String? _scanStatus;
  final _readings = <FuelPhotoField, PhotoReading>{};

  @override
  void initState() {
    super.initState();
    if (widget.startScan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scan();
      });
    }
  }

  @override
  void dispose() {
    _volume.dispose();
    _price.dispose();
    _total.dispose();
    _odometer.dispose();
    _octane.dispose();
    super.dispose();
  }

  TextEditingController _controller(FuelPhotoField field) => switch (field) {
    FuelPhotoField.gallons => _volume,
    FuelPhotoField.price => _price,
    FuelPhotoField.total => _total,
    FuelPhotoField.octane => _octane,
  };

  String _readingText(FuelPhotoField field, int value) => switch (field) {
    FuelPhotoField.gallons || FuelPhotoField.price => fixed(value, 3),
    FuelPhotoField.total => fixed(value, 2),
    FuelPhotoField.octane => value.toString(),
  };

  String _fieldLabel(FuelPhotoField field, String label) {
    final reading = _readings[field];
    if (reading == null ||
        _controller(field).text != _readingText(field, reading.value)) {
      return label;
    }
    return reading.confidence < 0.85
        ? '$label · Uncertain scan'
        : '$label · From photo';
  }

  Widget _scanField(FuelPhotoField field, String label, TextInputType type) {
    final controller = _controller(field);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => RecordField(
        label: _fieldLabel(field, label),
        controller: controller,
        keyboardType: type,
        maxLength: field == FuelPhotoField.octane ? 2 : null,
      ),
    );
  }

  Future<void> _scan() async {
    if (_pickingPhoto || _scanning) return;
    FocusScope.of(context).unfocus();
    setState(() => _pickingPhoto = true);
    try {
      final photos = await showFuelPhotoPicker(context);
      if (photos.isEmpty) return;
      final readings = <FuelPhotoField, PhotoReading>{};
      final conflicts = <FuelPhotoField>{};
      var failed = 0;
      var empty = 0;
      for (final (index, photo) in photos.indexed) {
        if (photo == null) {
          failed++;
          continue;
        }
        try {
          if (!mounted) continue;
          setState(() {
            _scanning = true;
            _photoNumber = index + 1;
            _photoCount = photos.length;
          });
          final result = await scanFuelPhoto(photo);
          if (result.isEmpty) empty++;
          for (final entry in result.entries) {
            if (conflicts.contains(entry.key)) continue;
            final previous = readings[entry.key];
            if (previous != null && previous.value != entry.value.value) {
              conflicts.add(entry.key);
              readings.remove(entry.key);
            } else if (previous == null ||
                previous.confidence < entry.value.confidence) {
              readings[entry.key] = entry.value;
            }
          }
        } catch (_) {
          failed++;
        } finally {
          await discardPickedPhoto(photo);
        }
      }
      if (!mounted) return;
      setState(() {
        for (final entry in readings.entries) {
          final controller = _controller(entry.key);
          final text = _readingText(entry.key, entry.value.value);
          if (controller.text.trim().isEmpty) {
            controller.text = text;
            _readings[entry.key] = entry.value;
          } else if (_enteredValue(entry.key) != entry.value.value) {
            conflicts.add(entry.key);
          }
        }
        final conflictLabels = conflicts.map(
          (field) => switch (field) {
            FuelPhotoField.gallons => 'gallons',
            FuelPhotoField.price => 'price per gallon',
            FuelPhotoField.total => 'total paid',
            FuelPhotoField.octane => 'octane',
          },
        );
        _scanStatus = [
          if (failed > 0)
            'Could not scan $failed of ${photos.length} selected photos.',
          if (empty > 0)
            'No fuel details found in $empty of ${photos.length} selected photos.',
          if (conflicts.isNotEmpty)
            'Conflicting readings for ${conflictLabels.join(', ')}. Check the photos and enter the correct values.',
          'Review the fields and fill in any blanks before saving.',
        ].join(' ');
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _scanStatus =
              'Could not open the photos. Try again or enter values manually.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _pickingPhoto = false;
          _scanning = false;
        });
      }
    }
  }

  int? _enteredValue(FuelPhotoField field) {
    final text = _controller(field).text.trim();
    return switch (field) {
      FuelPhotoField.gallons => parseFixed(text, 3, maximum: 999999),
      FuelPhotoField.price => parseFixed(text, 3, maximum: 99999),
      FuelPhotoField.total => parseFixed(text, 2, maximum: 999999),
      FuelPhotoField.octane => int.tryParse(text),
    };
  }

  void _calculatePrice() {
    final volume = parseFixed(_volume.text, 3, maximum: 999999);
    final total = parseFixed(_total.text, 2, maximum: 999999);
    if (volume == null || volume <= 0 || total == null || total <= 0) {
      showRecordError(context, 'Enter positive gallons and total paid first.');
      return;
    }
    final price = (total * 10000 + volume ~/ 2) ~/ volume;
    if (price <= 0 || price > 99999) {
      showRecordError(
        context,
        'Calculated price is outside the supported range.',
      );
      return;
    }
    setState(() {
      _readings.remove(FuelPhotoField.price);
      _price.text = fixed(price, 3);
      _scanStatus =
          'Price per gallon was calculated from total paid and gallons. Verify it against the photo if available.';
    });
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
    final grade = _octane.text.trim();
    final octane = RegExp(r'^\d{2}$').hasMatch(grade)
        ? int.tryParse(grade)
        : null;
    final odometer = RegExp(r'^\d{1,7}$').hasMatch(miles)
        ? int.parse(miles)
        : null;
    if (volume == null ||
        volume <= 0 ||
        price == null ||
        price <= 0 ||
        total == null ||
        total <= 0 ||
        (miles.isNotEmpty && odometer == null) ||
        (grade.isNotEmpty && (octane == null || !isUsOctane(octane)))) {
      await showRecordError(
        context,
        'Enter positive gallons, price per gallon, and total paid. Use up to three decimals for gallons and price, two for total, and whole miles for odometer. Enter octane from 85 to 99 AKI or leave it blank.',
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
      octane: octane,
    );
    if (widget.entry == null &&
        widget.store.data.fillUps.any(
          (entry) =>
              entry.vehicleId == _vehicleId &&
              entry.volume == volume &&
              entry.total == total &&
              _sameDay(entry.date.toLocal(), _date),
        )) {
      final confirmed = await confirmRecordAction(
        context,
        title: 'Possible duplicate',
        message:
            'This vehicle already has a fill-up with the same date, gallons and total.',
        action: 'Save another',
      );
      if (!mounted || !confirmed) return;
    }
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
        octane: octane,
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
    final disabled = _busy || _pickingPhoto || _scanning;
    return FuelPage(
      title: widget.entry != null
          ? 'Edit fill-up'
          : widget.startScan
          ? 'Review fill-up'
          : 'Log fill-up',
      children: [
        if (widget.entry == null) ...[
          FuelSurface(
            child: Padding(
              padding: const EdgeInsets.all(FuelTheme.gap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoButton(
                    onPressed: disabled ? null : _scan,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_scanning)
                          const CupertinoActivityIndicator()
                        else
                          const Icon(CupertinoIcons.camera),
                        const SizedBox(width: FuelTheme.compact),
                        Flexible(
                          child: Text(
                            _scanning
                                ? 'Reading photo $_photoNumber of $_photoCount…'
                                : _readings.isEmpty
                                ? 'Scan fill-up photos'
                                : 'Scan more photos',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_scanStatus case final status?)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        style: FuelTheme.body.copyWith(
                          color: FuelTheme.resolve(context, FuelTheme.muted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: FuelTheme.gap),
        ],
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
        const SizedBox(height: FuelTheme.gap),
        FuelPanel(
          children: [
            _scanField(FuelPhotoField.gallons, 'Gallons (US)', decimal),
            _scanField(FuelPhotoField.total, 'Total paid (USD)', decimal),
            _scanField(FuelPhotoField.price, 'Price per gallon (USD)', decimal),
            if (_readings.isNotEmpty)
              ListenableBuilder(
                listenable: _price,
                builder: (context, _) => _price.text.trim().isEmpty
                    ? CupertinoButton(
                        onPressed: disabled ? null : _calculatePrice,
                        child: const Text(
                          'Calculate price from total and gallons',
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            _scanField(
              FuelPhotoField.octane,
              'Octane (AKI, optional)',
              TextInputType.number,
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
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _full = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: FuelTheme.gap),
        FuelPanel(
          glow: true,
          children: [
            FuelAction(
              label: 'Save fill-up',
              onPressed: disabled ? null : _save,
            ),
          ],
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
