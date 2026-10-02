import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../state/app_state.dart';

/// Dati per il widget Android. Il widget nativo li legge dalle SharedPreferences
/// (chiave «flutter.widget_data»), quindi funziona anche quando l'app è chiusa.
class WidgetBridge {
  static const _channel = MethodChannel('dev.lorenzocaputo.allergyradar/widget');
  static const _key = 'widget_data';

  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;

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

  /// Chiede al widget di ridisegnarsi. Solo dall'app aperta: in background basta [save].
  static Future<void> refresh() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<void>('updateWidgets');
    } on PlatformException {
      // Nessun widget sulla Home: niente da aggiornare.
    }
  }
}
