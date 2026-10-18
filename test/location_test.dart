import 'dart:async';

import 'package:allergy_radar/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final index = placeIndex();

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

  test('Geocoder in tempo: vince il suo nome anche con l’indice', () async {
    final p = await LocationService.placeAt(
      40.36,
      18.17,
      reverse: (_, _) async => (name: 'Lecce', region: 'Puglia'),
      index: index,
    );
    expect(p.name, 'Lecce');
    expect(p.region, 'Puglia');
  });

  test('Geocoder lento: nome dal comune più vicino entro due secondi', () async {
    final watch = Stopwatch()..start();
    final p = await LocationService.placeAt(40.36, 18.17, reverse: (_, _) => Completer<Never>().future, index: index);
    expect(watch.elapsed, lessThan(const Duration(seconds: 3)));
    expect(p.name, 'Lecce');
    expect(p.region, 'Puglia');
    expect(p.lat, 40.36);
  });

  test('Geocoder in ritardo: prima il comune dall’indice, poi il nome giusto quando arriva', () async {
    final renamed = Completer<String>();
    final p = await LocationService.placeAt(
      40.17,
      18.17,
      reverse: (_, _) => Future.delayed(const Duration(milliseconds: 2500), () => (name: 'Noha', region: 'Puglia')),
      index: index,
      renamed: (p) => renamed.complete(p.name),
    );
    expect(p.name, isNot('Noha'));
    expect(p.name, isNot(LocationService.fallbackName));
    expect(await renamed.future, 'Noha');
  });

  test('fuori dall’Italia e senza Geocoder: «La mia posizione»', () async {
    final p = await LocationService.placeAt(48.85, 2.35, reverse: (_, _) async => null, index: index);
    expect(p.name, LocationService.fallbackName);
  });

  test('ricerca col Geocoder: sempre il nome del comune, mai il testo scritto', () async {
    final found = await LocationService.searchByGeocoder(
      'via roma 3 lecce',
      index,
      forward: (_) async => [(lat: 40.35, lon: 18.17), (lat: 48.85, lon: 2.35)],
    );
    expect(found.single.name, 'Lecce');
    expect(found.single.region, 'Puglia');
  });
}
