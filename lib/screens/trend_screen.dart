import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../models/trend.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/level_widgets.dart';
import '../widgets/page_list.dart';
import 'log_entry_screen.dart';

class TrendScreen extends StatefulWidget {
  const TrendScreen({super.key});

  @override
  State<TrendScreen> createState() => _TrendScreenState();
}

class _TrendScreenState extends State<TrendScreen> {
  static const _periods = {30: '30 giorni', 90: '3 mesi', 365: '1 anno'};
  static const _since = {30: 'negli ultimi 30 giorni', 90: 'negli ultimi 3 mesi', 365: 'nell’ultimo anno'};
  String? _allergenId;
  int _period = 30;

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryState>();
    final app = context.watch<AppState>();
    final choices = app.followedAllergens.isEmpty ? Allergens.all : app.followedAllergens;
    final now = DateTime.now();
    final a = Allergens.byId(_allergenId ?? '') ?? _mostTelling(diary, app, choices, now) ?? choices.first;
    final insight = diary.insight(a, now, threshold: app.thresholdOf(a), days: _period);
    final logged = diary.withLevel(a, now, _period).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Andamento')),
      body: PageList(
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
          if (diary.entries.length >= DiaryState.minDaysForInsight) ...[
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [for (final e in _periods.entries) ButtonSegment(value: e.key, label: Text(e.value))],
              selected: {_period},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _period = v.first),
            ),
          ],
          const SizedBox(height: 14),
          if (insight == null)
            _Progress(allergen: a, logged: logged, status: app.snapshot?[a.id])
          else
            _Answer(insight: insight, period: _since[_period]!),
          const SizedBox(height: 14),
          _Trend(
            key: ValueKey((a.id, _period)),
            allergen: a,
            step: TrendBucket.stepFor(_period),
            buckets: TrendBucket.build(entries: diary.entries, allergenId: a.id, period: _period, today: now),
          ),
          const SizedBox(height: 12),
          Text(
            'È un confronto, non una diagnosi: portalo all’allergologo.',
            style: TextStyle(fontSize: 13, color: context.palette.ink3),
          ),
        ],
      ),
    );
  }

  Allergen? _mostTelling(DiaryState diary, AppState app, List<Allergen> choices, DateTime now) {
    Allergen? best;
    var gap = 0.0;
    for (final c in choices) {
      final i = diary.insight(c, now, threshold: app.thresholdOf(c), days: _period);
      if (i != null && (i.highMean - i.lowMean) > gap) {
        gap = i.highMean - i.lowMean;
        best = c;
      }
    }
    return best;
  }
}

// --- Risposta ---
class _Progress extends StatelessWidget {
  const _Progress({required this.allergen, required this.logged, required this.status});

  final Allergen allergen;
  final int logged;
  final AllergenStatus? status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const need = DiaryState.minDaysForInsight;
    final enough = logged >= need;
    final name = allergen.name;
    final unmeasured = !allergen.hasForecast && status?.kind == DataKind.estimate;
    final String title;
    final String text;
    if (enough) {
      title = 'Servono giorni diversi';
      text = 'Per il confronto servono giorni con $name sotto la tua soglia e altri sopra.';
    } else if (unmeasured && logged == 0) {
      title = 'Nessuna misura vicina';
      text = 'Nella tua zona $name non ha misure recenti: il confronto parte quando arrivano.';
    } else {
      title = need - logged == 1 ? 'Ancora 1 giorno' : 'Ancora ${need - logged} giorni';
      text = allergen.hasForecast
          ? 'Dopo $need giorni di diario vedi se i sintomi peggiorano con $name.'
          : 'Dopo $need giorni di diario con una misura di $name vedi se i sintomi peggiorano. '
                'ISPRA pubblica le misure una volta a settimana: i giorni passati si completano da soli.';
    }
    return SectionCard(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: p.ink2)),
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

class _Answer extends StatelessWidget {
  const _Answer({required this.insight, required this.period});

  final DiaryInsight insight;
  final String period;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = insight.allergen;
    final headline = !insight.clear
        ? 'Nessuna differenza netta con ${a.name}'
        : insight.highMean > insight.lowMean
        ? 'Con più ${a.name} nell’aria stai peggio'
        : 'Con più ${a.name} nell’aria non stai peggio';

    Widget bar(String label, double value, int days, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, color: p.onHero)),
            ),
            Text(
              '${Fmt.number(value)} su ${DiaryInsight.maxScore}',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.onHero),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (value / DiaryInsight.maxScore).clamp(0, 1).toDouble(),
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
            'Punteggio medio $period: sintomi da 0 a 3 più farmaci da 0 a 2',
            style: TextStyle(fontSize: 13, color: p.onHero.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 16),
          bar('Giorni con ${a.name} sopra la tua soglia', insight.highMean, insight.highDays, p.fill(Level.high)),
          const SizedBox(height: 14),
          bar('Giorni con ${a.name} sotto la tua soglia', insight.lowMean, insight.lowDays, p.fill(Level.low)),
        ],
      ),
    );
  }
}

