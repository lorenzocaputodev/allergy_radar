import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/pollen_repository.dart';
import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';
import '../utils/days.dart';

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
  static const kWidgetTheme = 'widget_theme';
  static const kPlaces = 'places';
  static const kFollowLocation = 'follow_location';
  static const _kCache = 'cache';

  static const backupKeys = [
    kPlace,
    kFollowed,
    kThresholds,
    kOnboarded,
    kTheme,
    kAlerts,
    kWidgetTheme,
    kPlaces,
    kFollowLocation,
  ];

  static const maxSaved = 5;
  static const followKm = 5.0;
  static const followTimeout = Duration(seconds: 20);

  static const freshFor = Duration(hours: 1);

  Place place = Place.lecce;
  List<Place> saved = const [];
  bool followLocation = false;
  static final _defaultFollowed = {Allergens.grass.id, Allergens.parietaria.id};

  Set<String> followed = {..._defaultFollowed};
  Map<String, Level> personal = {};
  ThemeMode themeMode = ThemeMode.system;
  bool widgetDark = true;
  AlertSettings alerts = const AlertSettings();

  bool onboarded = false;

  PollenSnapshot? snapshot;
  String? error;
  final _inflight = <String, Future<void>>{};
  int _running = 0;

  Future<void>? _following;

  bool get loading => _running > 0;
  bool get hasData => snapshot != null && !estimatesOnly;
  bool get estimatesOnly => snapshot?.estimated ?? false;

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

  DataKind? get dayLevelSource {
    final level = dayLevel;
    if (level == Level.none) return null;
    final kinds = {for (final s in followedStatuses.where((s) => s.level == level)) s.kind};
    return DataKind.values.firstWhere(kinds.contains);
  }

  List<AllergenStatus> get aboveThreshold =>
      followedStatuses.where((s) => s.level != Level.none && s.level >= thresholdOf(s.allergen)).toList();

  bool get isStale {
    if (snapshot == null || estimatesOnly) return true;
    final now = DateTime.now();
    final at = snapshot!.fetchedAt;
    return now.difference(at) > freshFor || !now.isSameDay(at);
  }

  // --- Caricamento e dati ---
  Future<void> load() async {
    T read<T>(T Function() f, T fallback) {
      try {
        return f();
      } on Object {
        return fallback;
      }
    }

    onboarded = read(() => _prefs.getBool(kOnboarded) ?? false, false);
    final p = read(() => _prefs.getString(kPlace), null);
    place = p == null ? Place.lecce : read(() => Place.fromJson(jsonDecode(p) as Map<String, dynamic>), Place.lecce);
    final s = read(() => _prefs.getString(kPlaces), null);
    saved = s == null
        ? (p == null ? const [] : [place])
        : read(
            () => [for (final j in jsonDecode(s) as List) Place.fromJson(j as Map<String, dynamic>)],
            const <Place>[],
          );
    followLocation = read(() => _prefs.getBool(kFollowLocation) ?? false, false);
    final f = read(() => _prefs.getStringList(kFollowed), null);
    followed = f == null ? {..._defaultFollowed} : f.where((id) => Allergens.byId(id) != null).toSet();
    final t = read(() => _prefs.getString(kThresholds), null);
    personal = t == null
        ? {}
        : read(
            () => (jsonDecode(t) as Map<String, dynamic>).map((k, v) => MapEntry(k, Level.fromIndex(v as int))),
            <String, Level>{},
          );
    themeMode = ThemeMode.values.asNameMap()[read(() => _prefs.getString(kTheme), null)] ?? ThemeMode.system;
    widgetDark = read(() => _prefs.getString(kWidgetTheme), null) != 'light';
    final a = read(() => _prefs.getString(kAlerts), null);
    alerts = a == null
        ? const AlertSettings()
        : read(() => AlertSettings.fromJson(jsonDecode(a) as Map<String, dynamic>), const AlertSettings());
    snapshot = await _fromCache();
    notifyListeners();
  }

  RawPollenData? _cachedRaw() {
    final cached = _prefs.getString(_kCache);
    if (cached == null) return null;
    try {
      final raw = RawPollenData.decode(cached);
      return raw.place.cacheKey == place.cacheKey ? raw : null;
    } on Object {
      return null;
    }
  }

  Future<PollenSnapshot?> _fromCache() async {
    try {
      final raw = _cachedRaw();
      return raw == null ? null : _repo.build(raw);
    } on Object {
      await _prefs.remove(_kCache);
      return null;
    }
  }

  Future<void> syncCache() async {
    final cached = await _fromCache();
    if (cached == null || (snapshot != null && !estimatesOnly && !cached.fetchedAt.isAfter(snapshot!.fetchedAt))) {
      return;
    }
    snapshot = cached;
    notifyListeners();
  }

  Future<void> completeOnboarding(Place p, Set<String> allergens, AlertSettings alertSettings) async {
    followed = {...allergens};
    await _prefs.setStringList(kFollowed, followed.toList());
    await setAlerts(alertSettings);
    onboarded = true;
    await _prefs.setBool(kOnboarded, true);
    await setPlace(p);
  }

  Future<void> refresh({bool manual = false}) {
    final key = place.cacheKey;
    return _inflight[key] ??= _refresh(manual: manual).whenComplete(() {
      _inflight.remove(key);
    });
  }

  Future<void> _refresh({required bool manual}) async {
    _running++;
    error = null;
    notifyListeners();
    final asked = place;
    Future<bool> stillAsked() async {
      await _prefs.reload();
      final stored = storedPlaceKey;
      return place.cacheKey == asked.cacheKey && (stored == null || stored == asked.cacheKey);
    }

    Future<void> show(RawPollenData raw) async {
      snapshot = _repo.build(raw);
      notifyListeners();
      await _prefs.setString(_kCache, raw.encode());
    }

    try {
      final forecast = await _repo.fetchForecast(asked);
      if (await stillAsked()) {
        final cached = _cachedRaw();
        await show(forecast.withMeasures(cached?.measures ?? const [], at: cached?.measuresAt));
        final m = await _repo.fetchMeasures(asked, forecast.fetchedAt, cached: cached, force: manual);
        if (m.at != cached?.measuresAt && await stillAsked()) await show(forecast.withMeasures(m.measures, at: m.at));
      }
    } on Object {
      if (place.cacheKey == asked.cacheKey) {
        final cached = await _fromCache();
        if (cached == null && (snapshot == null || estimatesOnly)) {
          snapshot = _repo.estimates(asked);
          error = 'Previsioni non raggiungibili: per ora vedi le stime del calendario.';
        } else {
          snapshot = cached ?? snapshot;
          error = 'Sei offline o le fonti non rispondono: mostro gli ultimi dati.';
        }
      }
    } finally {
      _running--;
      notifyListeners();
    }
  }

  String? get storedPlaceKey {
    try {
      final p = _prefs.getString(kPlace);
      return p == null ? null : Place.fromJson(jsonDecode(p) as Map<String, dynamic>).cacheKey;
    } on Object {
      return null;
    }
  }

  // --- Impostazioni ---
  Future<void> setPlace(Place p, {bool following = false}) async {
    final same = p.cacheKey == place.cacheKey && hasData;
    place = p;
    if (!following) {
      followLocation = false;
      saved = [p, ...saved.where((s) => s.cacheKey != p.cacheKey)].take(maxSaved).toList();
      await _prefs.setBool(kFollowLocation, false);
      await _savePlaces();
    }
    await _prefs.setString(kPlace, jsonEncode(p.toJson()));
    if (same) return notifyListeners();
    snapshot = null;
    await _prefs.remove(_kCache);
    notifyListeners();
    await refresh();
  }

  Future<void> rename(Place p) async {
    if (p.cacheKey != place.cacheKey || p.name == place.name) return;
    place = p;
    saved = [for (final s in saved) s.cacheKey == p.cacheKey ? p : s];
    notifyListeners();
    await _prefs.setString(kPlace, jsonEncode(p.toJson()));
    await _savePlaces();
  }

  Future<void> forget(Place p) async {
    saved = saved.where((s) => s.cacheKey != p.cacheKey).toList();
    notifyListeners();
    await _savePlaces();
  }

  Future<void> _savePlaces() => _prefs.setString(kPlaces, jsonEncode([for (final s in saved) s.toJson()]));

  Future<void> startFollowing(Place here) async {
    followLocation = true;
    await _prefs.setBool(kFollowLocation, true);
    await setPlace(here, following: true);
  }

  Future<void> stopFollowing() async {
    followLocation = false;
    notifyListeners();
    await _prefs.setBool(kFollowLocation, false);
  }

  Future<void> follow(
    Future<({double lat, double lon})> Function() position,
    Future<Place> Function(double lat, double lon) describe,
  ) => _following ??= _follow(position, describe).whenComplete(() {
    _following = null;
  });

  Future<void> _follow(
    Future<({double lat, double lon})> Function() position,
    Future<Place> Function(double lat, double lon) describe,
  ) async {
    if (!followLocation) return;
    final Place here;
    try {
      final pos = await position().timeout(followTimeout);
      if (distanceKm(place.lat, place.lon, pos.lat, pos.lon) < followKm) return;
      here = await describe(pos.lat, pos.lon).timeout(followTimeout);
    } on Object {
      return;
    }
    if (followLocation) await setPlace(here, following: true);
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

  Future<void> setWidgetDark(bool dark) async {
    widgetDark = dark;
    notifyListeners();
    await _prefs.setString(kWidgetTheme, dark ? 'dark' : 'light');
  }

  Future<void> setAlerts(AlertSettings a) async {
    alerts = a;
    notifyListeners();
    await _prefs.setString(kAlerts, jsonEncode(a.toJson()));
  }
}
