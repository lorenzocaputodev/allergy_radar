import 'package:allergy_radar/models/alert_settings.dart';
import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/pollen_snapshot.dart';
import 'package:allergy_radar/services/alert_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = AlertPlanner();
  final day = DateTime(2026, 9, 30);

  AllergenStatus grass(Level today, Level tomorrow, double tomorrowValue) => AllergenStatus(
    allergen: Allergens.grass,
    kind: DataKind.forecast,
    level: today,
    value: 1,
    series: [DayValue(day, 1, today), DayValue(day.add(const Duration(days: 1)), tomorrowValue, tomorrow)],
  );

  final parietaria = AllergenStatus(allergen: Allergens.parietaria, kind: DataKind.estimate, level: Level.high);

  List<AlertMessage> plan(
    DateTime now, {
    AlertSettings settings = const AlertSettings(),
    List<AllergenStatus>? followed,
    bool diaryDone = false,
    Map<AlertKind, DateTime> sent = const {},
  }) => planner.plan(
    now: now,
    settings: settings,
    placeName: 'Lecce',
    followed: followed ?? [grass(Level.low, Level.moderate, 14), parietaria],
    thresholdOf: (_) => Level.moderate,
    diaryDoneToday: diaryDone,
    sentOn: sent,
  );

  test('briefing dopo le 7:30 e non prima', () {
    expect(plan(DateTime(2026, 9, 30, 7, 0)), isEmpty);
    final m = plan(DateTime(2026, 9, 30, 8, 10));
    expect(m.single.kind, AlertKind.briefing);
    expect(m.single.title, 'Pollini oggi a Lecce');
    expect(m.single.body, contains('Parietaria: alto (media storica)'));
    expect(m.single.body, contains('Sopra la tua soglia: Parietaria.'));
  });

  test('briefing: non si ripete nello stesso giorno, né fuori finestra', () {
    expect(plan(DateTime(2026, 9, 30, 8), sent: {AlertKind.briefing: DateTime(2026, 9, 30, 7, 40)}), isEmpty);
    expect(plan(DateTime(2026, 9, 30, 11)), isEmpty);
    expect(plan(DateTime(2026, 10, 1, 8), sent: {AlertKind.briefing: DateTime(2026, 9, 30, 7, 40)}), hasLength(1));
  });

  test('briefing solo sopra soglia', () {
    const s = AlertSettings(briefingOnlyAbove: true);
    expect(plan(DateTime(2026, 9, 30, 8), settings: s, followed: [grass(Level.low, Level.low, 2)]), isEmpty);
    expect(plan(DateTime(2026, 9, 30, 8), settings: s), hasLength(1));
  });

  test('domani peggiora: solo se sale e supera la soglia', () {
    final m = plan(DateTime(2026, 9, 30, 19, 30));
    expect(m.single.kind, AlertKind.tomorrow);
    expect(m.single.body, 'Graminacee: da basso a moderato (14 granuli/m³).');
    expect(plan(DateTime(2026, 9, 30, 19, 30), followed: [grass(Level.none, Level.low, 3)]), isEmpty);
  });

  test('diario: solo se oggi non c’è una voce', () {
    const onlyDiary = AlertSettings(briefing: false, tomorrow: false);
    expect(plan(DateTime(2026, 9, 30, 21, 5), settings: onlyDiary).single.kind, AlertKind.diary);
    expect(plan(DateTime(2026, 9, 30, 21, 5), settings: onlyDiary, diaryDone: true), isEmpty);
  });

  test('tutto spento: nessun avviso', () {
    expect(plan(DateTime(2026, 9, 30, 8), settings: AlertSettings.off), isEmpty);
    expect(AlertSettings.off.anyEnabled, isFalse);
  });

  test('impostazioni: JSON andata e ritorno', () {
    const a = AlertSettings(briefingAt: 6 * 60 + 45, tomorrow: false, diaryAt: 22 * 60);
    final b = AlertSettings.fromJson(a.toJson());
    expect(b.briefingAt, 405);
    expect(b.tomorrow, isFalse);
    expect(b.diaryAt, 1320);
    expect(AlertSettings.fromJson(const {}).briefing, isTrue);
  });
}
