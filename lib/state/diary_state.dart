import 'dart:async';
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

  static const maxScore = 5;

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
    _entries
      ..clear()
      ..addEntries(_stored().map((e) => MapEntry(e.key, e)));
    final saved = _prefs.getStringList(kMeds);
    medications = saved == null || listEquals(saved, _oldDefaults) ? defaultMedications : saved;
  }

  Iterable<DiaryEntry> _stored() sync* {
    final raw = _prefs.getString(kEntries);
    final list = raw == null ? null : _tryDecode(raw);
    for (final e in list is List ? list : const []) {
      try {
        yield DiaryEntry.fromJson(e as Map<String, dynamic>);
      } on Object {
        continue;
      }
    }
  }

  static Object? _tryDecode(String raw) {
    try {
      return jsonDecode(raw);
    } on Object {
      return null;
    }
  }

  void reload() {
    _read();
    notifyListeners();
    if (_measured case final snap?) unawaited(fillMeasured(snap));
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

  Future<bool> saveNoSymptoms(DateTime day, {PollenSnapshot? snapshot}) async {
    if (entryFor(day) != null) return false;
    final d = DiaryEntry.day(day);
    await save(DiaryEntry(date: d, pollen: snapshot?.levelsOn(d) ?? const {}, place: snapshot?.place.cacheKey));
    return true;
  }

  Future<void> delete(DateTime d) async {
    final key = DiaryEntry.keyOf(d);
    _entries.remove(key);
    notifyListeners();
    await _persist(removed: key);
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

  Future<void> _persist({String? removed}) async {
    final mine = Map.of(_entries);
    await _prefs.reload();
    for (final e in _stored()) {
      if (e.key != removed && !mine.containsKey(e.key)) mine[e.key] = e;
    }
    await _prefs.setString(kEntries, jsonEncode(mine.values.map((e) => e.toJson()).toList()));
    _entries
      ..clear()
      ..addAll(mine);
    notifyListeners();
  }

  // --- Misure arrivate dopo ---
  PollenSnapshot? _measured;

  Future<void> fillMeasured(PollenSnapshot snap) async {
    _measured = snap;
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
