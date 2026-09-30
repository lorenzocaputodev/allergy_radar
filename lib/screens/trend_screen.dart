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
import 'log_entry_screen.dart';

/// Sintomi confrontati con un allergene negli ultimi 30 giorni: prima la risposta, poi i dettagli.
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
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in choices)
                ChoiceChip(
                  label: Text(c.name),
                  selected: c.id == a.id,
                  onSelected: (_) => setState(() => _allergenId = c.id),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (insight == null) _Progress(allergen: a, logged: logged) else _Answer(insight: insight),
          const SizedBox(height: 14),
          _DayByDay(allergen: a, days: days, diary: diary),
          const SizedBox(height: 12),
          Text(
            'È un confronto, non una diagnosi: portalo all’allergologo.',
            style: TextStyle(fontSize: 13, color: context.palette.ink3),
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
}

/// Dati non ancora sufficienti: quanto manca.
class _Progress extends StatelessWidget {
  const _Progress({required this.allergen, required this.logged});

  final Allergen allergen;
  final int logged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const need = DiaryState.minDaysForInsight;
    final enough = logged >= need;
    return SectionCard(
      children: [
        Text(
          enough ? 'Servono giorni diversi' : need - logged == 1 ? 'Ancora 1 giorno' : 'Ancora ${need - logged} giorni',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          enough
              ? 'Per il confronto servono giorni con ${allergen.name} sia alto sia basso.'
              : 'Con $need giorni di diario ti dico se ${allergen.name} ti dà fastidio.',
          style: TextStyle(fontSize: 14, height: 1.4, color: p.ink2),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (logged / need).clamp(0, 1).toDouble(),
            minHeight: 8,
            color: p.pine,
            backgroundColor: p.track,
          ),
        ),
        Text('$logged di $need giorni', style: TextStyle(fontSize: 12, color: p.ink3)),
      ],
    );
  }
}

/// La risposta in una frase e il confronto a due barre.
class _Answer extends StatelessWidget {
  const _Answer({required this.insight});

  final DiaryInsight insight;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = insight.allergen;
    final headline = !insight.clear
        ? 'Nessuna differenza netta con ${a.name}'
        : insight.highMean > insight.lowMean
        ? 'Quando ${a.name} sale, stai peggio'
        : 'Quando ${a.name} sale, non stai peggio';

    Widget bar(String label, double value, int days, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: p.onHero)),
            ),
            Text(
              '${Fmt.number(value)} su 3',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.onHero),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / 3).clamp(0, 1).toDouble(),
            minHeight: 12,
            color: color,
            backgroundColor: p.heroTrack,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$days ${days == 1 ? 'giorno' : 'giorni'}',
          style: TextStyle(fontSize: 12, color: p.onHero.withValues(alpha: 0.8)),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, height: 1.25, color: p.onHero),
          ),
          const SizedBox(height: 4),
          Text(
            'Intensità media dei sintomi, ultimi 30 giorni',
            style: TextStyle(fontSize: 13, color: p.onHero.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 16),
          bar('Giorni con ${a.name} da moderato in su', insight.highMean, insight.highDays, p.fill(Level.high)),
          const SizedBox(height: 14),
          bar('Altri giorni', insight.lowMean, insight.lowDays, p.fill(Level.low)),
        ],
      ),
    );
  }
}

/// Ogni colonna è un giorno: sopra il livello del polline, sotto i sintomi, in fondo i farmaci.
class _DayByDay extends StatelessWidget {
  const _DayByDay({required this.allergen, required this.days, required this.diary});

  final Allergen allergen;
  final List<DateTime> days;
  final DiaryState diary;

  static const _barHeight = 90.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    TextStyle label() => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink2);

    Widget columns(Widget Function(DateTime d, DiaryEntry? e) cell) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in days) ...[
          Expanded(child: cell(d, diary.entryFor(d))),
          if (d != days.last) const SizedBox(width: 2),
        ],
      ],
    );

    void open(DateTime d) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: d), fullscreenDialog: true));

    return SectionCard(
      gap: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Giorno per giorno', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text(
              'Ogni colonna è un giorno. Toccala per aprire la voce.',
              style: TextStyle(fontSize: 13, color: p.ink3),
            ),
          ],
        ),
        Text(allergen.name, style: label()),
        columns((d, e) {
          final l = e?.pollen[allergen.id];
          return Container(
            height: 16,
            decoration: BoxDecoration(
              color: l == null ? null : p.fill(Level.fromIndex(l)),
              borderRadius: BorderRadius.circular(3),
              border: l == null ? Border.all(color: p.line) : null,
            ),
          );
        }),
        Text('Sintomi', style: label()),
        SizedBox(
          height: _barHeight,
          child: columns(
            (d, e) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => open(d),
              child: SizedBox(
                height: _barHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: e == null || e.severity == 0 ? 3 : e.severity / 3 * _barHeight,
                    decoration: BoxDecoration(
                      color: e == null ? p.line : p.symFill[e.severity == 0 ? 1 : e.severity],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        columns(
          (d, e) => Text(
            d == days.first || d.difference(days.first).inDays % 7 == 0 ? '${d.day}/${d.month}' : '',
            textAlign: TextAlign.left,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(fontSize: 10, color: p.ink3),
          ),
        ),
        Text('Farmaci', style: label()),
        columns(
          (d, e) => Center(
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (e?.meds.isNotEmpty ?? false) ? p.ink2 : null,
                border: Border.all(color: (e?.meds.isNotEmpty ?? false) ? p.ink2 : p.line),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
