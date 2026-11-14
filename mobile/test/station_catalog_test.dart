import 'package:flutter_test/flutter_test.dart';
import 'package:fueliq/features/stations/station_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('precise octanes stay distinct and generic grades stay unnumbered', () {
    final grades = StationFuelGrade.parseList([
      'octane_93',
      'octane_94',
      'premium',
      'midgrade',
      'diesel',
    ]);
    expect(grades.map((grade) => grade.description), [
      'Premium 93',
      'Premium 94',
      'Midgrade',
      'Diesel',
    ]);
    expect(StationFuelGrade.parseList(null), isEmpty);
  });

  test('bundled catalog searches real records without network', () async {
    final catalog = await StationCatalog.load();
    expect(catalog.stations.length, greaterThan(3000));
    expect(catalog.search('Sheetz'), isEmpty);
    expect(catalog.search('Wawa'), isEmpty);
    expect(catalog.search('Shell'), isNotEmpty);
    final afdcResults = catalog
        .search('')
        .where((result) => result.station.afdcFuels.isNotEmpty);
    expect(afdcResults, isNotEmpty);
    for (final result in afdcResults) {
      for (final fuel in result.station.afdcFuels) {
        expect(fuel.id, isPositive);
        expect(
          result.station.fuelGrades.where(
            (grade) => grade.description == fuel.label,
          ),
          hasLength(1),
        );
      }
    }
    expect(
      catalog
          .search('')
          .any(
            (result) =>
                result.station.fuelGrades.any((grade) => grade.octane == 93),
          ),
      isTrue,
    );
    expect(
      catalog
          .search("Rutter's")
          .any((result) => result.station.brand == "Rutter's"),
      isTrue,
    );
    final nearby = catalog.search(
      '',
      location: (latitude: 40.4406, longitude: -79.9959, accuracy: 100),
    );
    expect(nearby.length, greaterThan(30));
    expect(nearby.any((result) => result.miles! > 25), isTrue);
    expect(nearby.every((result) => result.station.isNamed), isTrue);
    expect(nearby.every((result) => result.station.brand.isNotEmpty), isTrue);
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
