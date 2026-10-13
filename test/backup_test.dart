import 'dart:convert';

import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/diary_entry.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/backup.dart';
import 'package:allergy_radar/services/report_pdf.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:allergy_radar/state/diary_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 30, 10);

  setUp(
    () => SharedPreferences.setMockInitialValues({
      'place': '{"name":"Lecce","region":"Puglia","lat":40.35,"lon":18.17}',
      'followed': ['grass', 'parietaria'],
      'onboarded': true,
      'cache': 'non va nel backup',
      'diary': jsonEncode([
        DiaryEntry(date: DateTime(2026, 9, 29), nose: 2, meds: const ['Cetirizina'], note: 'finestre; aperte').toJson(),
      ]),
    }),
  );

  test('esporta e ripristina impostazioni e diario, senza la cache', () async {
    final prefs = await SharedPreferences.getInstance();
    final json = Backup.export(prefs, now);
    expect(json, isNot(contains('non va nel backup')));

    await prefs.clear();
    final entries = await Backup.restore(prefs, json);
    expect(entries, 1);
    expect(prefs.getStringList('followed'), ['grass', 'parietaria']);
    expect(prefs.getBool('onboarded'), isTrue);
    expect(DiaryState(prefs).entryFor(DateTime(2026, 9, 29))!.meds, ['Cetirizina']);
  });

  test('i backup dell’app si reimportano, compresi luoghi salvati e «segui la mia posizione»', () async {
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(repository(now), prefs);
    await state.load();
    await state.setPlace(const Place(name: 'Roma', lat: 41.9, lon: 12.5));
    await state.startFollowing(Place.lecce);
    final json = Backup.export(prefs, now);
    for (final k in [AppState.kPlaces, AppState.kFollowLocation]) {
      expect(json, contains('"$k"'), reason: k);
    }

    await prefs.clear();
    await Backup.restore(prefs, json);
    final again = AppState(repository(now), prefs);
    await again.load();
    expect(again.followLocation, isTrue);
    expect(again.saved.first.name, 'Roma');
    expect(again.place.name, 'Lecce');
  });

  test('rifiuta file che non sono backup, senza toccare i dati', () async {
    final prefs = await SharedPreferences.getInstance();
    await expectLater(Backup.restore(prefs, 'ciao'), throwsA(isA<FormatException>()));
    await expectLater(Backup.restore(prefs, '{"app":"altro","data":{}}'), throwsA(isA<FormatException>()));
    await expectLater(
      Backup.restore(prefs, '{"app":"allergy_radar","format":99,"data":{}}'),
      throwsA(isA<FormatException>()),
    );
    expect(prefs.getBool('onboarded'), isTrue);
  });

  test('rifiuta backup con contenuti rotti, senza toccare i dati', () async {
    final prefs = await SharedPreferences.getInstance();
    String backup(Map<String, Object?> data) => jsonEncode({'app': 'allergy_radar', 'format': 1, 'data': data});
    for (final data in [
      {'diary': '[{"nose":1}]'},
      {'diary': '[{"date":"2026-09-29","nose":5}]'},
      {'diary': '[{"date":"2026-09-29","meds":[1]}]'},
      {'diary': '[{"date":"2026-09-29","pollen":{"grass":9}}]'},
      {'alerts': '{"briefingAt":5000}'},
      {'diary': 'non è json'},
      {'place': 'x'},
      {'place': '{"name":"Lecce"}'},
      {
        'followed': [1, 2],
      },
      {'thresholds': '{"grass":"alto"}'},
      {'onboarded': 'sì'},
    ]) {
      await expectLater(Backup.restore(prefs, backup(data)), throwsA(isA<FormatException>()), reason: '$data');
    }
    expect(prefs.getBool('onboarded'), isTrue);
    expect(prefs.getStringList('followed'), ['grass', 'parietaria']);
    expect(DiaryState(prefs).entries, hasLength(1));
  });

  test('CSV: intestazione, separatore e campi con «;» tra virgolette', () async {
    final csv = Backup.diaryCsv(
      DiaryState(await SharedPreferences.getInstance()).entries,
      followed: [Allergens.parietaria, Allergens.grass],
    );
    expect(csv, startsWith('﻿'), reason: 'BOM per Excel');
    final lines = csv.substring(1).trim().split('\n');
    expect(lines.first, startsWith('data;naso (0-3);occhi (0-3);gola (0-3);respiro (0-3);intensità (0-3);'));
    expect(lines.first, contains('nota;Parietaria;Graminacee;Olivo'), reason: 'prima gli allergeni seguiti');
    expect(lines[1], startsWith('2026-09-29;2;0;0;0;2;no;Cetirizina;;"finestre; aperte"'));
  });

  test('PDF per l’allergologo', () async {
    final diary = DiaryState(await SharedPreferences.getInstance());
    final bytes = await ReportPdf.build(
      diary: diary,
      allergens: [Allergens.grass, Allergens.parietaria],
      placeName: 'Lecce',
      now: now,
      thresholdOf: (_) => Level.moderate,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
  });

  test('PDF con tutti gli allergeni e una nota lunga', () async {
    final diary = DiaryState(await SharedPreferences.getInstance());
    for (var i = 0; i < 20; i++) {
      await diary.save(
        DiaryEntry(
          date: now.subtract(Duration(days: i)),
          nose: i % 4,
          meds: const ['Cetirizina', 'Spray nasale al cortisone'],
          note: 'Giornata ventosa, finestre aperte tutto il pomeriggio e passeggiata al parco ' * 3,
          pollen: {for (final a in Allergens.all) a.id: i % 5},
        ),
      );
    }
    final bytes = await ReportPdf.build(
      diary: diary,
      allergens: Allergens.all,
      placeName: 'Lecce',
      now: now,
      thresholdOf: (_) => Level.moderate,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('un formato non numerico è un backup non valido', () async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode({'app': 'allergy_radar', 'format': 'uno', 'data': <String, Object>{}});
    expect(
      () => Backup.restore(prefs, json),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', 'Il file non è un backup valido.')),
    );
  });

  test('CSV: un ritorno a capo nella nota resta nella cella', () {
    final csv = Backup.diaryCsv([DiaryEntry(date: DateTime(2026, 9, 29), note: 'prima\rdopo')]);
    expect(csv, contains('"prima\rdopo"'));
  });
}
