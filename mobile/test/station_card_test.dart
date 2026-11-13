import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/features/stations/station_card.dart';
import 'package:fueliq/features/stations/station_catalog.dart';

void main() {
  testWidgets(
    'station cards show a local logo or fallback and open the station',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 950));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var opened = false;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                width: 240,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StationCard(
                      station: const Station(
                        'node/1',
                        'Sunoco',
                        ' SUNOCO ',
                        '3100 W Liberty Ave',
                        0,
                        0,
                      ),
                      miles: .44,
                      onPressed: () => opened = true,
                    ),
                    StationCard(
                      station: const Station('node/2', 'BP', 'BP', '', 0, 0),
                      miles: null,
                      onPressed: () {},
                    ),
                    StationCard(
                      station: const Station(
                        'node/3',
                        'GetGo',
                        'GetGo',
                        '',
                        0,
                        0,
                      ),
                      miles: null,
                      onPressed: () {},
                    ),
                    StationCard(
                      station: const Station(
                        'node/4',
                        'Fuel Station',
                        '',
                        '',
                        0,
                        0,
                      ),
                      miles: null,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      const assets = 'assets/stations/logos';
      Finder logo(String name) => find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == '$assets/$name.png',
      );
      expect(logo('sunoco'), findsOneWidget);
      expect(logo('bp-helios'), findsOneWidget);
      expect(logo('getgo'), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.drop), findsOneWidget);
      expect(find.text('0.44 mi'), findsOneWidget);
      expect(find.text('Address unavailable'), findsNothing);
      expect(find.text('Check TOP TIER™ status'), findsNothing);
      await tester.tap(find.text('Sunoco'));
      expect(opened, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
