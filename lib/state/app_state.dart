import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/pollen_repository.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';

class AppState extends ChangeNotifier {
  AppState(this._repo, this._prefs);

  final PollenRepository _repo;
  final SharedPreferences _prefs;

  static const _kPlace = 'place';
  static const _kFollowed = 'followed';
  static const _kThresholds = 'thresholds';
  static const _kCache = 'cache';

  /// Sotto quest'età i dati in cache non vengono richiesti di nuovo.
  static const freshFor = Duration(hours: 1);

  Place place = Place.lecce;
  Set<String> followed = {Allergens.grass.id, Allergens.parietaria.id};
  Map<String, Level> personal = {};

  PollenSnapshot? snapshot;
  bool loading = false;
  String? error;

  List<Allergen> get followedAllergens => Allergens.all.where((a) => followed.contains(a.id)).toList();

  Level thresholdOf(Allergen a) => personal[a.id] ?? Level.moderate;

  List<AllergenStatus> get followedStatuses =>
      [for (final a in followedAllergens) if (snapshot?[a.id] != null) snapshot![a.id]!];

  List<AllergenStatus> get otherStatuses => [
        for (final a in Allergens.all)
          if (!followed.contains(a.id) && snapshot?[a.id] != null) snapshot![a.id]!,
      ];

  /// Livello peggiore tra gli allergeni seguiti.
  Level get dayLevel => followedStatuses.fold(Level.none, (l, s) => l.max(s.level));

  List<AllergenStatus> get aboveThreshold =>
      followedStatuses.where((s) => s.level != Level.none && s.level >= thresholdOf(s.allergen)).toList();

  bool get isStale => snapshot == null || DateTime.now().difference(snapshot!.fetchedAt) > freshFor;

  Future<void> init() async {
    final p = _prefs.getString(_kPlace);
    if (p != null) place = Place.fromJson(jsonDecode(p) as Map<String, dynamic>);
    final f = _prefs.getStringList(_kFollowed);
    if (f != null) followed = f.toSet();
    final t = _prefs.getString(_kThresholds);
    if (t != null) {
      personal = (jsonDecode(t) as Map<String, dynamic>).map((k, v) => MapEntry(k, Level.fromIndex(v as int)));
    }
    final cached = _prefs.getString(_kCache);
    if (cached != null) {
      try {
        final raw = RawPollenData.decode(cached);
        if (raw.place.cacheKey == place.cacheKey) snapshot = _repo.build(raw);
      } on Object {
        await _prefs.remove(_kCache);
      }
    }
    notifyListeners();
    if (isStale) await refresh();
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final raw = await _repo.fetch(place);
      snapshot = _repo.build(raw);
      await _prefs.setString(_kCache, raw.encode());
    } on Object catch (e) {
      error = snapshot == null ? 'Dati non disponibili: $e' : 'Sei offline o le fonti non rispondono.';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setPlace(Place p) async {
    place = p;
    snapshot = null;
    await _prefs.setString(_kPlace, jsonEncode(p.toJson()));
    await _prefs.remove(_kCache);
    notifyListeners();
    await refresh();
  }

  Future<void> setFollowed(Allergen a, bool on) async {
    on ? followed.add(a.id) : followed.remove(a.id);
    await _prefs.setStringList(_kFollowed, followed.toList());
    notifyListeners();
  }

  Future<void> setThreshold(Allergen a, Level l) async {
    personal[a.id] = l;
    await _prefs.setString(_kThresholds, jsonEncode(personal.map((k, v) => MapEntry(k, v.index))));
    notifyListeners();
  }
}
