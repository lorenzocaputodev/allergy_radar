import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../state/app_state.dart';
import '../utils/format.dart';

class WidgetBridge {
  static const _key = 'widget_data';

  static Future<void> save(SharedPreferences prefs, AppState app) async {
    final data = encode(app);
    if (data != null) await write(prefs, data);
  }

  static Future<void> write(SharedPreferences prefs, String data) => prefs.setString(_key, data);

  static String _source(DataKind? kind) => switch (kind) {
    DataKind.estimate => 'stima',
    DataKind.measured => 'misura',
    _ => '',
  };

  static String? encode(AppState app) {
    final snap = app.snapshot;
    if (snap == null) return null;
    return jsonEncode({
      'place': app.place.name,
      'updated': snap.fetchedAt.toIso8601String(),
      'level': app.dayLevel.index,
      'levelLabel': app.dayLevel.label,
      'source': _source(app.dayLevelSource),
      'allergens': [
        for (final s in [...app.followedStatuses]..sort((a, b) => b.level.index.compareTo(a.level.index)))
          {
            'name': s.allergen.name,
            'level': s.level.index,
            'levelLabel': s.level.label,
            'note': switch (s.kind) {
              DataKind.estimate => 'stima',
              DataKind.measured => s.date == null ? 'misura' : 'misura ${Fmt.shortDate(s.date!)}',
              DataKind.forecast => '',
            },
          },
      ],
    });
  }
}
