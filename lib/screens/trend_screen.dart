import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/level_widgets.dart';

/// Sintomi, farmaci e un allergene negli ultimi 30 giorni.
class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  static const _days = 30;
  String? _allergenId;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final diary = context.watch<DiaryState>();
    final app = context.watch<AppState>();
    final choices = app.followedAllergens.isEmpty ? Allergens.all : app.followedAllergens;
    final now = DateTime.now();
    // Di default l'allergene che spiega di più i sintomi, se il diario basta per dirlo.
    final a = Allergens.byId(_allergenId ?? '') ?? _mostTelling(diary, choices, now) ?? choices.first;
    final today = DiaryEntry.day(now);
    final days = [for (var i = _days - 1; i >= 0; i--) today.subtract(Duration(days: i))];
    final insight = diary.insight(a, now, days: _days);
    final logged = diary.between(days.first, today).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Andamento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          DropdownButtonFormField<String>(
            initialValue: a.id,
            decoration: InputDecoration(
              labelText: 'Confronta con',
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
            items: [for (final c in choices) DropdownMenuItem(value: c.id, child: Text(c.name))],
            onChanged: (v) => setState(() => _allergenId = v),
          ),
          const SizedBox(height: 14),
          SectionCard(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ultimi $_days giorni', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(
                    '$logged giorni registrati. I pollini sono quelli salvati con ogni voce.',
                    style: TextStyle(fontSize: 13, color: p.ink3),
                  ),
                ],
              ),
              _label(context, '${a.name}, livello del giorno'),
              _strip(days, (d) {
                final l = diary.entryFor(d)?.pollen[a.id];
                return l == null ? null : p.fill(Level.fromIndex(l));
              }, p),
              _label(context, 'I tuoi sintomi, 0–3'),
              SizedBox(
                height: 110,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final d in days) ...[
                      Expanded(child: _symptomBar(diary.entryFor(d), p)),
                      if (d != days.last) const SizedBox(width: 2),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  for (final d in days) ...[
                    Expanded(
                      child: Text(
                        d.day == 1 || d == days.first || d == today ? '${d.day}' : '',
                        textAlign: TextAlign.center,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        style: TextStyle(fontSize: 10, color: p.ink3),
                      ),
                    ),
                    if (d != days.last) const SizedBox(width: 2),
                  ],
                ],
              ),
              _label(context, 'Farmaci'),
              Row(
                children: [
                  for (final d in days) ...[
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (diary.entryFor(d)?.meds.isNotEmpty ?? false) ? p.ink2 : null,
                            border: Border.all(color: (diary.entryFor(d)?.meds.isNotEmpty ?? false) ? p.ink2 : p.line),
                          ),
                        ),
                      ),
                    ),
                    if (d != days.last) const SizedBox(width: 2),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (insight == null)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.line, width: 1.5),
              ),
              child: Text(
                'Servono almeno ${DiaryState.minDaysForInsight} giorni registrati negli ultimi $_days, con giorni sia sopra sia '
                'sotto il livello moderato di ${a.name}, per un confronto. Finora: $logged.',
                style: TextStyle(fontSize: 14, height: 1.5, color: p.ink2),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(22)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COSA EMERGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: p.onHero.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insight.clear
                        ? (insight.highMean > insight.lowMean
                              ? 'I tuoi sintomi salgono quando ${a.name} è da moderato in su.'
                              : 'Con ${a.name} alto non stai peggio: forse non è lui a darti fastidio.')
                        : 'Per ora nessuna differenza netta con ${a.name}.',
                    style: TextStyle(fontFamily: AppFonts.display, fontSize: 21, height: 1.3, color: p.onHero),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Da moderato in su: sintomi medi ${Fmt.number(insight.highMean)} su 3 (${insight.highDays} giorni). '
                    'Sotto: ${Fmt.number(insight.lowMean)} (${insight.lowDays} giorni).',
                    style: TextStyle(fontSize: 14, height: 1.5, color: p.onHero.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'È una correlazione, non una diagnosi. Portala al tuo allergologo insieme al diario.',
            style: TextStyle(fontSize: 13, color: p.ink3),
          ),
        ],
      ),
    );
  }

  Allergen? _mostTelling(DiaryState diary, List<Allergen> choices, DateTime now) {
    Allergen? best;
    var gap = 0.0;
    for (final c in choices) {
      final i = diary.insight(c, now, days: _days);
      if (i != null && (i.highMean - i.lowMean) > gap) {
        gap = i.highMean - i.lowMean;
        best = c;
      }
    }
    return best;
  }

  Widget _label(BuildContext context, String s) => Text(
    s,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.palette.ink2),
  );

  Widget _strip(List<DateTime> days, Color? Function(DateTime) color, AppPalette p) => Row(
    children: [
      for (final d in days) ...[
        Expanded(
          child: Container(
            height: 18,
            decoration: BoxDecoration(
              color: color(d),
              borderRadius: BorderRadius.circular(3),
              border: color(d) == null ? Border.all(color: p.line) : null,
            ),
          ),
        ),
        if (d != days.last) const SizedBox(width: 2),
      ],
    ],
  );

  Widget _symptomBar(DiaryEntry? e, AppPalette p) {
    if (e == null) return Container(height: 3, color: p.line);
    return Container(
      height: e.score == 0 ? 3 : (e.score / 3 * 110).clamp(3, 110),
      decoration: BoxDecoration(
        color: e.score == 0 ? p.symFill[1] : p.symFill[3],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}
