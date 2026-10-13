import 'package:flutter/material.dart';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/outdoor_plan.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import 'level_widgets.dart';

// --- Foglio ---
Future<void> showOutdoorSheet(BuildContext context, OutdoorPlan plan) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.palette.card,
  builder: (_) => OutdoorSheet(plan: plan),
);

class OutdoorSheet extends StatelessWidget {
  const OutdoorSheet({super.key, required this.plan});

  final OutdoorPlan plan;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final hours = [for (var h = OutdoorPlan.firstHour; h <= OutdoorPlan.lastHour; h++) h];

    String avoidText(HourSpan s) {
      final (from, to) = s;
      if (from <= plan.nowHour) return 'fino alle ${to + 1}';
      if (to >= OutdoorPlan.lastHour) return 'dalle $from in poi';
      return 'dalle $from alle ${to + 1}';
    }

    Widget verdict(IconData icon, Color color, String text) => Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: p.ink),
          ),
        ),
      ],
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Oggi, ora per ora', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(Fmt.list(plan.allergens), style: TextStyle(fontSize: 14, color: p.ink3)),
            const SizedBox(height: 22),
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final h in hours)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: _Bar(level: plan.levels[h], now: h == plan.nowHour, past: h < plan.nowHour),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final h in hours)
                  Expanded(
                    child: Text(
                      h % 3 == 0 ? '$h' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: p.ink3),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            verdict(Icons.check_circle_outline, p.pineText, 'Meglio: ${plan.good.map(plan.span).join(' e ')}'),
            if (plan.avoid case final a?) ...[
              const SizedBox(height: 10),
              verdict(
                Icons.do_not_disturb_on_outlined,
                p.text(plan.levels[a.$1] ?? Level.high),
                'Evita: ${avoidText(a)}',
              ),
            ],
            const SizedBox(height: 18),
            const SourceChip(DataKind.forecast, detail: 'Open-Meteo, CAMS Europa'),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.level, required this.now, required this.past});

  final Level? level;
  final bool now;
  final bool past;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = level;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (now)
          Text(
            'ora',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.ink),
          )
        else
          const SizedBox(height: 15),
        const SizedBox(height: 4),
        Container(
          height: 20.0 + 22 * (l?.index ?? 0),
          decoration: BoxDecoration(
            color: l == null ? p.track : (past ? p.fill(l).withValues(alpha: 0.35) : p.fill(l)),
            borderRadius: BorderRadius.circular(6),
            border: now ? Border.all(color: p.ink, width: 2) : null,
          ),
        ),
      ],
    );
  }
}
