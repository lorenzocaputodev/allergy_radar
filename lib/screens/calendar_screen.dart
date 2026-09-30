import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/level_widgets.dart';
import 'allergen_detail_screen.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  static const _m = ['G', 'F', 'M', 'A', 'M', 'G', 'L', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final month = DateTime.now().month;
    final area = state.area;
    final mine = state.followedAllergens;
    final others = Allergens.all.where((a) => !state.followed.contains(a.id)).toList();

    Widget header() => Row(
      children: [
        const SizedBox(width: 124),
        for (var i = 0; i < 12; i++)
          Expanded(
            child: Text(
              _m[i],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: i == month - 1 ? FontWeight.w800 : FontWeight.w500,
                color: i == month - 1 ? p.ink : p.ink3,
              ),
            ),
          ),
      ],
    );

    Widget row(Allergen a) => InkWell(
      onTap: () =>
          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AllergenDetailScreen(allergenId: a.id))),
      child: SizedBox(
        height: 44,
        child: Row(
          children: [
            SizedBox(
              width: 124,
              child: Row(
                children: [
                  AllergenGlyph(a, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < 12; i++)
              Expanded(
                child: Container(
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: p.riskFill[a.calendarFor(area)[i]],
                    borderRadius: BorderRadius.circular(4),
                    border: i == month - 1 ? Border.all(color: p.ink, width: 1.5) : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    Widget label(String s) => Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Text(
        s.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.ink3),
      ),
    );

    final active = Allergens.all.where((a) => a.calendarFor(area)[month - 1] >= 2).map((a) => a.name).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Text('Calendario', style: Theme.of(context).textTheme.headlineMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Text(
            'Quando fioriscono, mese per mese · ${area.label}',
            style: TextStyle(fontSize: 14, color: p.ink3),
          ),
        ),
        SectionCard(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
          gap: 6,
          children: [
            header(),
            if (mine.isNotEmpty) ...[label('I tuoi'), ...mine.map(row)],
            if (others.isNotEmpty) ...[label('Altri'), ...others.map(row)],
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                for (final (i, n) in [(0, 'Assente'), (1, 'Basso'), (2, 'Moderato'), (3, 'Alto')])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(color: p.riskFill[i], borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 6),
                      Text(n, style: TextStyle(fontSize: 12, color: p.ink2)),
                    ],
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        SectionCard(
          children: [
            Text('In ${Fmt.month(month)}', style: Theme.of(context).textTheme.titleLarge),
            Text(
              active.isEmpty
                  ? 'Mese tranquillo: nessun polline di solito sopra il livello basso.'
                  : 'Di solito attivi: ${active.join(', ')}.',
              style: TextStyle(fontSize: 15, height: 1.5, color: p.ink2),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Livello medio di ogni mese nelle stazioni POLLnet dell’area ${area.label}, 2016–2025. '
          'L’area segue il luogo scelto. Il dato di oggi è nella scheda Oggi.',
          style: TextStyle(fontSize: 13, color: p.ink3),
        ),
      ],
    );
  }
}
