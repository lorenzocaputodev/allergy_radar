import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_planner.dart';

abstract final class AlertLog {
  static const key = 'alerts_log';
  static const pendingKey = 'alerts_pending';
  static const max = 30;

  static List<AlertMessage> read(SharedPreferences prefs, DateTime now) {
    final all = [
      ..._decode(prefs.getString(key)),
      ..._decode(prefs.getString(pendingKey)).where((m) => !m.at.isAfter(now)),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return all.take(max).toList();
  }

  /// Sostituisce gli avvisi programmati; quelli già arrivati passano nel registro.
  static Future<void> setPending(SharedPreferences prefs, List<AlertMessage> pending, DateTime now) async {
    await prefs.reload();
    await prefs.setString(key, _encode(read(prefs, now)));
    await prefs.setString(pendingKey, _encode(pending));
  }

  static Future<void> remove(SharedPreferences prefs, AlertMessage m, DateTime now) async {
    bool same(AlertMessage x) => x.kind == m.kind && x.at == m.at;
    await prefs.setString(key, _encode(_decode(prefs.getString(key)).where((x) => !same(x)).toList()));
    // Fra i programmati si toglie solo se è già arrivato: quelli futuri devono restare.
    final pending = _decode(prefs.getString(pendingKey)).where((x) => !(same(x) && !x.at.isAfter(now))).toList();
    await prefs.setString(pendingKey, _encode(pending));
  }

  static Future<void> restore(SharedPreferences prefs, AlertMessage m) =>
      prefs.setString(key, _encode([..._decode(prefs.getString(key)), m]));

  static Future<SharedPreferences> fresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static String _encode(List<AlertMessage> list) => jsonEncode([
    for (final m in list) {'kind': m.kind.name, 'at': m.at.toIso8601String(), 'title': m.title, 'body': m.body},
  ]);

  static List<AlertMessage> _decode(String? raw) {
    if (raw == null) return const [];
    try {
      final out = <AlertMessage>[];
      for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
        final kind = AlertKind.values.asNameMap()[j['kind']];
        final at = DateTime.tryParse(j['at'] as String? ?? '');
        if (kind != null && at != null) {
          out.add(AlertMessage(kind, at, j['title'] as String? ?? '', j['body'] as String? ?? ''));
        }
      }
      return out;
    } on Object {
      return const [];
    }
  }
}
