import 'package:allergy_radar/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('usa il nome del comune trovato dal geocoder', () async {
    final p = await LocationService.placeAt(40.35, 18.17, reverse: (_, _) async => (name: 'Lecce', region: 'Puglia'));
    expect(p.name, 'Lecce');
    expect(p.region, 'Puglia');
    expect(p.lat, 40.35);
  });

  test('senza nome, o con il geocoder in errore, resta «La mia posizione»', () async {
    final none = await LocationService.placeAt(40.35, 18.17, reverse: (_, _) async => null);
    expect(none.name, LocationService.fallbackName);
    final failing = await LocationService.placeAt(40.35, 18.17, reverse: (_, _) => throw Exception('offline'));
    expect(failing.name, LocationService.fallbackName);
    expect(failing.lon, 18.17);
  });

  test('fuori da Android il geocoder di sistema non risponde', () async {
    expect(await LocationService.androidGeocoder(40.35, 18.17), isNull);
  });
}
