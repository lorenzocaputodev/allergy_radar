import 'package:allergy_radar/models/alert_settings.dart';
import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/pollen_snapshot.dart';
import 'package:allergy_radar/models/weather.dart';
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

  const parietaria = AllergenStatus(allergen: Allergens.parietaria, kind: DataKind.estimate, level: Level.high);

  List<AlertMessage> schedule(
    DateTime now, {
    AlertSettings settings = const AlertSettings(),
    List<AllergenStatus>? followed,
    bool diaryDone = false,
    bool following = false,
    DateTime? fixedAt,
    HourlyWeather? weather,
  }) => planner.schedule(
    now: now,
    settings: settings,
    placeName: 'Lecce',
    followed: followed ?? [grass(Level.low, Level.moderate, 14), parietaria],
    thresholdOf: (_) => Level.moderate,
    diaryDoneToday: diaryDone,
    followingPlace: following,
    placeFixedAt: fixedAt,
    weather: weather,
  );

  AlertMessage? of(List<AlertMessage> list, AlertKind k) => list.where((m) => m.kind == k).firstOrNull;

  test('seguendo la posizione, un luogo letto più di 12 ore prima dell’avviso lo dice', () {
    final evening = DateTime(2026, 9, 29, 22);
    String briefing({bool following = true, DateTime? fixedAt}) =>
        of(schedule(evening, following: following, fixedAt: fixedAt), AlertKind.briefing)!.body;

    expect(briefing(fixedAt: DateTime(2026, 9, 29, 21)), isNot(contains('posizione')));
    expect(
      briefing(fixedAt: DateTime(2026, 9, 29, 14, 30)),
      endsWith(' Luogo dell’ultima posizione letta, ieri alle 14:30.'),
    );
    expect(briefing(), endsWith(' Luogo dell’ultima posizione nota.'));
    expect(briefing(following: false, fixedAt: DateTime(2026, 9, 20)), isNot(contains('posizione')));
    expect(
      of(
        schedule(DateTime(2026, 9, 30, 12), following: true, fixedAt: DateTime(2026, 9, 29, 14, 30)),
        AlertKind.tomorrow,
      )!.body,
      contains('Luogo dell’ultima posizione letta, ieri alle 14:30'),
    );
  });

  test('briefing: una misura vecchia non fa scattare la soglia e dice la sua età', () {
    final old = AllergenStatus(
      allergen: Allergens.parietaria,
      kind: DataKind.measured,
      level: Level.high,
      value: 40,
      date: DateTime(2026, 9, 18),
    );
    final recent = AllergenStatus(
      allergen: Allergens.parietaria,
      kind: DataKind.measured,
      level: Level.high,
      value: 40,
      date: DateTime(2026, 9, 26),
    );
    final now = DateTime(2026, 9, 30, 7);
    expect(
      of(schedule(now, followed: [grass(Level.low, Level.low, 1), old]), AlertKind.briefing)!.body,
      'Nessun allergene da tenere d’occhio tra quelli con dati recenti.',
    );
    expect(
      of(schedule(now, followed: [grass(Level.low, Level.low, 1), recent]), AlertKind.briefing)!.body,
      'Parietaria alta (misura del 26 set). Gli altri sono più bassi.',
    );
  });

  test('ogni tipo attivo ha la sua prossima occorrenza', () {
    final list = schedule(DateTime(2026, 9, 30, 7));
    expect(of(list, AlertKind.briefing)!.at, DateTime(2026, 9, 30, 7, 30));
    expect(of(list, AlertKind.tomorrow)!.at, DateTime(2026, 9, 30, 19));
    expect(of(list, AlertKind.diary)!.at, DateTime(2026, 9, 30, 21));
  });

  test('nel giorno del cambio d’ora «domani» è il giorno dopo', () {
    final list = schedule(DateTime(2026, 10, 25, 8));
    expect(of(list, AlertKind.briefing)!.at, DateTime(2026, 10, 26, 7, 30));
    expect(of(list, AlertKind.diary)!.at, DateTime(2026, 10, 25, 21));
  });

  test('briefing: testo del giorno in cui arriva', () {
    final today = of(schedule(DateTime(2026, 9, 30, 7)), AlertKind.briefing)!;
    expect(today.title, 'Pollini di oggi a Lecce');
    expect(today.body, 'Parietaria alta (stima). Gli altri sono più bassi.');

    final next = of(schedule(DateTime(2026, 9, 30, 9)), AlertKind.briefing)!;
    expect(next.at, DateTime(2026, 10, 1, 7, 30));
    expect(next.body, 'Graminacee moderate e Parietaria alta (stima).');
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

  test('allerta per domani: se domani un allergene arriva al livello che dà fastidio', () {
    final m = of(schedule(DateTime(2026, 9, 30, 12)), AlertKind.tomorrow)!;
    expect(m.at, DateTime(2026, 9, 30, 19));
    expect(m.title, 'Domani a Lecce');
    expect(m.body, 'Graminacee moderate (14 granuli/m³).');
    expect(
      of(schedule(DateTime(2026, 9, 30, 12), followed: [grass(Level.none, Level.low, 3)]), AlertKind.tomorrow),
      isNull,
    );
    expect(
      of(
        schedule(DateTime(2026, 9, 30, 12), followed: [grass(Level.moderate, Level.moderate, 12)]),
        AlertKind.tomorrow,
      ),
      isNotNull,
    );
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

  test('meteo negli avvisi: il mattino dice l’evento del giorno, la sera quello di domani', () {
    final times = [for (var h = 0; h < 48; h++) day.add(Duration(hours: h))];
    List<double?> hours(Map<int, double> m) => [for (var h = 0; h < 48; h++) m[h] ?? 0];
    final weather = HourlyWeather(times, {
      'weather_code': hours({17: 95}),
      'precipitation': hours({}),
      'wind_speed_10m': hours({35: 40}),
    });
    expect(
      of(schedule(DateTime(2026, 9, 30, 7), weather: weather), AlertKind.briefing)!.body,
      'Parietaria alta (stima). Gli altri sono più bassi. Temporale verso le 17: attenzione se hai l’asma.',
    );
    expect(
      of(schedule(DateTime(2026, 9, 30, 12), weather: weather), AlertKind.tomorrow)!.body,
      'Graminacee moderate (14 granuli/m³). Vento forte dalle 11: più pollini in aria.',
    );
    final calm = [grass(Level.none, Level.none, 0)];
    expect(
      of(schedule(DateTime(2026, 9, 30, 7), followed: calm, weather: weather), AlertKind.briefing)!.body,
      'Nessun allergene da tenere d’occhio.',
    );
  });

  test('il livello si accorda con il nome dell’allergene', () {
    expect(Allergens.grass.at(Level.high), 'Graminacee alte');
    expect(Allergens.parietaria.at(Level.moderate), 'Parietaria moderata');
    expect(Allergens.olive.at(Level.veryHigh), 'Olivo molto alto');
    expect(Allergens.birch.at(Level.low), 'Betulla e ontano bassi');
    expect(Allergens.alternaria.at(Level.none), 'Alternaria assente');
  });

  test('altri allergeni allo stesso livello ma sotto il loro «Segnala da»: non si dice «più bassi»', () {
    final olive = AllergenStatus(
      allergen: Allergens.olive,
      kind: DataKind.forecast,
      level: Level.moderate,
      value: 30,
      series: [DayValue(day, 30, Level.moderate)],
    );
    final body = planner
        .schedule(
          now: DateTime(2026, 9, 30, 7),
          settings: const AlertSettings(),
          placeName: 'Lecce',
          followed: [grass(Level.moderate, Level.moderate, 14), olive],
          thresholdOf: (a) => a == Allergens.olive ? Level.high : Level.moderate,
          diaryDoneToday: false,
        )
        .firstWhere((m) => m.kind == AlertKind.briefing)
        .body;
    expect(body, 'Graminacee moderate. Gli altri non sono da tenere d’occhio.');
  });

  test('meteo nell’avviso del mattino: un evento all’ora dell’avviso resta una previsione', () {
    final times = [for (var h = 0; h < 24; h++) day.add(Duration(hours: h))];
    final weather = HourlyWeather(times, {
      'precipitation': [for (var h = 0; h < 24; h++) h == 8 ? 3.0 : 0.0],
    });
    expect(
      of(schedule(DateTime(2026, 9, 30, 6), weather: weather), AlertKind.briefing)!.body,
      contains('Pioggia dalle 7: pollini in calo.'),
    );
  });
}
