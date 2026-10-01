import 'package:flutter/material.dart';

import '../models/level.dart';

abstract final class AppFonts {
  static const sans = 'Figtree';
  static const display = 'Fraunces';
}

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.bg,
    required this.card,
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.line,
    required this.track,
    required this.chip,
    required this.glyphBg,
    required this.pine,
    required this.onPine,
    required this.pineSoft,
    required this.pineText,
    required this.hero,
    required this.onHero,
    required this.heroTrack,
    required this.riskFill,
    required this.riskText,
    required this.riskOnFill,
    required this.symFill,
    required this.symOnFill,
  });

  final Color bg, card, ink, ink2, ink3, line, track, chip, glyphBg;
  final Color pine, onPine, pineSoft, pineText, hero, onHero, heroTrack;

  /// Indicizzati per [Level.index].
  final List<Color> riskFill, riskText, riskOnFill;

  /// Scala dei sintomi (0 nessuno … 3 forti): separata da quella dei pollini, con gradini ben distinti.
  /// Nel tema scuro cresce verso il chiaro, come la luce sullo sfondo scuro.
  final List<Color> symFill, symOnFill;

  Color fill(Level l) => riskFill[l.index];
  Color text(Level l) => riskText[l.index];
  Color onFill(Level l) => riskOnFill[l.index];

  static const light = AppPalette(
    bg: Color(0xFFF4F2EB),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF17201C),
    ink2: Color(0xFF46514B),
    ink3: Color(0xFF5C6661),
    line: Color(0xFFE2DED3),
    track: Color(0xFFE6E3DA),
    chip: Color(0xFFEFEDE5),
    glyphBg: Color(0xFFE7ECE3),
    pine: Color(0xFF1F5A4A),
    onPine: Color(0xFFFFFFFF),
    pineSoft: Color(0xFFE1ECE6),
    pineText: Color(0xFF1F5A4A),
    hero: Color(0xFF1F5A4A),
    onHero: Color(0xFFFFFFFF),
    heroTrack: Color(0x38FFFFFF),
    riskFill: [Color(0xFFE4E1D7), Color(0xFFEFD27F), Color(0xFFE59A48), Color(0xFFC4502B), Color(0xFF7A2338)],
    riskText: [Color(0xFF5C6661), Color(0xFF76580A), Color(0xFF94470A), Color(0xFFA63A1B), Color(0xFF7A2338)],
    riskOnFill: [Color(0xFF46514B), Color(0xFF2A2006), Color(0xFF2A1605), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    symFill: [Color(0xFFECEEE8), Color(0xFFCFE8DC), Color(0xFF5FA88A), Color(0xFF1F4F40)],
    symOnFill: [Color(0xFF46514B), Color(0xFF17201C), Color(0xFF0E1A15), Color(0xFFFFFFFF)],
  );

  static const dark = AppPalette(
    bg: Color(0xFF121715),
    card: Color(0xFF1B221F),
    ink: Color(0xFFECEFEA),
    ink2: Color(0xFFB9C2BC),
    ink3: Color(0xFF9AA49E),
    line: Color(0xFF2A3430),
    track: Color(0xFF2C3632),
    chip: Color(0xFF232B28),
    glyphBg: Color(0xFF22302A),
    pine: Color(0xFF7CC4A8),
    onPine: Color(0xFF0E1A15),
    pineSoft: Color(0xFF20332B),
    pineText: Color(0xFF8FD1B6),
    hero: Color(0xFF1E3A31),
    onHero: Color(0xFFEAF2EE),
    heroTrack: Color(0x29FFFFFF),
    riskFill: [Color(0xFF2C3632), Color(0xFFE3C46E), Color(0xFFE0913F), Color(0xFFD0613A), Color(0xFFB23A55)],
    riskText: [Color(0xFF9AA49E), Color(0xFFEBCB6E), Color(0xFFF0A860), Color(0xFFF2825E), Color(0xFFF08CA2)],
    riskOnFill: [Color(0xFFB9C2BC), Color(0xFF2A2006), Color(0xFF2A1605), Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
    symFill: [Color(0xFF232B28), Color(0xFF3A6152), Color(0xFF6FB89A), Color(0xFFCFEFE2)],
    symOnFill: [Color(0xFFB9C2BC), Color(0xFFECEFEA), Color(0xFF0E1A15), Color(0xFF0E1A15)],
  );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) => other is AppPalette && t >= 0.5 ? other : this;
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
