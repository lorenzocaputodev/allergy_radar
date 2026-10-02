import 'package:allergy_radar/widgets/page_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('il margine della pagina tiene conto delle aree di sistema, anche ai lati', (tester) async {
    // Orizzontale con navigazione a tre tasti: la barra sta a destra.
    tester.view.padding = const FakeViewPadding(top: 72, right: 144, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PageList(padding: EdgeInsets.fromLTRB(16, 8, 16, 24), children: [Text('voce')]),
        ),
      ),
    );
    final padding = tester.widget<ListView>(find.byType(ListView)).padding! as EdgeInsets;
    final dpr = tester.view.devicePixelRatio;
    expect(padding, EdgeInsets.fromLTRB(16, 8, 16 + 144 / dpr, 24 + 24 / dpr));
  });
}
