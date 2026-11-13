import 'package:flutter/cupertino.dart';

import '../../design_system/fuel_page.dart';
import '../../design_system/fuel_theme.dart';
import 'station_catalog.dart';

class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.station,
    required this.miles,
    required this.onPressed,
    required this.onCheckStatus,
  });

  final Station station;
  final double? miles;
  final VoidCallback onPressed;
  final VoidCallback onCheckStatus;

  static const _logos = {
    '7-eleven': '7-eleven',
    'bp': 'bp-helios',
    'circle k': 'circle-k',
    'citgo': 'citgo',
    'conoco': 'conoco',
    'costco': 'costco',
    'costco gasoline': 'costco',
    'exxon': 'exxon',
    'getgo': 'getgo',
    'getgo café & market': 'getgo',
    'giant': 'giant',
    'gulf': 'gulf',
    'kwik fill': 'kwik-fill',
    'kwikfill': 'kwik-fill',
    'lukoil': 'lukoil',
    'marathon': 'marathon',
    'mobil': 'mobil',
    'pennzoil': 'pennzoil',
    'phillips 66': 'phillips-66',
    'royal farms': 'royal-farms',
    "rutter's": 'rutters',
    'rutters': 'rutters',
    "sam's club": 'sams-club',
    'sheetz': 'sheetz',
    'shell': 'shell',
    'shell express': 'shell',
    'speedway': 'speedway',
    'sunoco': 'sunoco',
    'sunoco gas station': 'sunoco',
    'ta': 'ta',
    'valero': 'valero',
    'weis': 'weis',
  };

  @override
  Widget build(BuildContext context) {
    final ink = FuelTheme.resolve(context, FuelTheme.ink);
    final muted = FuelTheme.resolve(context, FuelTheme.muted);
    final accent = FuelTheme.resolve(context, FuelTheme.accent);
    final brand = station.brand.trim();
    final label = brand.isEmpty || brand.toLowerCase() == 'none'
        ? station.name.trim()
        : brand;
    final key = label.toLowerCase().replaceAll('’', "'");
    final logo = _logos[key];
    final initials = RegExp(r'[\p{L}\p{N}]+', unicode: true)
        .allMatches(label)
        .take(2)
        .map((word) => String.fromCharCode(word.group(0)!.runes.first))
        .join()
        .toUpperCase();
    final fallback =
        initials.isEmpty ||
            const {'fuel station', 'gas station', 'independent'}.contains(key)
        ? Icon(CupertinoIcons.drop, color: accent, size: 23)
        : Center(
            child: FittedBox(
              child: Text(
                initials,
                style: FuelTheme.rowTitle.copyWith(color: accent),
              ),
            ),
          );
    final distance = miles == null
        ? null
        : Text(
            '${miles!.toStringAsFixed(2)} mi',
            style: FuelTheme.rowTitle.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          );

    return FuelSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            onPressed: onPressed,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackDistance =
                    constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(17) > 23;
                return Row(
                  children: [
                    ExcludeSemantics(
                      child: Container(
                        width: 54,
                        height: 54,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: logo == null
                              ? FuelTheme.resolve(
                                  context,
                                  FuelTheme.accentSurface,
                                )
                              : CupertinoColors.white,
                        ),
                        child: logo == null
                            ? fallback
                            : Image.asset(
                                'assets/stations/logos/$logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                    key == 'bp'
                                    ? Image.asset(
                                        'assets/stations/logos/bp.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stack) =>
                                            fallback,
                                      )
                                    : fallback,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station.name,
                            style: FuelTheme.rowTitle.copyWith(color: ink),
                            maxLines: stackDistance ? null : 2,
                            overflow: stackDistance
                                ? null
                                : TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            station.address.isEmpty
                                ? 'Address unavailable'
                                : station.address,
                            style: FuelTheme.body.copyWith(
                              color: muted,
                              fontSize: 14,
                            ),
                            maxLines: stackDistance ? null : 2,
                            overflow: stackDistance
                                ? null
                                : TextOverflow.ellipsis,
                          ),
                          if (stackDistance && distance != null) ...[
                            const SizedBox(height: 4),
                            distance,
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (!stackDistance && distance != null) ...[
                      Container(
                        width: 1,
                        height: 32,
                        color: FuelTheme.resolve(context, FuelTheme.border),
                      ),
                      const SizedBox(width: 10),
                      distance,
                    ] else
                      ExcludeSemantics(
                        child: Icon(
                          CupertinoIcons.arrow_up_right,
                          color: muted,
                          size: 13,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const FuelDivider(),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              onPressed: onCheckStatus,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/stations/logos/top-tier.png',
                    width: 24,
                    height: 24,
                    excludeFromSemantics: true,
                    errorBuilder: (context, error, stack) =>
                        Icon(CupertinoIcons.search, size: 20, color: accent),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Check TOP TIER™ status',
                      style: FuelTheme.body.copyWith(
                        color: accent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
