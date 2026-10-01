import 'package:flutter/material.dart';

import '../models/pollen_snapshot.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import 'level_widgets.dart';

class AllergenCard extends StatelessWidget {
  const AllergenCard({super.key, required this.status, required this.today, this.onTap, this.aboveThreshold = false});

  final AllergenStatus status;
  final DateTime today;
  final VoidCallback? onTap;
  final bool aboveThreshold;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = status.allergen;
    final value = status.value == null ? 'stima di ${Fmt.month(today.month)}' : Fmt.grains(status.value!);
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AllergenGlyph(a),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(a.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 2),
                        Text(a.family, style: TextStyle(fontSize: 13, color: p.ink3)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        LevelWord(status.level),
                        const SizedBox(height: 3),
                        Text(
                          value,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 13, color: p.ink2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RiskBar(status.level),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SourceChip(status.kind, detail: Fmt.sourceDetail(status, today)),
                  if (aboveThreshold)
                    Text(
                      'Sopra la tua soglia',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.text(status.level)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
