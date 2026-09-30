import 'package:allergy_radar/models/alert_log.dart';
import 'package:allergy_radar/services/alert_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  AlertLogEntry entry(int i) => AlertLogEntry(
    kind: AlertKind.briefing,
    title: 'Avviso $i',
    body: 'Testo',
    at: DateTime(2026, 9, 1).add(Duration(hours: i)),
  );

  test('registro: dal più recente, al massimo ${AlertLog.max} voci', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(AlertLog.read(prefs), isEmpty);
    for (var i = 0; i < 40; i++) {
      await AlertLog.add(prefs, [entry(i)]);
    }
    final log = AlertLog.read(prefs);
    expect(log, hasLength(AlertLog.max));
    expect(log.first.title, 'Avviso 39');
    expect(log.last.title, 'Avviso 10');
  });

  test('registro rovinato: elenco vuoto, niente eccezioni', () async {
    SharedPreferences.setMockInitialValues({AlertLog.key: 'non json'});
    expect(AlertLog.read(await SharedPreferences.getInstance()), isEmpty);
    SharedPreferences.setMockInitialValues({AlertLog.key: '[{"kind":"sconosciuto","at":"x"}]'});
    expect(AlertLog.read(await SharedPreferences.getInstance()), isEmpty);
  });
}
