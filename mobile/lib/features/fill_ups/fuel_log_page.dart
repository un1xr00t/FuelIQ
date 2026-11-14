import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../data/fuel_records.dart';
import '../../data/fuel_store.dart';
import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import '../../design_system/photo_picker.dart';
import '../../design_system/record_controls.dart';
import '../stations/station_catalog.dart';
import 'claude_vision.dart';
import 'fuel_photo_parser.dart';
import 'fuel_photo_scanner.dart';

String? _stationDisplay(String? label, bool hideAddress) =>
    hideAddress ? label?.split(' · ').first : label;

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
              color: FuelTheme.resolve(context, FuelTheme.accentSurface),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${dollars(data.spending)} total',
                style: FuelTheme.rowTitle.copyWith(
                  color: FuelTheme.resolve(context, FuelTheme.ink),
                ),
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
                                ?_stationDisplay(
                                  entry.station,
                                  data.hideStationAddresses,
                                ),
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
  bool _dateEdited = false;
  bool get _hideStationAddresses => widget.store.data.hideStationAddresses;
  late String? _selectedStationId = widget.entry?.stationId;
  late String? _selectedStationBrand = widget.entry?.stationBrand;

  bool get _keepsStationSelection =>
      _station.text.trim() ==
      _stationDisplay(_selectedStationLabel, _hideStationAddresses);

  late String? _selectedStationLabel = widget.entry?.station;
  late final _station = TextEditingController(
    text: _stationDisplay(_selectedStationLabel, _hideStationAddresses),
  );

  String get _stationToSave {
    final entered = _station.text.trim();
    return _keepsStationSelection ? _selectedStationLabel ?? entered : entered;
  }

  void _selectStation(Station station) {
    setState(() {
      _selectedStationId = station.id;
      final brand = station.brand.trim();
      _selectedStationBrand =
          brand.isEmpty || brand.toLowerCase() == 'none' || brand.length > 100
          ? null
          : brand;
      _selectedStationLabel = _catalogStationLabel(station);
      _station.text = _stationDisplay(
        _selectedStationLabel,
        _hideStationAddresses,
      )!;
    });
  }

  Future<void> _findStation() async {
    final catalog = StationCatalog.load();
    final station = await Navigator.of(context).push<Station>(
      CupertinoPageRoute(
        builder: (context) => _StationPicker(catalog: catalog),
      ),
    );
    if (mounted && station != null) _selectStation(station);
  }

  List<Station> _stationSuggestions = const [];
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
    _station.dispose();
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

  Future<List<Station>> _findStations(List<StationLocation> locations) async {
    if (locations.isEmpty) return [];
    try {
      final catalog = await StationCatalog.load();
      const radiusMiles = 150 / 1609.344;
      final matches =
          [
            for (final station in catalog.stations)
              if (station.isNamed &&
                  locations.every(
                    (location) => station.milesFrom(location) <= radiusMiles,
                  ))
                station,
          ]..sort(
            (a, b) => a
                .milesFrom(locations.first)
                .compareTo(b.milesFrom(locations.first)),
          );
      return matches.take(3).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _scan() async {
    if (_pickingPhoto || _scanning) return;
    FocusScope.of(context).unfocus();
    setState(() => _pickingPhoto = true);
    try {
      final String? claudeKey;
      try {
        claudeKey = await readClaudeVisionKey();
      } on PlatformException {
        if (mounted) {
          setState(() {
            _scanStatus =
                'Could not read the saved Claude Vision key. Unlock your iPhone and try again, or enter values manually.';
          });
        }
        return;
      }
      final useClaude = claudeKey != null;
      if (!mounted) return;
      if (Platform.isIOS && !useClaude) {
        final useLocal = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialog) => CupertinoAlertDialog(
            title: const Text('Claude Vision needs a key'),
            content: const Text(
              'Save your Anthropic API key under Settings → Claude Vision API key on this iPhone. The Mac benchmark key is stored separately.',
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Cancel'),
              ),
              CupertinoDialogAction(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text('Use local OCR'),
              ),
            ],
          ),
        );
        if (useLocal != true || !mounted) return;
      }
      final photos = await showFuelPhotoPicker(context);
      if (photos.isEmpty) return;
      final readings = <FuelPhotoField, PhotoReading>{};
      final conflicts = <FuelPhotoField>{};
      final displays = <PumpDisplay>[];
      final captures = <DateTime>[];
      final locations = <StationLocation>[];
      final unmatchedPhotos = <List<PumpDisplay>>[];
      var failed = 0;
      if (claudeKey != null) {
        try {
          if (!mounted) return;
          setState(() {
            _scanning = true;
            _photoNumber = photos.length;
            _photoCount = photos.length;
          });
          final result = await scanWithClaude(
            photos.nonNulls.toList(),
            key: claudeKey,
          );
          readings.addAll(result.readings);
          captures.addAll(result.captures);
          locations.addAll(result.locations);
          failed =
              result.failed + photos.where((photo) => photo == null).length;
        } catch (_) {
          if (mounted) {
            setState(
              () => _scanStatus =
                  'Claude Vision could not complete the scan. Check your connection and API key in Settings, or enter values manually.',
            );
          }
          return;
        } finally {
          for (final photo in photos.nonNulls) {
            await discardPickedPhoto(photo);
          }
        }
      }
      for (final (index, photo)
          in (useClaude ? photos.take(0) : photos).indexed) {
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
          if (result.capturedAt case final capture?) {
            if (!capture.isAfter(DateTime.now())) captures.add(capture);
          }
          if (result.location case final location?) locations.add(location);
          displays.addAll(result.displays);
          if (result.readings.isEmpty) unmatchedPhotos.add(result.displays);
          for (final entry in result.readings.entries) {
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
      final enteredPrice = _enteredValue(FuelPhotoField.price);
      final scannedPrice = readings[FuelPhotoField.price]?.value;
      final price = enteredPrice ?? scannedPrice;
      if (price != null &&
          !conflicts.contains(FuelPhotoField.price) &&
          !conflicts.contains(FuelPhotoField.total) &&
          !conflicts.contains(FuelPhotoField.gallons) &&
          (scannedPrice == null || scannedPrice == price)) {
        final match = matchPumpDisplay(
          displays,
          price: price,
          knownTotal:
              _enteredValue(FuelPhotoField.total) ??
              readings[FuelPhotoField.total]?.value,
          knownGallons:
              _enteredValue(FuelPhotoField.gallons) ??
              readings[FuelPhotoField.gallons]?.value,
        );
        if (match != null) {
          readings[FuelPhotoField.total] ??= (
            value: match.total,
            confidence: 0.7,
          );
          readings[FuelPhotoField.gallons] ??= (
            value: match.gallons,
            confidence: 0.7,
          );
          unmatchedPhotos.removeWhere(
            (photo) => photo.any(
              (display) =>
                  display.totals.any((total) => total.value == match.total) &&
                  display.gallons.any(
                    (gallons) => gallons.value == match.gallons,
                  ),
            ),
          );
        }
      }
      final suggestions = await _findStations(locations);
      if (!mounted) return;
      final empty = unmatchedPhotos.length;
      captures.sort();
      final dateConflict =
          captures.isNotEmpty && !_sameDay(captures.first, captures.last);
      final useCapture =
          captures.isNotEmpty &&
          !dateConflict &&
          !_dateEdited &&
          widget.entry == null;
      setState(() {
        _stationSuggestions = suggestions;
        if (useCapture) _date = captures.first;
        for (final entry in readings.entries) {
          final controller = _controller(entry.key);
          final text = _readingText(entry.key, entry.value.value);
          final previous = _readings[entry.key];
          final replaceScan =
              useClaude &&
              previous != null &&
              controller.text == _readingText(entry.key, previous.value);
          if (controller.text.trim().isEmpty || replaceScan) {
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
          if (useClaude && readings.isNotEmpty) 'Scanned with Claude Vision.',
          if (!useClaude) 'Scanned with local OCR.',
          if (failed > 0)
            'Could not scan $failed of ${photos.length} selected photos.',
          if (dateConflict)
            'Photos have different capture dates. Check the fill-up date.',
          if (useCapture) 'Date suggested from photo capture time.',
          if (useClaude && readings.isEmpty)
            'Claude Vision could not read the fill-up fields.',
          if (displays.isNotEmpty &&
              price == null &&
              !conflicts.contains(FuelPhotoField.price))
            'Scan both pump photos together, or enter the price per gallon and rescan the display.'
          else if (empty == photos.length)
            'No fuel details could be matched. Try a close-up of the completed pump display or the fuel lines on your receipt.'
          else if (empty > 0)
            'No fuel details could be matched in $empty of ${photos.length} selected photos.',
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
        station: _stationToSave,
        stationId: _keepsStationSelection ? _selectedStationId : null,
        stationBrand: _keepsStationSelection ? _selectedStationBrand : null,
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
              onDateTimeChanged: (date) => setState(() {
                _date = date;
                _dateEdited = true;
              }),
            ),
          ),
        const SizedBox(height: FuelTheme.gap),
        FuelPanel(
          children: [
            RecordField(
              label: 'Gas station (optional)',
              controller: _station,
              maxLength: 250,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: disabled ? null : _findStation,
              child: const Text('Find a Pennsylvania station'),
            ),
            if (_stationSuggestions.isNotEmpty) ...[
              Text(
                'Nearby stations from photo location',
                style: FuelTheme.body.copyWith(
                  color: FuelTheme.resolve(context, FuelTheme.muted),
                ),
              ),
              const SizedBox(height: FuelTheme.compact),
              ListenableBuilder(
                listenable: _station,
                builder: (context, _) => Column(
                  children: [
                    for (final station in _stationSuggestions)
                      _StationSuggestionRow(
                        station: station,
                        selected:
                            _keepsStationSelection &&
                            _selectedStationId == station.id,
                        hideAddress: _hideStationAddresses,
                        onSelected: () => _selectStation(station),
                        enabled: !disabled,
                      ),
                  ],
                ),
              ),
            ],
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

String _catalogStationLabel(Station station) => station.address.isEmpty
    ? station.name
    : '${station.name} · ${station.address}';

class _StationSuggestionRow extends StatelessWidget {
  const _StationSuggestionRow({
    required this.station,
    required this.selected,
    required this.hideAddress,
    required this.onSelected,
    required this.enabled,
  });

  final Station station;
  final bool selected;
  final bool hideAddress;
  final VoidCallback onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = FuelTheme.resolve(context, FuelTheme.accent);
    final muted = FuelTheme.resolve(context, FuelTheme.muted);
    return Padding(
      padding: const EdgeInsets.only(bottom: FuelTheme.gap),
      child: Semantics(
        selected: selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected
                ? accent.withValues(alpha: 0.12)
                : FuelTheme.resolve(context, FuelTheme.accentSurface),
            border: Border.all(
              color: selected
                  ? accent
                  : FuelTheme.resolve(context, FuelTheme.border),
            ),
          ),
          child: CupertinoButton(
            padding: const EdgeInsets.all(FuelTheme.gap),
            onPressed: enabled
                ? () {
                    FocusScope.of(context).unfocus();
                    onSelected();
                  }
                : null,
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(CupertinoIcons.location, color: muted, size: 20),
                ),
                const SizedBox(width: FuelTheme.gap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: FuelTheme.rowTitle.copyWith(
                          color: FuelTheme.resolve(context, FuelTheme.ink),
                        ),
                      ),
                      if (!hideAddress && station.address.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          station.address,
                          style: FuelTheme.body.copyWith(
                            color: muted,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: FuelTheme.gap),
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: selected ? accent : muted,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StationPicker extends StatefulWidget {
  const _StationPicker({required this.catalog});

  final Future<StationCatalog> catalog;

  @override
  State<_StationPicker> createState() => _StationPickerState();
}

class _StationPickerState extends State<_StationPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) => FuelPage(
    title: 'Find a station',
    children: [
      CupertinoSearchTextField(
        placeholder: 'Name, address or ZIP',
        onChanged: (value) => setState(() => _query = value.trim()),
      ),
      const SizedBox(height: FuelTheme.compact),
      FutureBuilder<StationCatalog>(
        future: widget.catalog,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text('Station catalog unavailable.');
          }
          final catalog = snapshot.data;
          if (catalog == null) return const CupertinoActivityIndicator();
          if (_query.isEmpty) return const SizedBox.shrink();
          final results = catalog.search(_query).take(20).toList();
          if (results.isEmpty) return const Text('No matching stations.');
          return Column(
            children: [
              for (final result in results)
                _StationSuggestionRow(
                  station: result.station,
                  selected: false,
                  hideAddress: false,
                  onSelected: () => Navigator.pop(context, result.station),
                  enabled: true,
                ),
              if (results.length == 20)
                const Text('Refine your search to narrow the results.'),
            ],
          );
        },
      ),
    ],
  );
}
