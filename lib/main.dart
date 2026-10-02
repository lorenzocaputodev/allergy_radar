import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/pollen_repository.dart';
import 'models/diary_entry.dart';
import 'models/station.dart';
import 'screens/home_shell.dart';
import 'screens/log_entry_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/alert_planner.dart';
import 'services/alerts_service.dart';
import 'services/open_meteo_client.dart';
import 'services/pollnet_client.dart';
import 'services/widget_bridge.dart';
import 'state/app_state.dart';
import 'state/diary_state.dart';
import 'theme/app_theme.dart';

final _navigator = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final stations = StationDirectory.parse(await rootBundle.loadString('assets/data/stations.json'));
  final client = http.Client();
  final openMeteo = OpenMeteoClient(client);
  final repo = PollenRepository(openMeteo: openMeteo, pollnet: PollnetClient(client), stations: stations);
  final state = AppState(repo, prefs);
  final diary = DiaryState(prefs);

  String? shown;
  state.addListener(() {
    final data = WidgetBridge.encode(state);
    if (data == null || data == shown) return;
    shown = data;
    unawaited(WidgetBridge.save(prefs, state));
  });

  Timer? pending;
  void reschedule() {
    pending?.cancel();
    pending = Timer(const Duration(seconds: 1), () => AlertsService.reschedule(prefs, state, diary));
  }

  state.addListener(reschedule);
  diary.addListener(reschedule);

  AppLifecycleListener(
    onResume: () {
      if (state.onboarded && state.isStale) state.refresh();
    },
  );

  AlertsService.opened.addListener(() {
    if (AlertsService.opened.value != AlertKind.diary) return;
    AlertsService.opened.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!state.onboarded) return;
      _navigator.currentState?.push(
        MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: DiaryEntry.day(DateTime.now()))),
      );
    });
  });

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: openMeteo),
        ChangeNotifierProvider.value(value: state),
        ChangeNotifierProvider.value(value: diary),
      ],
      child: const AllergyRadarApp(),
    ),
  );

  // Prima lo stato: un problema con le notifiche non deve mai riportare l'app al primo avvio.
  await state.init();
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
