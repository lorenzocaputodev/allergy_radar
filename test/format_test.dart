import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/pollen_snapshot.dart';
import 'package:allergy_radar/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('i numeri dei granuli: troncati, mai sopra la soglia del livello mostrato', () {
    expect(Fmt.number(0), '0');
    expect(Fmt.number(0.07), '0', reason: 'sotto la soglia di 0,1 resta 0, non 0,1');
    expect(Fmt.number(0.1), '0,1');
    expect(Fmt.number(2.96), '2,9');
    expect(Fmt.number(7.04), '7');
    expect(Fmt.number(7.25), '7,2');
    expect(Fmt.number(9.97), '9,9', reason: 'sotto la soglia di 10 non diventa 10');
    expect(Fmt.number(29.9), '29');
    expect(Fmt.number(73.4), '73');
  });

  test('quando sono stati aggiornati i dati', () {
    final now = DateTime(2026, 10, 13, 9);
    expect(Fmt.updated(DateTime(2026, 10, 13, 8, 5), now), 'dati controllati alle 08:05');
    expect(Fmt.updated(DateTime(2026, 10, 12, 18, 5), now), 'dati controllati ieri alle 18:05');
    expect(Fmt.updated(DateTime(2026, 10, 10, 18, 5), now), 'dati controllati il 10 ott alle 18:05');
  });

  test('una misura vecchia dice anche quanti giorni ha', () {
    final now = DateTime(2026, 11, 4, 9);
    AllergenStatus measured(DateTime d) =>
        AllergenStatus(allergen: Allergens.parietaria, kind: DataKind.measured, level: Level.low, date: d);
    expect(Fmt.sourceOf(measured(DateTime(2026, 10, 30)), now: now), 'misura del 30 ott');
    expect(Fmt.sourceOf(measured(DateTime(2026, 10, 25)), now: now), 'misura del 25 ott, 10 giorni fa');
    expect(Fmt.sourceOf(measured(DateTime(2026, 10, 25))), 'misura del 25 ott');
  });

  test('le medie si arrotondano', () {
    expect(Fmt.mean(2.25), '2,3');
    expect(Fmt.mean(1.96), '2');
    expect(Fmt.mean(0), '0');
  });
}
