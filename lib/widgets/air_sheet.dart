import 'package:flutter/material.dart';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../theme/palette.dart';
import 'level_widgets.dart';

// --- Testi ---
extension AirMetricText on AirMetric {
  String get title => switch (this) {
    AirMetric.ozone => 'Ozono',
    AirMetric.pm25 => 'Polveri fini (PM2.5)',
    AirMetric.dust => 'Sabbia del deserto',
  };

  String get what => switch (this) {
    AirMetric.ozone =>
      'Gas che si forma con il sole a partire dallo smog di traffico e industrie. Sale nelle ore calde e nei '
          'pomeriggi d\'estate, spesso più in periferia e in collina che in centro.',
    AirMetric.pm25 =>
      'Particelle più piccole di 2,5 millesimi di millimetro, prodotte da traffico, riscaldamento e industria. '
          'Sono così fini da arrivare in profondità nei polmoni.',
    AirMetric.dust =>
      'Sabbia portata dal vento, quasi sempre dal Sahara. Arriva a ondate di pochi giorni, più spesso al Sud e '
          'nelle isole, e di solito è assente.',
  };

  String get why => switch (this) {
    AirMetric.ozone =>
      'Irrita naso e bronchi e li rende più sensibili: con l\'ozono alto, la stessa quantità di polline dà '
          'sintomi più forti.',
    AirMetric.pm25 =>
      'Tengono infiammate le vie respiratorie e trasportano frammenti di polline: peggiorano rinite e asma.',
    AirMetric.dust => 'Irrita occhi, naso e gola e si somma all\'effetto dei pollini.',
  };

  String advice(Level l) => switch (l) {
    Level.none || Level.low => 'Nessuna precauzione particolare.',
    Level.moderate => 'Se sei sensibile, tieni d\'occhio i sintomi.',
    Level.high =>
      this == AirMetric.ozone
          ? 'Evita sforzi all\'aperto tra mezzogiorno e il tardo pomeriggio, quando l\'ozono è più alto.'
          : 'Limita sforzi e lunghe permanenze all\'aperto.',
    Level.veryHigh =>
      'Resta il più possibile al chiuso, con le finestre chiuse nelle ore peggiori. Se hai l\'asma, segui il '
          'piano del tuo medico.',
  };
}

// --- Foglio ---
Future<void> showAirSheet(BuildContext context, AirMetric metric, double? value) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.palette.card,
  builder: (_) => AirSheet(metric: metric, value: value),
);

class AirSheet extends StatelessWidget {
  const AirSheet({super.key, required this.metric, required this.value});

  final AirMetric metric;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = value;
    final level = v == null ? null : metric.levelOf(v);
    final textTheme = Theme.of(context).textTheme;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(text, style: textTheme.titleMedium),
    );
    Widget body(String text) => Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: p.ink2));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(metric.title, style: textTheme.titleLarge),
            const SizedBox(height: 10),
            if (v == null || level == null)
              body('Nessun dato per oggi.')
            else
              Row(
                children: [
                  Text(
                    metric.levelLabel(level),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: p.text(level)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${metric.statLabel}: ${v.round()} ${AirMetric.unit}',
                      style: TextStyle(fontSize: 13, color: p.ink2),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            const SourceChip(DataKind.forecast, detail: 'Open-Meteo, CAMS Europa'),
            heading('Cos\'è'),
            body(metric.what),
            heading('Perché conta per chi ha allergie'),
            body(metric.why),
            if (level != null) ...[heading('Cosa fare oggi'), body(metric.advice(level))],
            heading('Scala (${AirMetric.unit})'),
            for (final (l, from, to) in metric.bands)
              _BandRow(metric: metric, level: l, from: from, to: to, on: l == level),
          ],
        ),
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({required this.metric, required this.level, required this.from, required this.to, required this.on});

  final AirMetric metric;
  final Level level;
  final double? from;
  final double? to;
  final bool on;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    String n(double x) => x.round().toString();
    final range = from == null ? 'meno di ${n(to!)}' : (to == null ? '${n(from!)} e oltre' : '${n(from!)}–${n(to!)}');
    final style = TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: p.ink);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: on ? p.chip : null, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: p.fill(level), shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(metric.levelLabel(level), style: style)),
          Text(range, style: style.copyWith(color: p.ink2)),
          SizedBox(
            width: 44,
            child: on
                ? Text(
                    'oggi',
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.text(level)),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
