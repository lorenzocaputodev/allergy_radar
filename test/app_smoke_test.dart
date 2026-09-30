import 'package:allergy_radar/main.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/screens/allergen_detail_screen.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:allergy_radar/widgets/allergen_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  setUp(() => WidgetController.hitTestWarningShouldBeFatal = true);

  // Telefono stretto: fa emergere gli overflow.
  Future<void> pumpApp(WidgetTester tester, {Brightness brightness = Brightness.light}) async {
    tester.view.physicalSize = const Size(360, 780) * 3;
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = repository(DateTime(2026, 9, 30, 10));
    final state = AppState(repo, prefs);
    await tester.runAsync(state.init);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider.value(value: OpenMeteoClient(fakeHttp())),
        ChangeNotifierProvider.value(value: state),
      ],
      child: const AllergyRadarApp(),
    ));
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
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Perché non c’è la previsione?'), findsOneWidget);
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
}
