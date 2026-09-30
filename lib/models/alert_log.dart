import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../services/alert_planner.dart';

/// Un avviso mandato dall'app, per l'elenco della campanella.
class AlertLogEntry {
  const AlertLogEntry({required this.kind, required this.title, required this.body, required this.at});

  final AlertKind kind;
  final String title;
  final String body;
  final DateTime at;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'title': title, 'body': body, 'at': at.toIso8601String()};

  static AlertLogEntry? fromJson(Map<String, dynamic> j) {
    final kind = AlertKind.values.asNameMap()[j['kind']];
    final at = DateTime.tryParse(j['at'] as String? ?? '');
    if (kind == null || at == null) return null;
    return AlertLogEntry(kind: kind, title: j['title'] as String? ?? '', body: j['body'] as String? ?? '', at: at);
  }
}

/// Registro degli ultimi avvisi, in SharedPreferences. Non va nel backup.
abstract final class AlertLog {
  static const key = 'alerts_log';
  static const max = 30;

  /// Dal più recente.
  static List<AlertLogEntry> read(SharedPreferences prefs) {
    final raw = prefs.getString(key);
    if (raw == null) return const [];
    try {
      return [for (final e in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) ?AlertLogEntry.fromJson(e)]
        ..sort((a, b) => b.at.compareTo(a.at));
    } on Object {
      return const [];
    }
  }

  static Future<void> add(SharedPreferences prefs, List<AlertLogEntry> entries) async {
    if (entries.isEmpty) return;
    final all = [...entries, ...read(prefs)]..sort((a, b) => b.at.compareTo(a.at));
    await prefs.setString(key, jsonEncode(all.take(max).map((e) => e.toJson()).toList()));
  }
}
