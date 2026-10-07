import 'package:allergy_radar/models/alert_log.dart';
import 'package:allergy_radar/services/alert_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final day = DateTime(2026, 10, 1);
  AlertMessage at(int hour, [AlertKind kind = AlertKind.briefing]) =>
      AlertMessage(kind, day.add(Duration(hours: hour)), 'Avviso delle $hour', 'Testo');
  DateTime time(int hour, [int minute = 0]) => day.add(Duration(hours: hour, minutes: minute));

  group('split', () {
    final stored = [at(8), at(21, AlertKind.diary)];
    bool all(AlertKind _) => true;

    test('arrivato solo se Android l’ha già mostrato', () {
      final s = AlertLog.split(stored, unfired: {AlertKind.diary}, now: time(9), wanted: all);
      expect(s.arrived.map((m) => m.title), ['Avviso delle 8']);
      expect(s.late, isEmpty);
    });

    test('in ritardo resta in attesa se ancora voluto e da meno di un’ora', () {
      final s = AlertLog.split(stored, unfired: {AlertKind.briefing, AlertKind.diary}, now: time(8, 20), wanted: all);
      expect(s.arrived, isEmpty);
      expect(s.late.single.kind, AlertKind.briefing);
    });

    test('in ritardo ma non più voluto o troppo vecchio: né arrivato né in attesa', () {
      final unfired = {AlertKind.briefing, AlertKind.diary};
      final off = AlertLog.split(stored, unfired: unfired, now: time(8, 20), wanted: (k) => k != AlertKind.briefing);
      expect(off.late, isEmpty);
      expect(off.arrived, isEmpty);
      final old = AlertLog.split(stored, unfired: unfired, now: time(9, 30), wanted: all);
      expect(old.late, isEmpty);
      expect(old.arrived, isEmpty);
    });

    test('i futuri non sono né arrivati né in ritardo', () {
      final s = AlertLog.split(stored, unfired: const {}, now: time(7), wanted: all);
      expect(s.arrived, isEmpty);
      expect(s.late, isEmpty);
    });
  });

  test('registro: al massimo ${AlertLog.max} voci, dal più recente, senza doppioni', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (var h = 0; h < 40; h++) {
      await AlertLog.update(prefs, pending: const [], arrived: [at(h), at(h)]);
    }
    final log = AlertLog.read(prefs);
    expect(log, hasLength(AlertLog.max));
    expect(log.first.title, 'Avviso delle 39');
  });

  test('update salva gli in sospeso e aggiunge gli arrivati', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AlertLog.update(prefs, pending: [at(8), at(21, AlertKind.diary)], arrived: const []);
    expect(AlertLog.read(prefs), isEmpty);
    expect(await AlertLog.pending(prefs), hasLength(2));

    await AlertLog.update(prefs, pending: [at(21, AlertKind.diary)], arrived: [at(8)]);
    expect(AlertLog.read(prefs).single.title, 'Avviso delle 8');
    expect((await AlertLog.pending(prefs)).single.kind, AlertKind.diary);
  });

  test('swipe: l’avviso sparisce subito; Annulla lo rimette', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await AlertLog.update(prefs, pending: const [], arrived: [at(8), at(9)]);

    final removing = AlertLog.remove(prefs, at(9));
    expect(AlertLog.read(prefs).single.title, 'Avviso delle 8');
    await removing;
    await AlertLog.remove(prefs, at(8));
    expect(AlertLog.read(prefs), isEmpty);

    await AlertLog.restore(prefs, at(8));
    expect(AlertLog.read(prefs).single.title, 'Avviso delle 8');
  });

  test('registro rovinato: elenco vuoto, niente eccezioni', () async {
    SharedPreferences.setMockInitialValues({AlertLog.key: 'non json', AlertLog.pendingKey: '[{"kind":"x","at":"y"}]'});
    final prefs = await SharedPreferences.getInstance();
    expect(AlertLog.read(prefs), isEmpty);
    expect(await AlertLog.pending(prefs), isEmpty);
  });
}
