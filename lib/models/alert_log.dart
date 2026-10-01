import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_planner.dart';

/// Registro degli avvisi per la campanella, in SharedPreferences. Non va nel backup.
///
/// Un avviso programmato arriva senza far girare l'app: si salva quando lo si programma
/// ([setPending]) e conta come arrivato quando il suo orario è passato.
abstract final class AlertLog {
  static const key = 'alerts_log';
  static const pendingKey = 'alerts_pending';
  static const max = 30;

  /// Avvisi arrivati, dal più recente.
  static List<AlertMessage> read(SharedPreferences prefs, DateTime now) {
    final all = [
      ..._decode(prefs.getString(key)),
      ..._decode(prefs.getString(pendingKey)).where((m) => !m.at.isAfter(now)),
    ]..sort((a, b) => b.at.compareTo(a.at));
    return all.take(max).toList();
  }

  /// Sostituisce gli avvisi programmati; quelli già arrivati passano nel registro.
  static Future<void> setPending(SharedPreferences prefs, List<AlertMessage> pending, DateTime now) async {
    await prefs.setString(key, _encode(read(prefs, now)));
    await prefs.setString(pendingKey, _encode(pending));
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
