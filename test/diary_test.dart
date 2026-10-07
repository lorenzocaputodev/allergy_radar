import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/diary_entry.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/models/pollen_snapshot.dart';
import 'package:allergy_radar/state/diary_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final today = DateTime(2026, 9, 30);

  DiaryEntry entry(int daysAgo, int symptom, int parietaria) => DiaryEntry(
    date: today.subtract(Duration(days: daysAgo)),
    nose: symptom,
    eyes: symptom,
    pollen: {Allergens.parietaria.id: parietaria},
  );

  group('DiaryEntry', () {
    test('punteggio e classe del giorno', () {
      expect(DiaryEntry(date: today, nose: 2, eyes: 1).severity, 2);
      expect(DiaryEntry(date: today, eyes: 3).severity, 3);
      expect(DiaryEntry(date: today).severity, 0);
      expect(DiaryEntry(date: today, throat: 1).score, 1.0);
    });

    test('JSON andata e ritorno', () {
      final e = DiaryEntry(
        date: today,
        nose: 2,
        badSleep: true,
        meds: const ['Cetirizina'],
        outdoor: 1,
        note: 'finestre aperte',
        pollen: const {'parietaria': 3},
      );
      final back = DiaryEntry.fromJson(e.toJson());
      expect(back.key, '2026-09-30');
      expect(back.nose, 2);
      expect(back.badSleep, isTrue);
      expect(back.meds, ['Cetirizina']);
      expect(back.outdoor, 1);
      expect(back.note, 'finestre aperte');
      expect(back.pollen, {'parietaria': 3});
    });
  });

  group('DiaryState', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('salva, rilegge dalle preferenze ed elimina', () async {
      final prefs = await SharedPreferences.getInstance();
      final d = DiaryState(prefs);
      await d.save(entry(0, 2, 3));
      await d.save(entry(1, 1, 2));
      expect(DiaryState(prefs).entries.map((e) => e.key), ['2026-09-30', '2026-09-29']);
      await d.delete(today);
      expect(DiaryState(prefs).entryFor(today), isNull);
    });

    test('farmaci: niente duplicati né nomi vuoti', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      await d.addMedication('Cetirizina');
      await d.addMedication(' Cetirizina ');
      await d.addMedication('  ');
      expect(d.medications.where((m) => m == 'Cetirizina'), hasLength(1));
      await d.removeMedication('Cetirizina');
      expect(d.medications, isNot(contains('Cetirizina')));
    });

    test('confronto: servono almeno 14 giorni', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      for (var i = 0; i < 13; i++) {
        await d.save(entry(i, i.isEven ? 3 : 0, i.isEven ? 3 : 1));
      }
      expect(d.insight(Allergens.parietaria, today, threshold: Level.moderate), isNull);
    });

    test('confronto: sintomi più alti con Parietaria sopra la soglia', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      for (var i = 0; i < 20; i++) {
        final high = i < 10;
        await d.save(entry(i, high ? 2 : 0, high ? 3 : 1));
      }
      final r = d.insight(Allergens.parietaria, today, threshold: Level.moderate)!;
      expect(r.days, 20);
      expect(r.highDays, 10);
      expect(r.highMean, 2.0);
      expect(r.lowMean, 0);
      expect(r.clear, isTrue);
    });

    test('confronto: divide sulla soglia personale', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      for (var i = 0; i < 20; i++) {
        await d.save(entry(i, i < 10 ? 2 : 0, i < 10 ? 3 : 2));
      }
      expect(d.insight(Allergens.parietaria, today, threshold: Level.moderate), isNull, reason: 'tutti sopra');
      final r = d.insight(Allergens.parietaria, today, threshold: Level.high)!;
      expect(r.highDays, 10);
      expect(r.lowDays, 10);
    });

    test('confronto: punteggio sintomi + farmaci (CSMS)', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      for (var i = 0; i < 20; i++) {
        final high = i < 10;
        await d.save(entry(i, 1, high ? 3 : 1).copyWith(meds: high ? ['Spray nasale al cortisone'] : []));
      }
      final r = d.insight(Allergens.parietaria, today, threshold: Level.moderate)!;
      expect(r.highMean, 3.0);
      expect(r.lowMean, 1.0);
      expect(r.clear, isTrue, reason: 'stessi sintomi, ma con il cortisone');
    });

    test('farmaci: cortisone 2, antistaminici, colliri e farmaci aggiunti 1, il più alto del giorno', () {
      expect(DiaryEntry.medicationScore('Spray nasale al cortisone'), 2);
      expect(DiaryEntry.medicationScore('Cetirizina'), 1);
      expect(DiaryEntry.medicationScore('Collirio antistaminico'), 1);
      expect(
        DiaryEntry(date: today, nose: 2, meds: const ['Cetirizina', 'Spray nasale al cortisone']).combinedScore,
        4,
      );
      expect(DiaryEntry(date: today, nose: 2).combinedScore, 2);
    });

    test('misure arrivate dopo: completano le voci dello stesso luogo, non le altre', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      const bologna = Place(name: 'Bologna', lat: 44.49, lon: 11.34);
      final day = today.subtract(const Duration(days: 5));
      await d.save(DiaryEntry(date: day, nose: 1, place: bologna.cacheKey));
      await d.save(DiaryEntry(date: day.subtract(const Duration(days: 1)), nose: 1, place: Place.lecce.cacheKey));
      final snap = PollenSnapshot(
        place: bologna,
        fetchedAt: today,
        air: const AirStatus(),
        area: Area.north,
        statuses: {
          Allergens.parietaria.id: AllergenStatus(
            allergen: Allergens.parietaria,
            kind: DataKind.measured,
            level: Level.high,
            series: [DayValue(day, 73, Level.high), DayValue(day.subtract(const Duration(days: 1)), 10, Level.low)],
          ),
        },
      );
      await d.fillMeasured(snap);
      expect(d.entryFor(day)!.pollen[Allergens.parietaria.id], Level.high.index);
      expect(d.entryFor(day.subtract(const Duration(days: 1)))!.pollen, isEmpty);
      expect(DiaryState(await SharedPreferences.getInstance()).entryFor(day)!.pollen, isNotEmpty);
    });

    test('confronto: le voci fuori periodo non contano', () async {
      final d = DiaryState(await SharedPreferences.getInstance());
      for (var i = 40; i < 60; i++) {
        await d.save(entry(i, 2, 3));
      }
      expect(d.insight(Allergens.parietaria, today, threshold: Level.moderate), isNull);
    });
  });

  group('farmaci', () {
    test('la lista iniziale delle prime versioni passa ai principi attivi comuni', () async {
      SharedPreferences.setMockInitialValues({
        DiaryState.kMeds: ['Antistaminico', 'Spray nasale', 'Collirio'],
      });
      expect(DiaryState(await SharedPreferences.getInstance()).medications, DiaryState.defaultMedications);
    });

    test('una lista modificata da chi usa l’app resta com’è', () async {
      SharedPreferences.setMockInitialValues({
        DiaryState.kMeds: ['Antistaminico', 'Mometasone'],
      });
      expect(DiaryState(await SharedPreferences.getInstance()).medications, ['Antistaminico', 'Mometasone']);
    });
  });
}
