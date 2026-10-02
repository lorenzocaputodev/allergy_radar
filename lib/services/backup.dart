import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../models/place.dart';
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
    // Ogni valore si legge come lo leggerà l'app: un diario rotto bloccherebbe l'avvio.
    final values = <String, Object>{};
    for (final k in _keys) {
      final v = data[k];
      if (v == null) continue;
      try {
        values[k] = _check(k, v);
      } on Object {
        throw const FormatException('Il backup contiene dati non validi.');
      }
    }
    final diaryRaw = values[DiaryState.kEntries];
    final entries = diaryRaw is String ? (jsonDecode(diaryRaw) as List).length : 0;
    for (final k in _keys) {
      await prefs.remove(k);
    }
    for (final MapEntry(:key, :value) in values.entries) {
      switch (value) {
        case final String s:
          await prefs.setString(key, s);
        case final bool b:
          await prefs.setBool(key, b);
        case final List<String> l:
          await prefs.setStringList(key, l);
      }
    }
    return entries;
  }

  /// Il valore da salvare per la chiave [k], se è quello che l'app si aspetta. Altrimenti lancia.
  static Object _check(String k, Object v) {
    Map<String, dynamic> map(Object s) => jsonDecode(s as String) as Map<String, dynamic>;
    switch (k) {
      case AppState.kPlace:
        Place.fromJson(map(v));
      case AppState.kThresholds:
        map(v).forEach((_, l) => Level.fromIndex(l as int));
      case AppState.kAlerts:
        AlertSettings.fromJson(map(v));
      case DiaryState.kEntries:
        for (final e in jsonDecode(v as String) as List) {
          DiaryEntry.fromJson(e as Map<String, dynamic>);
        }
      case AppState.kFollowed || DiaryState.kMeds:
        return (v as List).cast<String>().toList();
      case AppState.kOnboarded:
        return v as bool;
    }
    return v as String;
  }

  /// Diario in CSV: separatore «;» e BOM UTF-8, come si aspetta Excel in italiano.
  /// Colonne dei pollini: prima gli allergeni seguiti, poi gli altri.
  static String diaryCsv(List<DiaryEntry> entries, {List<Allergen> followed = const []}) {
    final allergens = [...followed, ...Allergens.all.where((a) => !followed.contains(a))];
    String cell(Object? v) {
      final s = '${v ?? ''}';
      return s.contains(RegExp('[;"\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    const outdoor = ['meno di 1 ora', '1-3 ore', 'più di 3 ore'];
    final rows = <List<Object?>>[
      [
        'data',
        'naso (0-3)',
        'occhi (0-3)',
        'gola (0-3)',
        'respiro (0-3)',
        'intensità (0-3)',
        'sonno disturbato',
        'farmaci',
        'ore all’aperto',
        'nota',
        for (final a in allergens) a.name,
      ],
      for (final e in entries.reversed)
        [
          e.key,
          e.nose,
          e.eyes,
          e.throat,
          e.breath,
          e.severity,
          e.badSleep ? 'sì' : 'no',
          e.meds.join(', '),
          e.outdoor == null ? '' : outdoor[e.outdoor!],
          e.note,
          for (final a in allergens) e.pollen[a.id] == null ? '' : Level.fromIndex(e.pollen[a.id]!).label,
        ],
    ];
    return '﻿${rows.map((r) => r.map(cell).join(';')).join('\n')}\n';
  }
}
