import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/features/stations/station_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled catalog searches real records without network', () async {
    final catalog = await StationCatalog.load();
    expect(catalog.stations.length, greaterThan(3000));
    expect(catalog.search('Sheetz'), isNotEmpty);
    final nearby = catalog.search(
      '',
      location: (latitude: 40.4406, longitude: -79.9959, accuracy: 100),
    );
    expect(nearby.length, greaterThan(30));
    expect(nearby.any((result) => result.miles! > 25), isTrue);
    expect(nearby.every((result) => result.station.isNamed), isTrue);
    final distances = nearby.map((result) => result.miles!).toList();
    expect(distances, orderedEquals([...distances]..sort()));
    expect(
      catalog.search(
        '',
        location: (latitude: 34.05, longitude: -118.25, accuracy: 100),
      ),
      isNotEmpty,
    );
  });
}
