import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';

/// Confronto tra sintomi e un allergene nel periodo.
class DiaryInsight {
  const DiaryInsight({
    required this.allergen,
    required this.days,
    required this.highDays,
    required this.lowDays,
    required this.highMean,
    required this.lowMean,
  });

  final Allergen allergen;

  /// Giorni registrati nel periodo.
  final int days;

  /// Giorni con l'allergene da moderato in su, e sotto.
  final int highDays;
  final int lowDays;

  /// Sintomi medi (0–3) nei due gruppi.
  final double highMean;
  final double lowMean;

  /// Differenza abbastanza netta da dirla (almeno mezzo punto su 3).
  bool get clear => (highMean - lowMean).abs() >= 0.5;
}

class DiaryState extends ChangeNotifier {
  DiaryState(this._prefs) {
    final raw = _prefs.getString(_kEntries);
    if (raw != null) {
      for (final e in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
        final entry = DiaryEntry.fromJson(e);
        _entries[entry.key] = entry;
      }
    }
    final meds = _prefs.getStringList(_kMeds);
    if (meds != null) medications = meds;
  }

  final SharedPreferences _prefs;

  static const _kEntries = 'diary';
  static const _kMeds = 'medications';

  /// Servono almeno questi giorni registrati per un confronto.
  static const minDaysForInsight = 14;

  final Map<String, DiaryEntry> _entries = {};
  List<String> medications = ['Antistaminico', 'Spray nasale', 'Collirio'];

  DiaryEntry? entryFor(DateTime d) => _entries[DiaryEntry.keyOf(d)];

  /// Dal più recente.
  List<DiaryEntry> get entries => _entries.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  List<DiaryEntry> between(DateTime from, DateTime to) => entries
      .where((e) => !e.date.isBefore(DiaryEntry.day(from)) && !e.date.isAfter(DiaryEntry.day(to)))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));

  Future<void> save(DiaryEntry e) async {
    _entries[e.key] = e;
    notifyListeners();
    await _persist();
  }

  Future<void> delete(DateTime d) async {
    _entries.remove(DiaryEntry.keyOf(d));
    notifyListeners();
    await _persist();
  }

  Future<void> addMedication(String name) async {
    final n = name.trim();
    if (n.isEmpty || medications.contains(n)) return;
    medications = [...medications, n];
    notifyListeners();
    await _prefs.setStringList(_kMeds, medications);
  }

  Future<void> removeMedication(String name) async {
    medications = medications.where((m) => m != name).toList();
    notifyListeners();
    await _prefs.setStringList(_kMeds, medications);
  }

  Future<void> _persist() =>
      _prefs.setString(_kEntries, jsonEncode(_entries.values.map((e) => e.toJson()).toList()));

  /// Sintomi con l'allergene da moderato in su contro sotto, negli ultimi [days] giorni.
  /// Null se i dati non bastano.
  DiaryInsight? insight(Allergen a, DateTime now, {int days = 30}) {
    final list = between(now.subtract(Duration(days: days - 1)), now).where((e) => e.pollen.containsKey(a.id)).toList();
    if (list.length < minDaysForInsight) return null;
    final high = list.where((e) => e.pollen[a.id]! >= Level.moderate.index).toList();
    final low = list.where((e) => e.pollen[a.id]! < Level.moderate.index).toList();
    if (high.length < 3 || low.length < 3) return null;
    double mean(List<DiaryEntry> l) => l.fold<double>(0, (s, e) => s + e.score) / l.length;
    return DiaryInsight(
      allergen: a,
      days: list.length,
      highDays: high.length,
      lowDays: low.length,
      highMean: mean(high),
      lowMean: mean(low),
    );
  }
}
