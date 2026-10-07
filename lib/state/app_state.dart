import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/pollen_repository.dart';
import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';

class AppState extends ChangeNotifier {
  AppState(this._repo, this._prefs);

  final PollenRepository _repo;
  final SharedPreferences _prefs;

  static const kPlace = 'place';
  static const kFollowed = 'followed';
  static const kThresholds = 'thresholds';
  static const kOnboarded = 'onboarded';
  static const kTheme = 'theme';
  static const kAlerts = 'alerts';
  static const _kCache = 'cache';

  static const backupKeys = [kPlace, kFollowed, kThresholds, kOnboarded, kTheme, kAlerts];

  static const freshFor = Duration(hours: 1);

  Place place = Place.lecce;
  static final _defaultFollowed = {Allergens.grass.id, Allergens.parietaria.id};

  Set<String> followed = {..._defaultFollowed};
  Map<String, Level> personal = {};
  ThemeMode themeMode = ThemeMode.system;
  AlertSettings alerts = const AlertSettings();

  bool onboarded = false;

  PollenSnapshot? snapshot;
  bool loading = false;
  String? error;

  Area get area => snapshot?.area ?? _repo.stations.areaOf(place);

  List<Allergen> get followedAllergens => Allergens.all.where((a) => followed.contains(a.id)).toList();

  Level thresholdOf(Allergen a) => personal[a.id] ?? Level.moderate;

  List<AllergenStatus> get followedStatuses => [
    for (final a in followedAllergens)
      if (snapshot?[a.id] != null) snapshot![a.id]!,
  ];

  List<AllergenStatus> get otherStatuses => [
    for (final a in Allergens.all)
      if (!followed.contains(a.id) && snapshot?[a.id] != null) snapshot![a.id]!,
  ];

  Level get dayLevel => followedStatuses.fold(Level.none, (l, s) => l.max(s.level));

  List<AllergenStatus> get aboveThreshold =>
      followedStatuses.where((s) => s.level != Level.none && s.level >= thresholdOf(s.allergen)).toList();

  bool get isStale {
    if (snapshot == null) return true;
    final now = DateTime.now();
    final at = snapshot!.fetchedAt;
    return now.difference(at) > freshFor ||
        DateTime(now.year, now.month, now.day) != DateTime(at.year, at.month, at.day);
  }

  // --- Caricamento e dati ---
  Future<void> load() async {
    onboarded = _prefs.getBool(kOnboarded) ?? false;
    final p = _prefs.getString(kPlace);
    place = p == null ? Place.lecce : Place.fromJson(jsonDecode(p) as Map<String, dynamic>);
    final f = _prefs.getStringList(kFollowed);
    followed = f == null ? {..._defaultFollowed} : f.where((id) => Allergens.byId(id) != null).toSet();
    final t = _prefs.getString(kThresholds);
    personal = t == null
        ? {}
        : (jsonDecode(t) as Map<String, dynamic>).map((k, v) => MapEntry(k, Level.fromIndex(v as int)));
    themeMode = ThemeMode.values.asNameMap()[_prefs.getString(kTheme)] ?? ThemeMode.system;
    final a = _prefs.getString(kAlerts);
    alerts = a == null ? const AlertSettings() : AlertSettings.fromJson(jsonDecode(a) as Map<String, dynamic>);
    snapshot = await _fromCache();
    notifyListeners();
  }

  Future<PollenSnapshot?> _fromCache() async {
    final cached = _prefs.getString(_kCache);
    if (cached == null) return null;
    try {
      final raw = RawPollenData.decode(cached);
      return raw.place.cacheKey == place.cacheKey ? _repo.build(raw) : null;
    } on Object {
      await _prefs.remove(_kCache);
      return null;
    }
  }

  Future<void> init() async {
    await load();
    if (onboarded && isStale) await refresh();
  }

  Future<void> completeOnboarding(Place p, Set<String> allergens, AlertSettings alertSettings) async {
    followed = {...allergens};
    await _prefs.setStringList(kFollowed, followed.toList());
    await setAlerts(alertSettings);
    onboarded = true;
    await _prefs.setBool(kOnboarded, true);
    await setPlace(p);
  }

  Future<void> refresh() async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    final asked = place;
    try {
      final raw = await _repo.fetch(asked);
      if (place.cacheKey == asked.cacheKey) {
        snapshot = _repo.build(raw);
        await _prefs.setString(_kCache, raw.encode());
      }
    } on Object {
      if (place.cacheKey == asked.cacheKey) {
        snapshot = await _fromCache() ?? snapshot;
        error = snapshot == null
            ? 'Dati non disponibili. Controlla la connessione e riprova.'
            : 'Sei offline o le fonti non rispondono: mostro gli ultimi dati.';
      }
    } finally {
      loading = false;
      notifyListeners();
    }
    if (place.cacheKey != asked.cacheKey) await refresh();
  }

  // --- Impostazioni ---
  Future<void> setPlace(Place p) async {
    place = p;
    snapshot = null;
    await _prefs.setString(kPlace, jsonEncode(p.toJson()));
    await _prefs.remove(_kCache);
    notifyListeners();
    await refresh();
  }

  Future<void> setFollowed(Allergen a, bool on) async {
    on ? followed.add(a.id) : followed.remove(a.id);
    notifyListeners();
    await _prefs.setStringList(kFollowed, followed.toList());
  }

  Future<void> setThreshold(Allergen a, Level l) async {
    personal[a.id] = l;
    notifyListeners();
    await _prefs.setString(kThresholds, jsonEncode(personal.map((k, v) => MapEntry(k, v.index))));
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    notifyListeners();
    await _prefs.setString(kTheme, m.name);
  }

  Future<void> setAlerts(AlertSettings a) async {
    alerts = a;
    notifyListeners();
    await _prefs.setString(kAlerts, jsonEncode(a.toJson()));
  }
}
