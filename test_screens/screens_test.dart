// ignore_for_file: invalid_use_of_visible_for_testing_member
// Screenshot di tutte le schermate a 412 dp (Motorola Edge 50 Fusion), per la revisione visiva.
// flutter test test_screens --update-goldens  →  test_screens/out/*.png
import 'dart:convert';
import 'dart:io';

import 'package:allergy_radar/models/diary_entry.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/screens/allergen_detail_screen.dart';
import 'package:allergy_radar/screens/home_shell.dart';
import 'package:allergy_radar/screens/log_entry_screen.dart';
import 'package:allergy_radar/screens/onboarding_screen.dart';
import 'package:allergy_radar/screens/trend_screen.dart';
import 'package:allergy_radar/screens/place_search_screen.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:allergy_radar/state/diary_state.dart';
import 'package:allergy_radar/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers.dart';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _font('Figtree', [for (final w in [400, 500, 600, 700]) 'assets/fonts/Figtree-$w.ttf']);
    await _font('Fraunces', [for (final w in [400, 500, 600]) 'assets/fonts/Fraunces-$w.ttf']);
    await _font('MaterialIcons', ['C:/development/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
  });

  Future<AppState> state(Place place, DateTime now, {bool diary = false, bool onboarded = true}) async {
    SharedPreferences.setMockInitialValues({
      'onboarded': onboarded,
      'place': '{"name":"${place.name}","region":null,"lat":${place.lat},"lon":${place.lon}}',
      if (diary) 'diary': jsonEncode(_sampleDiary()),
    });
    final s = AppState(repository(now), await SharedPreferences.getInstance());
    return s;
  }

  Future<void> shot(
    WidgetTester tester,
    String name,
    Widget home, {
    required AppState s,
    Brightness b = Brightness.light,
    double height = 915,
    Future<void> Function()? before,
  }) async {
    tester.view.physicalSize = Size(412, height) * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.runAsync(s.init);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: OpenMeteoClient(fakeHttp())),
        ChangeNotifierProvider.value(value: s),
        ChangeNotifierProvider(create: (_) => DiaryState(prefs)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(b),
        home: home,
      ),
    ));
    await tester.pumpAndSettle();
    if (before != null) await before();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('out/$name.png'));
  }

  final lecceNow = DateTime(2026, 9, 30, 10);
  const bologna = Place(name: 'Bologna', lat: 44.49, lon: 11.34);
  final bolognaNow = DateTime(2026, 9, 25, 10);

  for (final b in Brightness.values) {
    final t = b == Brightness.light ? 'chiaro' : 'scuro';
    testWidgets('oggi $t', (tester) async {
      await shot(tester, '01_oggi_$t', const HomeShell(), s: await state(Place.lecce, lecceNow), b: b, height: 2300);
    });
  }

  testWidgets('oggi bologna', (tester) async {
    await shot(tester, '02_oggi_bologna', const HomeShell(), s: await state(bologna, bolognaNow), height: 2300);
  });

  for (final (id, place, now) in [('parietaria', Place.lecce, lecceNow), ('grass', Place.lecce, lecceNow)]) {
    testWidgets('dettaglio $id', (tester) async {
      await shot(tester, '03_dettaglio_$id', AllergenDetailScreen(allergenId: id), s: await state(place, now), height: 1700);
    });
  }

  testWidgets('dettaglio parietaria misurata', (tester) async {
    await shot(tester, '04_dettaglio_parietaria_bologna', const AllergenDetailScreen(allergenId: 'parietaria'),
        s: await state(bologna, bolognaNow), height: 1700);
  });

  for (final (tab, h) in [('Diario', 915.0), ('Calendario', 1150.0), ('Profilo', 1900.0)]) {
    testWidgets('tab $tab', (tester) async {
      await shot(tester, '05_${tab.toLowerCase()}', const HomeShell(), s: await state(Place.lecce, lecceNow), height: h,
          before: () async {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      });
    });
  }

  testWidgets('ricerca luogo', (tester) async {
    await shot(tester, '06_luogo', const PlaceSearchScreen(), s: await state(Place.lecce, lecceNow));
  });

  for (final (tab, h) in [('Diario', 1700.0)]) {
    testWidgets('diario pieno', (tester) async {
      await shot(tester, '07_diario_pieno', const HomeShell(), s: await state(Place.lecce, lecceNow, diary: true), height: h,
          before: () async {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
      });
    });
  }

  testWidgets('registra', (tester) async {
    await shot(tester, '08_registra', LogEntryScreen(date: DateTime.now()), s: await state(Place.lecce, lecceNow), height: 1450);
  });

  testWidgets('benvenuto', (tester) async {
    await shot(tester, '10_benvenuto', const OnboardingScreen(), s: await state(Place.lecce, lecceNow, onboarded: false));
  });

  testWidgets('scelta allergeni', (tester) async {
    await shot(tester, '11_allergeni', const OnboardingScreen(), s: await state(Place.lecce, lecceNow, onboarded: false),
        before: () async {
      await tester.tap(find.text('Inizia'));
      await tester.pumpAndSettle();
    });
  });

  testWidgets('andamento', (tester) async {
    await shot(tester, '09_andamento', const TrendScreen(), s: await state(Place.lecce, lecceNow, diary: true), height: 1100);
  });
}


/// Un mese di diario inventato, con sintomi che salgono insieme alla Parietaria.
List<Map<String, dynamic>> _sampleDiary() {
  final today = DiaryEntry.day(DateTime.now());
  final out = <Map<String, dynamic>>[];
  for (var i = 1; i < 30; i++) {
    if (i % 9 == 0) continue; // qualche giorno dimenticato
    final par = i < 10 ? 3 : i < 20 ? 2 : 1;
    final sym = par == 3 ? (i.isEven ? 3 : 2) : par == 2 ? 1 : (i.isEven ? 1 : 0);
    out.add(DiaryEntry(
      date: today.subtract(Duration(days: i)),
      nose: sym,
      eyes: sym > 0 ? sym - 1 : 0,
      throat: i % 3 == 0 ? 1 : 0,
      badSleep: sym == 3,
      meds: sym >= 2 ? const ['Antistaminico'] : const [],
      pollen: {'parietaria': par, 'grass': 1},
    ).toJson());
  }
  return out;
}
