import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_planner.dart';

abstract final class AlertLog {
  static const key = 'alerts_log';
  static const pendingKey = 'alerts_pending';
  static const max = 30;

  static List<AlertMessage> read(SharedPreferences prefs, DateTime now) => _merge([
    ..._decode(prefs.getString(key)),
    ..._decode(prefs.getString(pendingKey)).where((m) => !m.at.isAfter(now)),
  ]);

  static Future<List<AlertMessage>> pending(SharedPreferences prefs) async {
    await prefs.reload();
    return _decode(prefs.getString(pendingKey));
  }

  static Future<void> setPending(SharedPreferences prefs, List<AlertMessage> pending, DateTime now) async {
    await prefs.reload();
    final arrived = _decode(prefs.getString(pendingKey)).where((m) => !m.at.isAfter(now) && !pending.any(_same(m)));
    await prefs.setString(key, _encode(_merge([..._decode(prefs.getString(key)), ...arrived])));
    await prefs.setString(pendingKey, _encode(pending));
  }

  static Future<void> remove(SharedPreferences prefs, AlertMessage m, DateTime now) async {
    await _drop(prefs, m, now);
    await prefs.reload();
    await _drop(prefs, m, now);
  }

  static Future<void> _drop(SharedPreferences prefs, AlertMessage m, DateTime now) {
    final same = _same(m);
    final log = _decode(prefs.getString(key)).where((x) => !same(x)).toList();
    final pending = _decode(prefs.getString(pendingKey)).where((x) => !(same(x) && !x.at.isAfter(now))).toList();
    return Future.wait([prefs.setString(key, _encode(log)), prefs.setString(pendingKey, _encode(pending))]);
  }

  static Future<void> restore(SharedPreferences prefs, AlertMessage m) async {
    await prefs.reload();
    await prefs.setString(key, _encode(_merge([..._decode(prefs.getString(key)), m])));
  }

  static Future<SharedPreferences> fresh() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs;
  }

  static bool Function(AlertMessage) _same(AlertMessage m) =>
      (x) => x.kind == m.kind && x.at == m.at;

  static List<AlertMessage> _merge(List<AlertMessage> all) {
    final out = <AlertMessage>[];
    for (final m in all..sort((a, b) => b.at.compareTo(a.at))) {
      if (!out.any(_same(m))) out.add(m);
    }
    return out.take(max).toList();
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
