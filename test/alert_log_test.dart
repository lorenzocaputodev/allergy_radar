import 'package:allergy_radar/models/alert_log.dart';
import 'package:allergy_radar/services/alert_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final day = DateTime(2026, 10, 1);
  AlertMessage at(int hour, [AlertKind kind = AlertKind.briefing]) =>
      AlertMessage(kind, day.add(Duration(hours: hour)), 'Avviso delle $hour', 'Testo');

  test('gli avvisi programmati contano come arrivati quando passa il loro orario', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AlertLog.setPending(prefs, [at(8), at(21, AlertKind.diary)], day);
    expect(AlertLog.read(prefs, day.add(const Duration(hours: 7))), isEmpty);
    expect(AlertLog.read(prefs, day.add(const Duration(hours: 9))).single.title, 'Avviso delle 8');

    // Riprogrammando alle 20 il promemoria delle 21 viene sostituito; quello delle 8 resta nel registro.
    await AlertLog.setPending(prefs, [at(45, AlertKind.diary)], day.add(const Duration(hours: 20)));
    final log = AlertLog.read(prefs, day.add(const Duration(hours: 22)));
    expect(log.map((m) => m.title), ['Avviso delle 8']);
  });

  test('al massimo ${AlertLog.max} voci, dal più recente', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (var h = 0; h < 40; h++) {
      await AlertLog.setPending(prefs, [at(h)], day.add(Duration(hours: h)));
    }
    final log = AlertLog.read(prefs, day.add(const Duration(days: 3)));
    expect(log, hasLength(AlertLog.max));
    expect(log.first.title, 'Avviso delle 39');
  });

  test('swipe: l’avviso arrivato sparisce, quello futuro resta; Annulla lo rimette', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = day.add(const Duration(hours: 10));
    await AlertLog.setPending(prefs, [at(8)], day.add(const Duration(hours: 7)));
    await AlertLog.setPending(prefs, [at(9), at(21, AlertKind.diary)], day.add(const Duration(hours: 8, minutes: 30)));

    await AlertLog.remove(prefs, at(8), now);
    await AlertLog.remove(prefs, at(9), now);
    expect(AlertLog.read(prefs, now), isEmpty);
    expect(AlertLog.read(prefs, day.add(const Duration(hours: 22))).single.kind, AlertKind.diary);

    await AlertLog.restore(prefs, at(8));
    expect(AlertLog.read(prefs, now).single.title, 'Avviso delle 8');
  });

  test('registro rovinato: elenco vuoto, niente eccezioni', () async {
    SharedPreferences.setMockInitialValues({AlertLog.key: 'non json', AlertLog.pendingKey: '[{"kind":"x","at":"y"}]'});
    expect(AlertLog.read(await SharedPreferences.getInstance(), day), isEmpty);
  });
}
