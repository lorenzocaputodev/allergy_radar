import 'package:allergy_radar/main.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/screens/allergen_detail_screen.dart';
import 'package:allergy_radar/screens/log_entry_screen.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:allergy_radar/state/diary_state.dart';
import 'package:allergy_radar/widgets/allergen_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);

  // Telefono stretto: fa emergere gli overflow.
  Future<void> pumpApp(WidgetTester tester, {Brightness brightness = Brightness.light, bool onboarded = true}) async {
    tester.view.physicalSize = const Size(360, 780) * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    SharedPreferences.setMockInitialValues({'onboarded': onboarded});
    final prefs = await SharedPreferences.getInstance();
    final repo = repository(DateTime(2026, 9, 30, 10));
    final state = AppState(repo, prefs);
    await tester.runAsync(state.init);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: OpenMeteoClient(fakeHttp())),
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider(create: (_) => DiaryState(prefs)),
        ],
        child: const AllergyRadarApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Oggi mostra livelli e fonti', (tester) async {
    await pumpApp(tester);
    expect(find.text('LA TUA GIORNATA'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Parietaria'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Parietaria'), findsWidgets);
    expect(find.textContaining('Stima'), findsWidgets);
    expect(find.textContaining('Previsione'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Altri pollini in zona'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Altri pollini in zona'), findsOneWidget);
  });

  testWidgets('tutte le schede e il dettaglio si aprono senza errori', (tester) async {
    await pumpApp(tester, brightness: Brightness.dark);
    for (final tab in ['Calendario', 'Profilo', 'Diario', 'Oggi']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
    }
    final card = find.widgetWithText(AllergenCard, 'Parietaria');
    await tester.scrollUntilVisible(card, 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Perché è una stima'), findsOneWidget);
    final high = find.widgetWithText(SegmentedButton<Level>, 'Alto');
    await tester.scrollUntilVisible(
      high,
      300,
      scrollable: find.descendant(of: find.byType(AllergenDetailScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.ensureVisible(high);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: high, matching: find.text('Alto')));
    await tester.pumpAndSettle();
  });

  testWidgets('diario: registrare i sintomi di oggi', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Diario').last);
    await tester.pumpAndSettle();
    expect(find.text('Oggi non hai ancora registrato'), findsOneWidget);

    await tester.tap(find.text('Registra'));
    await tester.pumpAndSettle();
    expect(find.text('Come stai oggi?'), findsOneWidget);
    await tester.tap(find.text('Forte').first); // naso
    await tester.pump();
    final save = find.text('Salva');
    await tester.scrollUntilVisible(
      save,
      300,
      scrollable: find.descendant(of: find.byType(LogEntryScreen), matching: find.byType(Scrollable)).first,
    );
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.text('Oggi: sintomi forti'), findsOneWidget);
    await tester.tap(find.byTooltip('Andamento e confronti'));
    await tester.pumpAndSettle();
    expect(find.text('Ancora 13 giorni'), findsOneWidget);
  });

  testWidgets('campanella e schermate del Profilo', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byTooltip('Avvisi ricevuti'));
    await tester.pumpAndSettle();
    expect(find.text('Nessun avviso, per ora'), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profilo').last);
    await tester.pumpAndSettle();
    for (final (entry, title) in [
      ('I miei allergeni', 'I miei allergeni'),
      ('Farmaci', 'Farmaci'),
      ('Avvisi', 'Avvisi'),
      ('Fonti e privacy', 'Fonti e privacy'),
    ]) {
      final tile = find.widgetWithText(ListTile, entry);
      await tester.scrollUntilVisible(tile, 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('primo avvio: allergeni, luogo, poi Oggi', (tester) async {
    await pumpApp(tester, onboarded: false);
    expect(find.text('Sappi prima cosa c’è nell’aria.'), findsOneWidget);
    await tester.tap(find.text('Inizia'));
    await tester.pumpAndSettle();

    expect(find.text('A cosa sei allergico?'), findsOneWidget);
    await tester.tap(find.text('Continua · 2 scelti'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lecce');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Lecce').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continua con Lecce'));
    await tester.pumpAndSettle();

    expect(find.text('Quando vuoi saperlo?'), findsOneWidget);
    await tester.tap(find.text('Non ora'));
    await tester.pumpAndSettle();

    expect(find.text('Tutto pronto'), findsOneWidget);
    await tester.tap(find.text('Vai a Oggi'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('LA TUA GIORNATA'), findsOneWidget);
  });
}
