import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_planner.dart';

class AlertSplit {
  const AlertSplit({required this.arrived, required this.late});

  final List<AlertMessage> arrived;
  final List<AlertMessage> late;
}

abstract final class AlertLog {
  static const key = 'alerts_log';
  static const pendingKey = 'alerts_pending';
  static const max = 30;
  static const lateBy = Duration(hours: 1);

  static List<AlertMessage> read(SharedPreferences prefs) => _merge([..._decode(prefs.getString(key))]);

  static Future<List<AlertMessage>> pending(SharedPreferences prefs) async {
    await prefs.reload();
    return _decode(prefs.getString(pendingKey));
  }

  // --- Avvisi arrivati e in ritardo ---
  static AlertSplit split(
    List<AlertMessage> stored, {
    required Set<AlertKind> unfired,
    required DateTime now,
    required bool Function(AlertKind) wanted,
  }) => AlertSplit(
    arrived: [
      for (final m in stored)
        if (!m.at.isAfter(now) && !unfired.contains(m.kind)) m,
    ],
    late: [
      for (final m in stored)
        if (!m.at.isAfter(now) && unfired.contains(m.kind) && now.difference(m.at) < lateBy && wanted(m.kind)) m,
    ],
  );

  static Future<void> update(
    SharedPreferences prefs, {
    required List<AlertMessage> pending,
    required List<AlertMessage> arrived,
  }) async {
    await prefs.reload();
    await prefs.setString(key, _encode(_merge([..._decode(prefs.getString(key)), ...arrived])));
    await prefs.setString(pendingKey, _encode(pending));
  }

  static Future<void> remove(SharedPreferences prefs, AlertMessage m) async {
    await _drop(prefs, m);
    await prefs.reload();
    await _drop(prefs, m);
  }

  static Future<void> _drop(SharedPreferences prefs, AlertMessage m) =>
      prefs.setString(key, _encode(_decode(prefs.getString(key)).where((x) => !_same(m)(x)).toList()));

  static Future<void> restore(SharedPreferences prefs, AlertMessage m) async {
    await prefs.reload();
    await prefs.setString(key, _encode(_merge([..._decode(prefs.getString(key)), m])));
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
