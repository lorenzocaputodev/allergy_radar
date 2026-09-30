import 'dart:convert';

import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/diary_entry.dart';
import 'package:allergy_radar/services/backup.dart';
import 'package:allergy_radar/services/report_pdf.dart';
import 'package:allergy_radar/state/diary_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    expect(bytes.length, greaterThan(2000));
  });
}
