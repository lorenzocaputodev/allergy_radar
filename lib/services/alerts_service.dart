import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../data/pollen_repository.dart';
import '../models/alert_log.dart';
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
      await AlertsService.runInBackground(force: task == AlertsService.refreshTask);
    } on Object {
      // Un giro andato male non deve bloccare i successivi.
    }
    return true;
  });
}

class AlertsService {
  static const _task = 'pollen_check';

  static const refreshTask = 'widget_refresh';
  static const _work = 'pollen_check_hourly';
  static const _testId = 99;
  static const _testBody = 'Gli avvisi di Allergy Radar arrivano così.';

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

  static const _statusIcon = '@drawable/ic_stat_logo';
  static const _accent = Color(0xFF1F5A4A);

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static final opened = ValueNotifier<AlertKind?>(null);

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  // --- Avvio e permessi ---
  static Future<bool> init({bool background = false}) async {
    if (!isSupported) return false;
    if (_ready) return true;
    try {
      await _plugin.initialize(
        const InitializationSettings(android: AndroidInitializationSettings(_statusIcon)),
        onDidReceiveNotificationResponse: (r) => _open(r.payload),
      );
      if (!background) {
        await Workmanager().initialize(alertsCallbackDispatcher);
        final launch = await _plugin.getNotificationAppLaunchDetails();
        if (launch?.didNotificationLaunchApp ?? false) _open(launch!.notificationResponse?.payload);
      }
      await _android?.createNotificationChannel(_pollenChannel);
      await _android?.createNotificationChannel(_diaryChannel);
      _ready = true;
    } on Object catch (e) {
      debugPrint('Avvisi non disponibili: $e');
    }
    return _ready;
  }

  static Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      return await _android?.requestNotificationsPermission() ?? true;
    } on Object {
      return false;
    }
  }

  static Future<bool> enabled() async {
    if (!await init()) return false;
    try {
      return await _android?.areNotificationsEnabled() ?? false;
    } on Object {
      return false;
    }
  }

  static Future<bool> exact() async {
    if (!await init()) return false;
    try {
      return await _android?.canScheduleExactNotifications() ?? false;
    } on Object {
      return false;
    }
  }

  static Future<bool> requestExact() async {
    if (!await init()) return false;
    try {
      await _android?.requestExactAlarmsPermission();
    } on Object {
      return false;
    }
    return exact();
  }

  // --- Prova e lavoro in background ---
  static Future<bool> sendTest() async {
    if (!await enabled()) return false;
    await _plugin.show(_testId, 'Avviso di prova', _testBody, _details(AlertKind.briefing, _testBody));
    return true;
  }

  /// Avvia il controllo orario in background (dati, widget, avvisi).
  static Future<void> startBackground() async {
    if (!await init()) return;
    try {
      await Workmanager().registerPeriodicTask(
        _work,
        _task,
        frequency: const Duration(hours: 1),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      );
    } on Object catch (e) {
      debugPrint('Controllo in background non registrato: $e');
    }
  }

  // --- Programmazione ---
  static Future<void> reschedule(SharedPreferences prefs, AppState app, DiaryState diary) async {
    if (!_ready || !app.onboarded) return;
    final now = DateTime.now();
    final messages = const AlertPlanner().schedule(
      now: now,
      settings: app.alerts,
      placeName: app.place.name,
      followed: app.followedStatuses,
      thresholdOf: app.thresholdOf,
      diaryDoneToday: diary.entryFor(DiaryEntry.day(now)) != null,
    );
    try {
      final mode = await exact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
      for (final k in AlertKind.values) {
        await _plugin.cancel(_id(k));
      }
      for (final m in messages) {
        await _plugin.zonedSchedule(
          _id(m.kind),
          m.title,
          m.body,
          tz.TZDateTime.from(m.at, tz.UTC),
          _details(m.kind, m.body),
          androidScheduleMode: mode,
          payload: m.kind.name,
        );
      }
      await AlertLog.setPending(prefs, messages, now);
    } on Object catch (e) {
      debugPrint('Avvisi non programmati: $e');
    }
  }

  // --- Controllo in background ---
  static Future<void> runInBackground({bool force = false}) async {
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
      if (force || app.isStale) await app.refresh();
      await WidgetBridge.save(prefs, app);
      await reschedule(prefs, app, DiaryState(prefs));
    } finally {
      client.close();
    }
  }

  // --- Notifiche ---
  static int _id(AlertKind k) => k.index + 1;

  static void _open(String? payload) => opened.value = AlertKind.values.asNameMap()[payload];

  static NotificationDetails _details(AlertKind kind, String body) {
    final channel = kind == AlertKind.diary ? _diaryChannel : _pollenChannel;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: kind == AlertKind.diary ? Priority.defaultPriority : Priority.high,
        icon: _statusIcon,
        color: _accent,
        styleInformation: BigTextStyleInformation(body),
      ),
    );
  }
}
