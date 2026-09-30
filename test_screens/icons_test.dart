// Genera le icone dell'app dal disegno del radar.
// flutter test test_screens/icons_test.dart --update-goldens
// Poi: dart run flutter_launcher_icons
import 'package:allergy_radar/widgets/radar_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _pine = Color(0xFF1F5A4A);

Future<void> _icon(WidgetTester tester, String path, double px, Widget child) async {
  tester.view.physicalSize = Size(px, px);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      child: SizedBox(width: px, height: px, child: child),
    ),
  );
  await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile(path));
}

void main() {
  testWidgets('icona classica', (tester) async {
    await _icon(
      tester,
      '../assets/launcher/icon_legacy.png',
      1024,
      Container(
        decoration: BoxDecoration(color: _pine, borderRadius: BorderRadius.circular(224)),
        padding: const EdgeInsets.all(190),
        child: const CustomPaint(painter: RadarPainter(color: Colors.white, stroke: 3.4)),
      ),
    );
  });

  testWidgets('icona adattiva, primo piano', (tester) async {
    // Zona sicura delle icone adattive: il 66% centrale.
    await _icon(
      tester,
      '../assets/launcher/icon_foreground.png',
      1024,
      const Padding(
        padding: EdgeInsets.all(300),
        child: CustomPaint(painter: RadarPainter(color: Colors.white, stroke: 3.4)),
      ),
    );
  });

  for (final (dir, px) in [('mdpi', 24.0), ('hdpi', 36.0), ('xhdpi', 48.0), ('xxhdpi', 72.0), ('xxxhdpi', 96.0)]) {
    testWidgets('barra di stato $dir', (tester) async {
      await _icon(
        tester,
        '../android/app/src/main/res/drawable-$dir/ic_stat_logo.png',
        px,
        Padding(
          padding: EdgeInsets.all(px / 12),
          child: const CustomPaint(painter: RadarPainter(color: Colors.white, stroke: 4.5, inner: false)),
        ),
      );
    });
  }
}
