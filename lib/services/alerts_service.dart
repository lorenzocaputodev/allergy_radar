import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../data/pollen_repository.dart';
import '../models/alert_settings.dart';
import '../models/diary_entry.dart';
import '../models/station.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import 'alert_planner.dart';
import 'open_meteo_client.dart';
import 'pollnet_client.dart';
import 'widget_bridge.dart';

@pragma('vm:entry-point')
void alertsCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await AlertsService.runInBackground();
    } on Object {
      // Un giro andato male non deve bloccare i successivi.
    }
    return true;
  });
}

/// Avvisi su Android: un lavoro in background ogni ora aggiorna i dati, il widget
/// e manda gli avvisi dovuti. Cosa mandare lo decide [AlertPlanner].
class AlertsService {
  static const _task = 'pollen_check';
  static const _work = 'pollen_check_hourly';
  static const _kSent = 'alerts_sent';

  static const _pollenChannel = AndroidNotificationChannel(
    'pollen',
    'Pollini',
    description: 'Briefing del mattino e avviso se domani peggiora.',
    importance: Importance.high,
  );
  static const _diaryChannel = AndroidNotificationChannel(
    'diary',
    'Promemoria diario',
    description: 'La sera, se oggi non hai ancora registrato i sintomi.',
  );

  /// Sagoma bianca su fondo trasparente: Android colora da sé le icone della barra di stato.
  static const _statusIcon = '@drawable/ic_stat_logo';
  static const _accent = Color(0xFF1F5A4A);

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  /// Sistema reale, non defaultTargetPlatform: nei test vale «android» anche su Windows.
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static Future<void> init({bool background = false}) async {
    if (!isSupported || _ready) return;
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings(_statusIcon)));
    if (!background) await Workmanager().initialize(alertsCallbackDispatcher);
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_pollenChannel);
    await android?.createNotificationChannel(_diaryChannel);
    _ready = true;
  }

  /// Chiede il permesso (Android 13+). True se si possono mostrare avvisi.
  static Future<bool> requestPermission() async {
    if (!isSupported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Attiva o ferma il lavoro in background secondo le impostazioni.
  static Future<void> sync(AlertSettings settings) async {
    if (!isSupported) return;
    await init();
    if (settings.anyEnabled) {
      await Workmanager().registerPeriodicTask(
        _work,
        _task,
        frequency: const Duration(hours: 1),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } else {
      await Workmanager().cancelByUniqueName(_work);
    }
  }

  static Future<void> runInBackground() async {
    await init(background: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final client = http.Client();
    try {
      final repo = PollenRepository(
        openMeteo: OpenMeteoClient(client),
        pollnet: PollnetClient(client),
        stations: StationDirectory.parse(await rootBundle.loadString('assets/data/stations.json')),
      );
      final app = AppState(repo, prefs);
      await app.load();
      if (!app.onboarded) return;
      if (app.isStale) await app.refresh();
      await WidgetBridge.save(prefs, app);

      final now = DateTime.now();
      final sent = _loadSent(prefs);
      final messages = const AlertPlanner().plan(
        now: now,
        settings: app.alerts,
        placeName: app.place.name,
        followed: app.followedStatuses,
        thresholdOf: app.thresholdOf,
        diaryDoneToday: DiaryState(prefs).entryFor(DiaryEntry.day(now)) != null,
        sentOn: sent,
      );
      for (final m in messages) {
        await _show(m);
        sent[m.kind] = now;
      }
      if (messages.isNotEmpty) {
        await prefs.setString(
          _kSent,
          jsonEncode({for (final e in sent.entries) e.key.name: e.value.toIso8601String()}),
        );
      }
    } finally {
      client.close();
    }
  }

  static Map<AlertKind, DateTime> _loadSent(SharedPreferences prefs) {
    final raw = prefs.getString(_kSent);
    if (raw == null) return {};
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {
      for (final k in AlertKind.values)
        if (map[k.name] is String) k: DateTime.parse(map[k.name] as String),
    };
  }

  static Future<void> _show(AlertMessage m) {
    final channel = m.kind == AlertKind.diary ? _diaryChannel : _pollenChannel;
    return _plugin.show(
      m.kind.index + 1,
      m.title,
      m.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: m.kind == AlertKind.diary ? Priority.defaultPriority : Priority.high,
          icon: _statusIcon,
          color: _accent,
          styleInformation: BigTextStyleInformation(m.body),
        ),
      ),
    );
  }
}
