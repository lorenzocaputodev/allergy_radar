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

  List<AlertMessage> schedule(
    DateTime now, {
    AlertSettings settings = const AlertSettings(),
    List<AllergenStatus>? followed,
    bool diaryDone = false,
  }) => planner.schedule(
    now: now,
    settings: settings,
    placeName: 'Lecce',
    followed: followed ?? [grass(Level.low, Level.moderate, 14), parietaria],
    thresholdOf: (_) => Level.moderate,
    diaryDoneToday: diaryDone,
  );

  AlertMessage? of(List<AlertMessage> list, AlertKind k) => list.where((m) => m.kind == k).firstOrNull;

  test('ogni tipo attivo ha la sua prossima occorrenza', () {
    final list = schedule(DateTime(2026, 9, 30, 7));
    expect(of(list, AlertKind.briefing)!.at, DateTime(2026, 9, 30, 7, 30));
    expect(of(list, AlertKind.tomorrow)!.at, DateTime(2026, 9, 30, 19));
    expect(of(list, AlertKind.diary)!.at, DateTime(2026, 9, 30, 21));
  });

  test('briefing: testo del giorno in cui arriva', () {
    final today = of(schedule(DateTime(2026, 9, 30, 7)), AlertKind.briefing)!;
    expect(today.title, 'Pollini di oggi a Lecce');
    expect(today.body, 'Graminacee: basso. Parietaria: alto (stima). Ti danno fastidio: Parietaria.');

    // Dopo le 7:30 si programma per domani, con la previsione di domani.
    final next = of(schedule(DateTime(2026, 9, 30, 9)), AlertKind.briefing)!;
    expect(next.at, DateTime(2026, 10, 1, 7, 30));
    expect(next.body, contains('Graminacee: moderato'));
    expect(next.body, contains('Ti danno fastidio: Graminacee, Parietaria.'));
  });

  test('briefing solo sopra soglia', () {
    const s = AlertSettings(briefingOnlyAbove: true);
    expect(
      of(
        schedule(DateTime(2026, 9, 30, 7), settings: s, followed: [grass(Level.low, Level.low, 2)]),
        AlertKind.briefing,
      ),
      isNull,
    );
    expect(of(schedule(DateTime(2026, 9, 30, 7), settings: s), AlertKind.briefing), isNotNull);
  });

  test('domani peggiora: solo se sale e supera la soglia', () {
    final m = of(schedule(DateTime(2026, 9, 30, 12)), AlertKind.tomorrow)!;
    expect(m.at, DateTime(2026, 9, 30, 19));
    expect(m.body, 'Graminacee: da basso a moderato (14 granuli/m³).');
    expect(
      of(schedule(DateTime(2026, 9, 30, 12), followed: [grass(Level.none, Level.low, 3)]), AlertKind.tomorrow),
      isNull,
    );
    // Dopo le 19 servirebbe la previsione di dopodomani, che qui non c'è.
    expect(of(schedule(DateTime(2026, 9, 30, 20)), AlertKind.tomorrow), isNull);
  });

  test('diario: oggi se manca la voce, altrimenti domani', () {
    expect(of(schedule(DateTime(2026, 9, 30, 12)), AlertKind.diary)!.at, DateTime(2026, 9, 30, 21));
    expect(of(schedule(DateTime(2026, 9, 30, 12), diaryDone: true), AlertKind.diary)!.at, DateTime(2026, 10, 1, 21));
    expect(of(schedule(DateTime(2026, 9, 30, 22)), AlertKind.diary)!.at, DateTime(2026, 10, 1, 21));
  });

  test('tutto spento: nessun avviso', () {
    expect(schedule(DateTime(2026, 9, 30, 8), settings: AlertSettings.off), isEmpty);
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
