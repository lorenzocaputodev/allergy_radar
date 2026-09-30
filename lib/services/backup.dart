import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';

/// Backup in JSON di impostazioni e diario, ed esportazione del diario in CSV.
class Backup {
  static const _app = 'allergy_radar';
  static const _format = 1;

  static List<String> get _keys => [...AppState.backupKeys, ...DiaryState.backupKeys];

  static String export(SharedPreferences prefs, DateTime now) {
    final data = <String, Object?>{};
    for (final k in _keys) {
      final v = prefs.get(k);
      if (v != null) data[k] = v;
    }
    return const JsonEncoder.withIndent('  ')
        .convert({'app': _app, 'format': _format, 'exportedAt': now.toIso8601String(), 'data': data});
  }

  /// Ripristina un backup. Lancia [FormatException] se il file non è un backup di questa app.
  /// Restituisce quante voci del diario contiene.
  static Future<int> restore(SharedPreferences prefs, String json) async {
    final Map<String, dynamic> root;
    try {
      root = jsonDecode(json) as Map<String, dynamic>;
    } on Object {
      throw const FormatException('Il file non è un backup valido.');
    }
    if (root['app'] != _app || root['data'] is! Map) {
      throw const FormatException('Il file non è un backup di Allergy Radar.');
    }
    if ((root['format'] as int? ?? 0) > _format) {
      throw const FormatException('Il backup viene da una versione più recente dell’app: aggiornala.');
    }
    final data = (root['data'] as Map).cast<String, Object?>();
    // Prima si verifica tutto, poi si scrive: un file a metà non lascia l'app a metà.
    for (final e in data.entries) {
      if (!_keys.contains(e.key)) continue;
      final v = e.value;
      if (v is! String && v is! bool && v is! int && v is! double && v is! List) {
        throw const FormatException('Il backup contiene dati non validi.');
      }
    }
    final diaryRaw = data[DiaryState.kEntries];
    final entries = diaryRaw is String ? (jsonDecode(diaryRaw) as List).length : 0;
    for (final k in _keys) {
      await prefs.remove(k);
    }
    for (final e in data.entries) {
      if (!_keys.contains(e.key)) continue;
      final v = e.value;
      switch (v) {
        case final String s:
          await prefs.setString(e.key, s);
        case final bool b:
          await prefs.setBool(e.key, b);
        case final int i:
          await prefs.setInt(e.key, i);
        case final double d:
          await prefs.setDouble(e.key, d);
        case final List l:
          await prefs.setStringList(e.key, l.cast<String>());
      }
    }
    return entries;
  }

  /// Diario in CSV (separatore «;», come si aspetta Excel in italiano).
  static String diaryCsv(List<DiaryEntry> entries) {
    String cell(Object? v) {
      final s = '${v ?? ''}';
      return s.contains(RegExp('[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    const outdoor = ['meno di 1 ora', '1-3 ore', 'più di 3 ore'];
    final rows = <List<Object?>>[
      [
        'data',
        'naso',
        'occhi',
        'gola',
        'respiro',
        'intensita_giorno',
        'sonno_disturbato',
        'farmaci',
        'ore_aperto',
        'nota',
        for (final a in Allergens.all) a.name,
      ],
      for (final e in entries.reversed)
        [
          e.key,
          e.nose,
          e.eyes,
          e.throat,
          e.breath,
          e.severity,
          e.badSleep ? 'si' : 'no',
          e.meds.join(', '),
          e.outdoor == null ? '' : outdoor[e.outdoor!],
          e.note,
          for (final a in Allergens.all) e.pollen[a.id] == null ? '' : Level.fromIndex(e.pollen[a.id]!).label,
        ],
    ];
    return '${rows.map((r) => r.map(cell).join(';')).join('\n')}\n';
  }
}
