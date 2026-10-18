import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/pollen_repository.dart';
import 'models/diary_entry.dart';
import 'models/place.dart';
import 'models/place_index.dart';
import 'models/pollen_snapshot.dart';
import 'models/station.dart';
import 'screens/home_shell.dart';
import 'screens/log_entry_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/alert_planner.dart';
import 'services/alerts_service.dart';
import 'services/location_service.dart';
import 'services/open_meteo_client.dart';
import 'services/pollnet_client.dart';
import 'services/update_checker.dart';
import 'services/widget_bridge.dart';
import 'state/app_state.dart';
import 'state/diary_state.dart';
import 'state/update_state.dart';
import 'theme/app_theme.dart';

final _navigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final stations = StationDirectory.parse(await rootBundle.loadString('assets/data/stations.json'));
  final placesLoad = rootBundle.loadString('assets/data/places.json').then((s) => compute(PlaceIndex.parse, s));
  final client = http.Client();
  final openMeteo = OpenMeteoClient(client);
  final repo = PollenRepository(openMeteo: openMeteo, pollnet: PollnetClient(client), stations: stations);
  final state = AppState(repo, prefs);
  final diary = DiaryState(prefs);
  final info = await PackageInfo.fromPlatform();
  final places = await placesLoad;
  final updates = UpdateState(prefs, UpdateChecker(client), current: info.version)..load();

  PollenSnapshot? filled;
  state.addListener(() {
    final snap = state.snapshot;
    if (snap == null || identical(snap, filled)) return;
    filled = snap;
    unawaited(diary.fillMeasured(snap));
  });

  String? shown;
  state.addListener(() {
    final data = WidgetBridge.encode(state);
    if (data == null || data == shown) return;
    shown = data;
    unawaited(WidgetBridge.write(prefs, data));
  });

  Timer? pending;
  void reschedule() {
    pending?.cancel();
    pending = Timer(const Duration(seconds: 1), () => AlertsService.reschedule(prefs, state, diary));
  }

  state.addListener(reschedule);
  diary.addListener(reschedule);

  Future<void> reloadDiary() async {
    await prefs.reload();
    diary.reload();
  }

  Future<({double lat, double lon})> locate() => LocationService.position(ask: false);
  Future<Place> describe(double lat, double lon) => LocationService.placeAt(
    lat,
    lon,
    reverse: LocationService.androidGeocoder,
    index: places,
    renamed: (p) => unawaited(state.rename(p)),
  );

  Future<void> freshenData() async {
    final followFirst = state.followLocation && state.hasData;
    if (followFirst) await state.follow(locate, describe);
    if (state.isStale) await state.refresh();
    if (state.followLocation && !followFirst) await state.follow(locate, describe);
  }

  void freshen() {
    if (!state.onboarded) return;
    unawaited(freshenData());
    unawaited(updates.checkIfDue());
  }

  Future<void> resume() async {
    await reloadDiary();
    await state.syncCache();
    reschedule();
    freshen();
  }

  AlertsService.diaryChanged.addListener(() => unawaited(reloadDiary()));

  AppLifecycleListener(onResume: () => unawaited(resume()));

  AlertsService.opened.addListener(() {
    final opened = AlertsService.opened.value;
    if (opened == null || opened.kind != AlertKind.diary) return;
    AlertsService.opened.value = null;
    WidgetsBinding.instance.scheduleFrame();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.onboarded) return;
      _navigator.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: DiaryEntry.day(opened.at ?? DateTime.now()))),
      );
    });
  });

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: openMeteo),
        Provider.value(value: places),
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: diary),
        ChangeNotifierProvider.value(value: updates),
      ],
      child: const AllergyRadarApp(),
    ),
  );

  await state.load();
  freshen();
  await AlertsService.init();
  if (state.onboarded) await AlertsService.startBackground();
  reschedule();
}

class AllergyRadarApp extends StatelessWidget {
  const AllergyRadarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Allergy Radar',
    navigatorKey: _navigator,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.of(Brightness.light),
    darkTheme: AppTheme.of(Brightness.dark),
    themeMode: context.select<AppState, ThemeMode>((s) => s.themeMode),
    locale: const Locale('it'),
    supportedLocales: const [Locale('it')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Selector<AppState, bool>(
      selector: (_, s) => s.onboarded,
      builder: (_, onboarded, _) => onboarded ? const HomeShell() : const OnboardingScreen(),
    ),
  );
}
