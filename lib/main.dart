import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/pollen_repository.dart';
import 'models/pollen_snapshot.dart';
import 'models/station.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/alerts_service.dart';
import 'services/open_meteo_client.dart';
import 'services/pollnet_client.dart';
import 'services/widget_bridge.dart';
import 'state/app_state.dart';
import 'state/diary_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final stations = StationDirectory.parse(await rootBundle.loadString('assets/data/stations.json'));
  final client = http.Client();
  final openMeteo = OpenMeteoClient(client);
  final repo = PollenRepository(openMeteo: openMeteo, pollnet: PollnetClient(client), stations: stations);
  final state = AppState(repo, prefs);
  final diary = DiaryState(prefs);

  PollenSnapshot? shown;
  state.addListener(() {
    if (state.snapshot == null || identical(state.snapshot, shown)) return;
    shown = state.snapshot;
    WidgetBridge.save(prefs, state).then((_) => WidgetBridge.refresh());
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
  if (state.onboarded) await AlertsService.sync(state.alerts);
}

class AllergyRadarApp extends StatelessWidget {
  const AllergyRadarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Allergy Radar',
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
