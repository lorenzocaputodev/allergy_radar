import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/update_checker.dart';

enum UpdateFrequency {
  day('Ogni giorno', Duration(days: 1)),
  week('Ogni settimana', Duration(days: 7)),
  month('Ogni mese', Duration(days: 30)),
  never('Mai', null);

  const UpdateFrequency(this.label, this.every);

  final String label;
  final Duration? every;
}

class UpdateState extends ChangeNotifier {
  UpdateState(this._prefs, this._checker, {required this.current});

  final SharedPreferences _prefs;
  final UpdateChecker _checker;
  final String current;

  static const kFrequency = 'update_frequency';
  static const _kCheckedAt = 'update_checked_at';
  static const _kLatest = 'update_latest';
  static const _kDismissed = 'update_dismissed';

  static const backupKeys = [kFrequency];

  UpdateFrequency frequency = UpdateFrequency.day;
  bool checking = false;
  String? _latest;
  String? _dismissed;

  String? get available {
    final v = _latest;
    return frequency != UpdateFrequency.never && v != null && v != _dismissed && UpdateChecker.isNewer(v, current)
        ? v
        : null;
  }

  // --- Caricamento ---
  void load() {
    T? read<T>(String key) {
      final v = _prefs.get(key);
      return v is T ? v : null;
    }

    frequency = UpdateFrequency.values.asNameMap()[read<String>(kFrequency)] ?? UpdateFrequency.day;
    _latest = read<String>(_kLatest);
    _dismissed = read<String>(_kDismissed);
    notifyListeners();
  }

  // --- Controllo ---
  Future<void> checkIfDue() async {
    final every = frequency.every;
    if (every == null || checking) return;
    final at = _prefs.get(_kCheckedAt);
    if (at is int && clock.now().difference(DateTime.fromMillisecondsSinceEpoch(at)) < every) return;
    try {
      await check();
    } on Object {
      return;
    }
  }

  Future<String> check({bool manual = false}) async {
    checking = true;
    notifyListeners();
    try {
      final v = await _checker.latestVersion();
      _latest = v;
      await _prefs.setString(_kLatest, v);
      await _prefs.setInt(_kCheckedAt, clock.now().millisecondsSinceEpoch);
      if (manual) {
        _dismissed = null;
        await _prefs.remove(_kDismissed);
      }
      return v;
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  // --- Impostazioni ---
  Future<void> dismiss() async {
    final v = available;
    if (v == null) return;
    _dismissed = v;
    notifyListeners();
    await _prefs.setString(_kDismissed, v);
  }

  Future<void> setFrequency(UpdateFrequency f) async {
    frequency = f;
    notifyListeners();
    await _prefs.setString(kFrequency, f.name);
    await checkIfDue();
  }
}
