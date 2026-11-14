import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import 'fuel_report.dart';

class FuelReportPage extends StatelessWidget {
  const FuelReportPage({super.key, required this.report});

  final FuelReport report;

  Future<void> _openSource(BuildContext context, FuelEvidence evidence) async {
    const channel = MethodChannel('fueliq/station_location');
    try {
      if (await channel.invokeMethod<bool>(
            'openFuelReportSource',
            evidence.url,
          ) ==
          true) {
        return;
      }
    } on PlatformException {
      // Keep the citation available if the browser cannot open.
    } on MissingPluginException {
      // External source links use the iOS host.
    }
    if (!context.mounted) return;
    await showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Couldn’t open source'),
        content: Text(evidence.source),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heading = FuelTheme.rowTitle.copyWith(
      color: FuelTheme.resolve(context, FuelTheme.ink),
    );
    final body = FuelTheme.body.copyWith(
      color: FuelTheme.resolve(context, FuelTheme.muted),
    );
    return FuelPage(
      title: 'Fuel report',
      children: [
        Semantics(header: true, child: Text(report.title, style: heading)),
        const SizedBox(height: FuelTheme.compact),
        Text(
          'U.S. product research. Fuel availability and blend at this station are unverified.',
          style: body,
        ),
        for (final evidence in [
          report.manufacturer,
          FuelReport.octane,
          FuelReport.regular,
          FuelReport.recommended,
          FuelReport.deposits,
        ]) ...[
          const SizedBox(height: FuelTheme.gap),
          FuelSurface(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(evidence.label, style: heading),
                  ),
                  const SizedBox(height: FuelTheme.compact),
                  Text(evidence.text, style: body),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => _openSource(context, evidence),
                    child: Text(evidence.source),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: FuelTheme.gap),
        Text(
          'Independent head-to-head product comparison · Unavailable',
          style: body,
        ),
      ],
    );
  }
}
