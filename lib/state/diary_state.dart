import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../utils/days.dart';

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

  final int days;

  final int highDays;
  final int lowDays;

  final double highMean;
  final double lowMean;

  static const maxScore = 6;

  bool get clear => (highMean - lowMean).abs() >= 1;
}

class DiaryState extends ChangeNotifier {
  DiaryState(this._prefs) {
    _read();
  }

  final SharedPreferences _prefs;

  static const kEntries = 'diary';
  static const kMeds = 'medications';
  static const backupKeys = [kEntries, kMeds];

  static const defaultMedications = [
    'Cetirizina',
    'Levocetirizina',
    'Loratadina',
    'Desloratadina',
    'Bilastina',
    'Fexofenadina',
    'Spray nasale al cortisone',
    'Collirio antistaminico',
  ];
  static const _oldDefaults = ['Antistaminico', 'Spray nasale', 'Collirio'];

  static const minDaysForInsight = 14;

  final Map<String, DiaryEntry> _entries = {};
  List<String> medications = defaultMedications;

  // --- Caricamento ---
  void _read() {
    _entries.clear();
    final raw = _prefs.getString(kEntries);
    if (raw != null) {
      for (final e in (jsonDecode(raw) as List).cast<Map<String, dynamic>>()) {
        final entry = DiaryEntry.fromJson(e);
        _entries[entry.key] = entry;
      }
    }
    final saved = _prefs.getStringList(kMeds);
    medications = saved == null || listEquals(saved, _oldDefaults) ? defaultMedications : saved;
  }

  void reload() {
    _read();
    notifyListeners();
  }

  // --- Voci ---
  DiaryEntry? entryFor(DateTime d) => _entries[DiaryEntry.keyOf(d)];

  List<DiaryEntry> get entries => _entries.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  List<DiaryEntry> between(DateTime from, DateTime to) {
    final start = from.dateOnly;
    final end = to.dateOnly;
    return _entries.values.where((e) => !e.date.isBefore(start) && !e.date.isAfter(end)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

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

  // --- Farmaci ---
  Future<void> addMedication(String name) async {
    final n = name.trim();
    if (n.isEmpty || medications.contains(n)) return;
    medications = [...medications, n];
    notifyListeners();
    await _prefs.setStringList(kMeds, medications);
  }

  Future<void> removeMedication(String name) async {
    medications = medications.where((m) => m != name).toList();
    notifyListeners();
    await _prefs.setStringList(kMeds, medications);
  }

  Future<void> _persist() => _prefs.setString(kEntries, jsonEncode(_entries.values.map((e) => e.toJson()).toList()));

  // --- Misure arrivate dopo ---
  Future<void> fillMeasured(PollenSnapshot snap) async {
    var changed = false;
    for (final st in snap.statuses.values.where((s) => s.kind == DataKind.measured)) {
      for (final d in st.series) {
        final e = entryFor(d.date);
        if (e == null || e.place != snap.place.cacheKey || e.pollen[st.allergen.id] == d.level.index) continue;
        _entries[e.key] = e.copyWith(pollen: {...e.pollen, st.allergen.id: d.level.index});
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    await _persist();
  }

  // --- Confronto ---
  List<DiaryEntry> withLevel(Allergen a, DateTime now, int days) =>
      between(now.plusDays(1 - days), now).where((e) => e.pollen.containsKey(a.id)).toList();

  DiaryInsight? insight(Allergen a, DateTime now, {required Level threshold, int days = 30}) {
    final list = withLevel(a, now, days);
    if (list.length < minDaysForInsight) return null;
    final high = list.where((e) => e.pollen[a.id]! >= threshold.index).toList();
    final low = list.where((e) => e.pollen[a.id]! < threshold.index).toList();
    if (high.length < 3 || low.length < 3) return null;
    double mean(List<DiaryEntry> l) => l.fold<double>(0, (s, e) => s + e.combinedScore) / l.length;
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
