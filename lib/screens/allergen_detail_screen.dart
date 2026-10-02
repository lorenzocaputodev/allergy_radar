import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../models/station.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/level_widgets.dart';
import '../widgets/page_list.dart';

class AllergenDetailScreen extends StatelessWidget {
  const AllergenDetailScreen({super.key, required this.allergenId});

  final String allergenId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final s = state.snapshot?[allergenId];
    final a = Allergens.byId(allergenId)!;
    final now = DateTime.now();
    final t = a.thresholds;
    String r(double x) => Fmt.number(x);

    return Scaffold(
      appBar: AppBar(),
      body: PageList(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
            child: Row(
              children: [
                AllergenGlyph(a, size: 72),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, style: Theme.of(context).textTheme.headlineMedium),
                      Text(a.family, style: TextStyle(fontSize: 14, color: p.ink3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (s != null) ...[
            SectionCard(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(switch (s.kind) {
                            DataKind.forecast => 'Oggi, media del giorno',
                            DataKind.measured => 'Ultima misura, ${Fmt.shortDate(s.date!)}',
                            DataKind.estimate => 'Stima per ${Fmt.month(now.month)}',
                          }, style: TextStyle(fontSize: 13, color: p.ink3)),
                          const SizedBox(height: 4),
                          LevelWord(s.level, size: 36),
                        ],
                      ),
                    ),
                    if (s.value != null)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: Fmt.number(s.value!),
                              style: const TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: '  granuli/m³',
                              style: TextStyle(fontSize: 14, color: p.ink2),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                RiskBar(s.level, height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (l, range) in [
                      (Level.low, '${r(t.low)}–${r(t.moderate)}'),
                      (Level.moderate, '${r(t.moderate)}–${r(t.high)}'),
                      (Level.high, '${r(t.high)}–${r(t.veryHigh)}'),
                      (Level.veryHigh, 'da ${r(t.veryHigh)}'),
                    ])
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${l.label}\n',
                                style: TextStyle(fontWeight: FontWeight.w700, color: p.text(l)),
                              ),
                              TextSpan(text: range),
                            ],
                          ),
                          style: TextStyle(fontSize: 11, height: 1.3, color: p.ink3),
                        ),
                      ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: SourceChip(s.kind, detail: Fmt.sourceDetail(s, now)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (s.hourly.isNotEmpty) ...[
              SectionCard(
                children: [
                  Text('Ora per ora', style: Theme.of(context).textTheme.titleLarge),
                  _Bars(
                    values: s.hourly.where((h) => h.date.hour.isEven).toList(),
                    label: (d) => d.date.day == s.hourly.first.date.day ? '${d.date.hour}' : '24',
                    height: 110,
                    thresholds: t,
                    current: (d) => d.date.day == now.day && d.date.hour == now.hour - now.hour % 2,
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            if (s.series.length > 1)
              SectionCard(
                children: [
                  Text(
                    s.kind == DataKind.forecast ? 'Prossimi giorni' : 'Ultimi giorni misurati',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  _Bars(
                    values: s.kind == DataKind.forecast
                        ? s.series
                        : s.series.skip(s.series.length > 14 ? s.series.length - 14 : 0).toList(),
                    label: (d) => s.kind == DataKind.forecast ? Fmt.weekday(d.date, now) : '${d.date.day}',
                    height: 140,
                    thresholds: t,
                  ),
                ],
              ),
            if (s.series.length > 1) const SizedBox(height: 14),
            if (s.kind != DataKind.forecast)
              SectionCard(
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: p.ink),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.kind == DataKind.measured ? 'Da dove arriva' : 'Perché è una stima',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _whyText(s, state.snapshot?.nearestStation, state.area, now),
                    style: TextStyle(fontSize: 14, height: 1.5, color: p.ink2),
                  ),
                ],
              ),
            if (s.kind != DataKind.forecast) const SizedBox(height: 14),
          ],
          SectionCard(
            children: [
              Text('Stagione', style: Theme.of(context).textTheme.titleLarge),
              SeasonStrip(a.calendarFor(state.area), month: now.month),
              Text(
                'Valore tipico di ogni mese, area ${state.area.label}.',
                style: TextStyle(fontSize: 13, color: p.ink3),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SectionCard(
            children: [
              Text('Ti dà fastidio da', style: Theme.of(context).textTheme.titleLarge),
              SegmentedButton<Level>(
                segments: const [
                  ButtonSegment(value: Level.low, label: Text('Basso')),
                  ButtonSegment(value: Level.moderate, label: Text('Moderato')),
                  ButtonSegment(value: Level.high, label: Text('Alto')),
                ],
                selected: {state.thresholdOf(a)},
                showSelectedIcon: false,
                onSelectionChanged: (v) => state.setThreshold(a, v.first),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.values,
    required this.label,
    required this.height,
    required this.thresholds,
    this.current,
  });

  final List<DayValue> values;
  final String Function(DayValue) label;
  final double height;

  final bool Function(DayValue)? current;

  final Thresholds thresholds;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final max = values.fold<double>(thresholds.moderate * 1.5, (m, v) => v.value > m ? v.value : m);
    final refBottom = thresholds.moderate / max * height;
    final now = current == null ? -1 : values.indexWhere(current!);
    return Column(
      children: [
        SizedBox(
          height: height + 18,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: refBottom,
                child: Container(height: 1.5, color: p.text(Level.moderate).withValues(alpha: 0.8)),
              ),
              _barRow(p, max, now),
            ],
          ),
        ),
        Divider(color: p.line, height: 1),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final (i, v) in values.indexed) ...[
              Expanded(
                child: Text(
                  label(v),
                  textAlign: TextAlign.center,
                  style: i == now
                      ? TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.ink)
                      : TextStyle(fontSize: 11, color: p.ink3),
                ),
              ),
              if (v != values.last) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(width: 16, height: 1.5, color: p.text(Level.moderate)),
            const SizedBox(width: 6),
            Text(
              'Sopra la linea il livello è almeno moderato (${Fmt.number(thresholds.moderate)} granuli/m³)',
              style: TextStyle(fontSize: 12, color: p.ink2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _barRow(AppPalette p, double max, int now) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final (i, v) in values.indexed) ...[
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ColoredBox(
                color: p.card,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
                  child: Text(Fmt.number(v.value), maxLines: 1, style: TextStyle(fontSize: 10, color: p.ink3)),
                ),
              ),
              Container(
                height: (v.value / max * height).clamp(3, height),
                decoration: BoxDecoration(
                  color: v.level == Level.none ? p.track : p.fill(v.level),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(6), bottom: Radius.circular(2)),
                  border: i == now ? Border.all(color: p.ink, width: 2) : null,
                ),
              ),
            ],
          ),
        ),
        if (v != values.last) const SizedBox(width: 5),
      ],
    ],
  );
}

String _whyText(AllergenStatus s, NearStation? nearest, Area area, DateTime now) {
  if (s.kind == DataKind.measured) {
    final day = s.date == null ? '' : ' del ${Fmt.shortDate(s.date!)}';
    return 'Per questo polline non c’è una previsione: è l’ultima misura$day della stazione di '
        '${s.station!.station.name}. ISPRA pubblica le misure una volta a settimana.';
  }
  final why = s.allergen.hasForecast
      ? 'Oggi la previsione non è disponibile'
      : nearest != null
      ? 'Per questo polline non c’è una previsione e le stazioni vicine non hanno misure recenti'
      : 'Per questo polline non c’è una previsione e non ci sono stazioni di misura vicine';
  return '$why: mostriamo il valore tipico di ${Fmt.month(now.month)} nell’area ${area.label}.';
}
