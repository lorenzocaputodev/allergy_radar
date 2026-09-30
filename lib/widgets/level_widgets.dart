import 'package:flutter/material.dart';

import '../models/allergen.dart';
import '../models/level.dart';
import '../theme/palette.dart';

/// Barra a 4 segmenti: il livello si legge anche senza colore.
class RiskBar extends StatelessWidget {
  const RiskBar(this.level, {super.key, this.height = 8, this.track});

  final Level level;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 1; i <= 4; i++) ...[
            if (i > 1) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: i <= level.index ? p.riskFill[i] : (track ?? p.track),
                  borderRadius: BorderRadius.circular(height / 2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class LevelPill extends StatelessWidget {
  const LevelPill(this.level, {super.key, this.small = false});

  final Level level;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Larghezza minima uguale per tutti i livelli: in colonna le pillole restano allineate.
    return Container(
      height: small ? 24 : 28,
      constraints: BoxConstraints(minWidth: small ? 88 : 100),
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 11),
      alignment: Alignment.center,
      decoration: BoxDecoration(color: p.fill(level), borderRadius: BorderRadius.circular(999)),
      child: Text(
        level.label,
        style: TextStyle(fontSize: small ? 12 : 13, fontWeight: FontWeight.w700, color: p.onFill(level)),
      ),
    );
  }
}

class LevelWord extends StatelessWidget {
  const LevelWord(this.level, {super.key, this.size = 22});

  final Level level;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    level.label,
    style: TextStyle(
      fontFamily: AppFonts.display,
      fontSize: size,
      height: 1.05,
      fontWeight: FontWeight.w600,
      color: context.palette.text(level),
    ),
  );
}

/// Da dove arriva il dato: obbligatorio accanto a ogni valore.
class SourceChip extends StatelessWidget {
  const SourceChip(this.kind, {super.key, this.detail});

  final DataKind kind;
  final String? detail;

  static String label(DataKind k) => switch (k) {
    DataKind.forecast => 'Previsione',
    DataKind.measured => 'Misurato',
    DataKind.estimate => 'Stima',
  };

  static IconData _icon(DataKind k) => switch (k) {
    DataKind.forecast => Icons.layers_outlined,
    DataKind.measured => Icons.sensors,
    DataKind.estimate => Icons.calendar_month_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(kind), size: 15, color: p.ink2),
          const SizedBox(width: 6),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: label(kind),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detail != null) TextSpan(text: ' · $detail'),
                ],
              ),
              style: TextStyle(fontSize: 12, color: p.ink2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class AllergenGlyph extends StatelessWidget {
  const AllergenGlyph(this.allergen, {super.key, this.size = 52});

  final Allergen allergen;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.glyphBg, shape: BoxShape.circle),
      child: Icon(allergen.icon, size: size * 0.52, color: p.ink),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children, this.padding = const EdgeInsets.all(18), this.gap = 14});

  final List<Widget> children;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
        ],
      ),
    );
  }
}

/// Striscia dei 12 mesi con il mese corrente evidenziato.
class SeasonStrip extends StatelessWidget {
  const SeasonStrip(this.calendar, {super.key, required this.month});

  final List<int> calendar;
  final int month;

  static const _m = ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var i = 0; i < 12; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: p.riskFill[calendar[i]],
                    borderRadius: BorderRadius.circular(6),
                    border: i == month - 1 ? Border.all(color: p.ink, width: 2) : null,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _m[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == month - 1 ? FontWeight.w800 : FontWeight.w400,
                    color: i == month - 1 ? p.ink : p.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Intensità dei sintomi come 1, 2 o 3 pallini pieni su 3: il livello non dipende solo dal colore.
class SeverityDots extends StatelessWidget {
  const SeverityDots(this.severity, {super.key, required this.color, this.size = 6});

  final int severity;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++) ...[
          if (i > 1) SizedBox(width: size / 2),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= severity ? color : null,
              border: Border.all(color: color, width: 1.2),
            ),
          ),
        ],
      ],
    ),
  );
}
