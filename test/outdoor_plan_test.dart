import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/outdoor_plan.dart';
import 'package:allergy_radar/models/pollen_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

final day = DateTime(2026, 5, 10);

AllergenStatus hourly(Allergen a, List<int> fromSeven) => AllergenStatus(
  allergen: a,
  kind: DataKind.forecast,
  level: Level.fromIndex(fromSeven.reduce((x, y) => x > y ? x : y)),
  hourly: [
    for (var i = 0; i < fromSeven.length; i++)
      DayValue(day.add(Duration(hours: 7 + i)), 0, Level.fromIndex(fromSeven[i])),
  ],
);

AllergenStatus daily(Allergen a, Level l) => AllergenStatus(allergen: a, kind: DataKind.estimate, level: l);

DateTime at(int hour) => day.add(Duration(hours: hour, minutes: 20));

void main() {
  const grass = [1, 1, 1, 2, 2, 3, 3, 3, 3, 3, 2, 2, 1, 1, 1];

  test('picco a metà giornata: meglio mattina e sera, evita il picco', () {
    final plan = OutdoorPlan.of([hourly(Allergens.grass, grass)], at(7))!;
    expect(plan.good, [(7, 9), (19, 21)]);
    expect(plan.goodText(' o '), 'prima delle 10 o dopo le 19');
    expect(plan.avoidSpan(plan.avoid!), 'dalle 12 alle 17');
    expect(plan.avoid, (12, 16));
  });

  test('a metà mattina conta solo quello che resta', () {
    final plan = OutdoorPlan.of([hourly(Allergens.grass, grass)], at(13))!;
    expect(plan.good, [(19, 21)]);
    expect(plan.goodText(' o '), 'dopo le 19');
    expect(plan.avoidSpan(plan.avoid!), 'fino alle 17');
    expect(plan.avoid, (13, 16));
  });

  test('una fascia in mezzo', () {
    final plan = OutdoorPlan.of([
      hourly(Allergens.grass, [3, 3, 3, 3, 1, 1, 1, 3, 3, 3, 3, 3, 3, 3, 3]),
    ], at(7))!;
    expect(plan.goodText(' o '), 'tra le 11 e le 14');
  });

  test('giornata bassa o uniforme: nessuna riga', () {
    expect(OutdoorPlan.of([hourly(Allergens.grass, List.filled(15, 1))], at(7)), isNull);
    expect(OutdoorPlan.of([hourly(Allergens.grass, List.filled(15, 3))], at(7)), isNull);
  });

  test('una sola ora migliore non basta', () {
    expect(
      OutdoorPlan.of([
        hourly(Allergens.grass, [1, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3]),
      ], at(7)),
      isNull,
    );
  });

  test('vale il peggiore tra gli allergeni con previsione oraria', () {
    final olive = List.filled(15, 0)
      ..[0] = 3
      ..[1] = 3;
    final plan = OutdoorPlan.of([hourly(Allergens.grass, grass), hourly(Allergens.olive, olive)], at(7))!;
    expect(plan.good, [(19, 21)]);
    expect(plan.allergens, ['Graminacee', 'Olivo']);
  });

  test('un allergene senza previsione oraria che domina nasconde la riga', () {
    expect(OutdoorPlan.of([hourly(Allergens.grass, grass), daily(Allergens.parietaria, Level.high)], at(7)), isNull);
  });

  test('un allergene senza previsione oraria più basso alza solo il fondo', () {
    final plan = OutdoorPlan.of([hourly(Allergens.grass, grass), daily(Allergens.parietaria, Level.moderate)], at(7))!;
    expect(plan.good, [(7, 11), (17, 21)]);
    expect(plan.levels[7], Level.low);
    expect(plan.peak, Level.high);
  });

  test('dopo le 21 o senza dati orari: nessuna riga', () {
    expect(OutdoorPlan.of([hourly(Allergens.grass, grass)], at(22)), isNull);
    expect(OutdoorPlan.of([daily(Allergens.parietaria, Level.high)], at(7)), isNull);
  });
}