// --- Andamento nel tempo ---
class _Trend extends StatefulWidget {
  const _Trend({super.key, required this.allergen, required this.step, required this.buckets});

  final Allergen allergen;
  final TrendStep step;
  final List<TrendBucket> buckets;

  @override
  State<_Trend> createState() => _TrendState();
}

class _TrendState extends State<_Trend> {
  static const _barHeight = 90.0;
  late int _selected = widget.buckets.length - 1;

  void _pick(double dx, double width) {
    final i = (dx / width * widget.buckets.length).floor().clamp(0, widget.buckets.length - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  static String _capital(String s) => '${s[0].toUpperCase()}${s.substring(1)}';

  String _tick(int i) {
    final b = widget.buckets[i];
    final back = widget.buckets.length - 1 - i;
    final every = widget.step == TrendStep.day ? 7 : 4;
    return switch (widget.step) {
      TrendStep.month => _capital(Fmt.month(b.from.month))[0],
      _ when back % every != 0 => '',
      _ => back == 0 ? 'Oggi' : '${b.from.day}/${b.from.month}',
    };
  }

  String _title(TrendBucket b) => switch (widget.step) {
    TrendStep.day => Fmt.longDate(b.from),
    TrendStep.week => '${Fmt.shortDate(b.from)} – ${Fmt.shortDate(b.to)}',
    TrendStep.month => '${_capital(Fmt.month(b.from.month))} ${b.from.year}',
  };

  String _detail(TrendBucket b) {
    final pollen = b.pollen;
    final name = widget.allergen.name;
    if (widget.step == TrendStep.day) {
      final e = b.entries.firstOrNull;
      if (e == null) return 'Non registrato';
      return [
        DiaryEntry.symptomNames[e.severity],
        if (pollen != null) '$name ${pollen.label.toLowerCase()}',
        if (e.meds.isNotEmpty) e.meds.join(', '),
      ].join(' · ');
    }
    final mean = b.symptoms;
    if (mean == null) return 'Nessun giorno registrato';
    return [
      '${b.logged} ${b.logged == 1 ? 'giorno registrato' : 'giorni registrati'}',
      'sintomi in media ${Fmt.number(mean)} su 3',
      if (pollen != null) '$name fino a ${pollen.label.toLowerCase()}',
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final buckets = widget.buckets;
    final step = widget.step;
    TextStyle label() => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink2);

    Widget columns(Widget Function(int i, TrendBucket b) cell) => Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, b) in buckets.indexed) ...[
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: i == _selected ? p.pine.withValues(alpha: 0.22) : null,
                borderRadius: BorderRadius.circular(4),
              ),
              child: cell(i, b),
            ),
          ),
          if (i < buckets.length - 1) const SizedBox(width: 2),
        ],
      ],
    );

    final selected = buckets[_selected];
    final day = step == TrendStep.day ? selected.from : null;
    final (title, hint) = switch (step) {
      TrendStep.day => ('Giorno per giorno', 'un giorno'),
      TrendStep.week => ('Settimana per settimana', 'una settimana'),
      TrendStep.month => ('Mese per mese', 'un mese'),
    };

    return SectionCard(
      gap: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text('Tocca o trascina sul grafico per vedere $hint.', style: TextStyle(fontSize: 13, color: p.ink3)),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _pick(d.localPosition.dx, c.maxWidth),
            onHorizontalDragUpdate: (d) => _pick(d.localPosition.dx, c.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.allergen.name, style: label()),
                const SizedBox(height: 6),
                columns((i, b) {
                  final l = b.pollen;
                  return Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: l == null ? null : p.fill(l),
                      borderRadius: BorderRadius.circular(3),
                      border: l == null ? Border.all(color: p.line) : null,
                    ),
                  );
                }),
                const SizedBox(height: 10),
                Text('Sintomi', style: label()),
                const SizedBox(height: 6),
                SizedBox(
                  height: _barHeight,
                  child: columns((i, b) {
                    final v = b.symptoms;
                    return Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: v == null || v == 0 ? 3 : v / 3 * _barHeight,
                        decoration: BoxDecoration(
                          color: v == null ? p.line : p.symFill[v.round().clamp(1, 3)],
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                columns((i, b) {
                  final text = _tick(i);
                  if (text.isEmpty) return const SizedBox(height: 14);
                  return SizedBox(
                    height: 14,
                    child: OverflowBox(
                      maxWidth: 48,
                      alignment: text == 'Oggi' ? Alignment.centerRight : Alignment.center,
                      child: Text(text, softWrap: false, style: TextStyle(fontSize: 10, color: p.ink3)),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        Material(
          color: p.chip,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: day == null
                ? null
                : () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: day), fullscreenDialog: true)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 10, day == null ? 14 : 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title(selected), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        Text(_detail(selected), style: TextStyle(fontSize: 13, height: 1.35, color: p.ink2)),
                      ],
                    ),
                  ),
                  if (day != null) ...[
                    Text(
                      selected.entries.isEmpty ? 'Registra' : 'Apri',
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.pineText),
                    ),
                    Icon(Icons.chevron_right, color: p.pineText),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
