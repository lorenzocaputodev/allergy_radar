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
    final snap = app.snapshot;
    if (snap == null) return;
    final data = {
      'place': app.place.name,
      'updated': snap.fetchedAt.toIso8601String(),
      'level': app.dayLevel.index,
      'levelLabel': app.dayLevel.label,
      'allergens': [
        // Ci stanno tre righe: prima i livelli più alti.
        for (final s in ([...app.followedStatuses]..sort((a, b) => b.level.index.compareTo(a.level.index))).take(3))
          {
            'name': s.allergen.name,
            'level': s.level.index,
            'levelLabel': s.level.label,
            'estimate': s.kind == DataKind.estimate,
          },
      ],
    };
    await prefs.setString(_key, jsonEncode(data));
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
