import 'package:allergy_radar/models/place_index.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final index = placeIndex();

  test('tutti i comuni, con nomi italiani e regione', () {
    expect(index.places.length, greaterThan(7800));
    expect(index.search('Napoli').first.name, 'Napoli');
    expect(index.search('Napoli').first.region, 'Campania');
    expect(index.search('Bolzano').first.name, 'Bolzano');
  });

  test('ricerca senza accenti, apostrofi o maiuscole', () {
    expect(index.search('forli').first.name, 'Forlì');
    expect(index.search('laquila').first.name, "L'Aquila");
    expect(index.search("l'aq").first.name, "L'Aquila");
    expect(index.search('aquila').map((p) => p.name), contains("L'Aquila"));
    expect(index.search('REGGIO').map((p) => p.name).take(2), ['Reggio di Calabria', "Reggio nell'Emilia"]);
  });

  test('prima il nome esatto, poi i più popolosi', () {
    expect(index.search('lecce').first.name, 'Lecce');
    expect(index.search('sant').first.name, startsWith('Sant'));
    expect(index.search('a'), isEmpty);
  });

  test('comune più vicino entro 15 km', () {
    expect(index.nearest(40.36, 18.17)!.name, 'Lecce');
    expect(index.nearest(41.90, 12.50)!.name, 'Roma');
    expect(index.nearest(48.85, 2.35), isNull, reason: 'Parigi è fuori dall’Italia');
  });

  test('normalize', () {
    expect(PlaceIndex.normalize("Sant'Agata de' Goti"), 'sant agata de goti');
    expect(PlaceIndex.normalize('Valle d’Aosta'), 'valle d aosta');
  });
}
