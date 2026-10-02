import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../state/app_state.dart';

/// Dati per il widget Android. Il widget nativo li legge dalle SharedPreferences
/// (chiave «flutter.widget_data») e si ridisegna da solo quando cambiano, anche ad app chiusa.
class WidgetBridge {
  static const _key = 'widget_data';

  static Future<void> save(SharedPreferences prefs, AppState app) async {
    final data = encode(app);
    if (data != null) await prefs.setString(_key, data);
  }

  /// Quello che mostra il widget, in JSON. Null se non ci sono ancora dati.
  static String? encode(AppState app) {
    final snap = app.snapshot;
    if (snap == null) return null;
    return jsonEncode({
      'place': app.place.name,
      'updated': snap.fetchedAt.toIso8601String(),
      'level': app.dayLevel.index,
      'levelLabel': app.dayLevel.label,
      'allergens': [
        // Tutti, dal livello più alto: il widget ne mostra quanti ci stanno e scorre gli altri con le frecce.
        for (final s in [...app.followedStatuses]..sort((a, b) => b.level.index.compareTo(a.level.index)))
          {
            'name': s.allergen.name,
            'level': s.level.index,
            'levelLabel': s.level.label,
            'estimate': s.kind == DataKind.estimate,
          },
      ],
    });
  }
}
