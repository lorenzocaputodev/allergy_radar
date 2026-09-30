import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/pollen_repository.dart';
import 'models/station.dart';
import 'screens/home_shell.dart';
import 'services/open_meteo_client.dart';
import 'services/pollnet_client.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final stations = StationDirectory.parse(await rootBundle.loadString('assets/data/stations.json'));
  final client = http.Client();
  final openMeteo = OpenMeteoClient(client);
  final repo = PollenRepository(openMeteo: openMeteo, pollnet: PollnetClient(client), stations: stations);
  final state = AppState(repo, prefs);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: openMeteo),
        ChangeNotifierProvider.value(value: state),
      ],
      child: const AllergyRadarApp(),
    ),
  );
  await state.init();
}

class AllergyRadarApp extends StatelessWidget {
  const AllergyRadarApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Allergy Radar',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(Brightness.light),
        darkTheme: AppTheme.of(Brightness.dark),
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomeShell(),
      );
}
