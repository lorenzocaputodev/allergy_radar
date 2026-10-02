import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/allergen_card.dart';
import '../widgets/level_widgets.dart';
import 'allergen_detail_screen.dart';
import 'log_entry_screen.dart';
import 'notifications_screen.dart';
import 'place_search_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.palette;
    final snap = s.snapshot;
    final now = DateTime.now();

    void openDetail(AllergenStatus st) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => AllergenDetailScreen(allergenId: st.allergen.id)));

    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => const PlaceSearchScreen())),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.place_outlined, color: p.ink),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  s.place.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                              ),
                              Icon(Icons.expand_more, color: p.ink),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (s.loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                IconButton(
                  tooltip: 'Avvisi ricevuti',
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen())),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(
              snap == null ? Fmt.longDate(now) : '${Fmt.longDate(now)} · aggiornato alle ${Fmt.time(snap.fetchedAt)}',
              style: TextStyle(fontSize: 14, color: p.ink3),
            ),
          ),
          if (s.error != null) _Banner(message: s.error!),
          if (snap == null && s.error == null)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (snap != null) ...[
            _Hero(state: s),
            const SizedBox(height: 14),
            _SectionTitle('I tuoi allergeni'),
            if (s.followedStatuses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text('Non segui nessun allergene. Sceglili da Profilo.', style: TextStyle(color: p.ink2)),
              ),
            for (final st in s.followedStatuses)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: AllergenCard(
                  status: st,
                  today: now,
                  aboveThreshold: s.aboveThreshold.contains(st),
                  onTap: () => openDetail(st),
                ),
              ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 14), child: _DiaryCta()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Forecast(state: s, today: now),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Air(air: snap.air),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _Others(statuses: s.otherStatuses, onTap: openDetail),
            ),
          ],
        ],
      ),
    );
  }
}

// --- Elementi comuni ---
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(Icons.wifi_off, color: p.bg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: TextStyle(color: p.bg, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Riquadro del giorno ---
class _Hero extends StatelessWidget {
  const _Hero({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final level = state.dayLevel;
    final above = state.aboveThreshold;
    final followed = state.followedStatuses;

    String summary;
    if (followed.isEmpty) {
      summary = 'Scegli i tuoi allergeni da Profilo.';
    } else if (above.isEmpty) {
      summary = 'Oggi nessuno dei tuoi allergeni è al livello che ti dà fastidio.';
    } else {
      summary = 'Al livello che ti dà fastidio: ${Fmt.list([for (final s in above) s.allergen.name])}.';
    }
    final estimated = followed.where((s) => s.kind == DataKind.estimate).map((s) => s.allergen);
    final noMeasure = [for (final a in estimated.where((a) => !a.hasForecast)) a.name];
    final noForecast = [for (final a in estimated.where((a) => a.hasForecast)) a.name];
    final noStation = state.snapshot?.nearestStation == null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: p.hero, borderRadius: BorderRadius.circular(24)),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: p.onHero, fontSize: 16, height: 1.45),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OGGI PER TE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: p.onHero.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              level.label,
              style: TextStyle(
                fontFamily: AppFonts.display,
                fontSize: 44,
                height: 1,
                fontWeight: FontWeight.w600,
                color: p.onHero,
              ),
            ),
            const SizedBox(height: 14),
            RiskBar(level, track: p.heroTrack),
            const SizedBox(height: 14),
            Text(summary),
            for (final note in [
              if (noMeasure.isNotEmpty)
                noStation
                    ? 'Stima per ${Fmt.list(noMeasure)}: non ci sono stazioni di misura vicine.'
                    : 'Stima per ${Fmt.list(noMeasure)}: nessuna misura recente dalle stazioni vicine.',
              if (noForecast.isNotEmpty) 'Stima per ${Fmt.list(noForecast)}: la previsione non è disponibile.',
            ]) ...[
              const SizedBox(height: 10),
              Text(note, style: TextStyle(fontSize: 13, color: p.onHero.withValues(alpha: 0.85))),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Prossimi giorni ---
class _Forecast extends StatelessWidget {
  const _Forecast({required this.state, required this.today});

  final AppState state;
  final DateTime today;

  static const _nameStyle = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final statuses = [
      ...state.followedStatuses.where((s) => s.kind == DataKind.forecast),
      ...state.followedStatuses.where((s) => s.kind != DataKind.forecast),
    ];
    if (statuses.isEmpty) return const SizedBox.shrink();
    final forecast = statuses.first.kind == DataKind.forecast ? statuses.first : null;
    final days = forecast != null
        ? forecast.series.take(5).map((d) => d.date).toList()
        : [for (var i = 0; i < 4; i++) today.add(Duration(days: i))];

    String source(AllergenStatus s) => switch (s.kind) {
      DataKind.forecast => 'previsione',
      DataKind.measured => 'misura del ${s.date!.day}/${s.date!.month}',
      DataKind.estimate => 'stima',
    };

    _DayCell cell(AllergenStatus s, DateTime d) {
      switch (s.kind) {
        case DataKind.forecast:
          final v = s.series.where((x) => x.date == d).firstOrNull;
          return _DayCell(level: v?.level, label: v == null ? '–' : Fmt.number(v.value));
        case DataKind.measured:
          return d == days.first ? _DayCell(level: s.level, label: Fmt.number(s.value!)) : const _DayCell(label: '–');
        case DataKind.estimate:
          return _DayCell(level: s.level);
      }
    }

    return SectionCard(
      children: [
        Row(
          children: [
            Expanded(child: Text('Prossimi giorni', style: Theme.of(context).textTheme.titleLarge)),
            Text('granuli/m³', style: TextStyle(fontSize: 12, color: p.ink3)),
          ],
        ),
        LayoutBuilder(
          builder: (context, c) {
            final widest = widestText(context, statuses.map((s) => s.allergen.name), _nameStyle);
            final nameWidth = (widest + 12).clamp(0, c.maxWidth * 0.42).toDouble();
            return Column(
              children: [
                Row(
                  children: [
                    SizedBox(width: nameWidth),
                    for (final d in days)
                      Expanded(
                        child: Text(
                          Fmt.weekday(d, today),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.ink2,
                            fontWeight: d == days.first ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final s in statuses)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: nameWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.allergen.name, style: _nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(
                                source(s),
                                style: TextStyle(fontSize: 12, color: p.ink3),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        for (final d in days) Expanded(child: cell(s, d)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        if (statuses.any((s) => s.kind == DataKind.estimate))
          Text('Stima: valore tipico del mese, uguale ogni giorno.', style: TextStyle(fontSize: 12, color: p.ink3)),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({this.level, this.label = ''});

  final Level? level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final l = level;
    return Column(
      children: [
        Tooltip(
          message: l?.label ?? 'Nessun dato',
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: l == null ? p.track : p.fill(l),
              borderRadius: BorderRadius.circular(8),
              border: l == null || l == Level.none
                  ? Border.all(color: p.ink3.withValues(alpha: 0.35), width: 1.5)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, height: 1.2, fontWeight: FontWeight.w600, color: p.ink2),
        ),
      ],
    );
  }
}

// --- Aria ---
class _Air extends StatelessWidget {
  const _Air({required this.air});

  final AirStatus air;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tile(String name, double? v, String unit, Level Function(double) lv, {bool dust = false}) {
      final level = v == null ? null : lv(v);
      final label = level == null ? '–' : (dust && level == Level.none ? 'Assente' : level.label);
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.ink3),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: level == null ? p.ink3 : p.text(level),
                ),
              ),
              const SizedBox(height: 6),
              Text(v == null ? '' : '${v.round()} $unit', style: TextStyle(fontSize: 12, color: p.ink2)),
            ],
          ),
        ),
      );
    }

    return SectionCard(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aria', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 2),
            Text('Smog e polvere possono peggiorare i sintomi.', style: TextStyle(fontSize: 13, color: p.ink3)),
          ],
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile('Ozono', air.ozoneMax, 'µg/m³', AirStatus.ozoneLevel),
              const SizedBox(width: 8),
              tile('PM2.5', air.pm25Mean, 'µg/m³', AirStatus.pm25Level),
              const SizedBox(width: 8),
              tile('Polvere', air.dustMax, 'µg/m³', AirStatus.dustLevel, dust: true),
            ],
          ),
        ),
      ],
    );
  }
}

// --- Altri pollini ---
class _Others extends StatefulWidget {
  const _Others({required this.statuses, required this.onTap});

  final List<AllergenStatus> statuses;
  final void Function(AllergenStatus) onTap;

  @override
  State<_Others> createState() => _OthersState();
}

class _OthersState extends State<_Others> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final statuses = widget.statuses;
    final onTap = widget.onTap;
    if (statuses.isEmpty) return const SizedBox.shrink();
    final notable = statuses.where((s) => s.level >= Level.moderate).length;
    return SectionCard(
      gap: 4,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Altri pollini in zona', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Text(
                          notable == 0
                              ? '${statuses.length} pollini, tutti bassi o assenti'
                              : '${statuses.length} pollini, $notable sopra il livello basso',
                          style: TextStyle(fontSize: 13, color: p.ink3),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, color: p.ink2),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_open) const SizedBox(height: 4),
        if (_open)
          for (final s in statuses)
            InkWell(
              onTap: () => onTap(s),
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Row(
                  children: [
                    AllergenGlyph(s.allergen, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.allergen.name,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _othersNote(s, context.read<AppState>().area, DateTime.now()),
                            style: TextStyle(fontSize: 12, color: p.ink3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    LevelPill(s.level, small: true),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

String _othersNote(AllergenStatus s, Area area, DateTime today) {
  if (s.level == Level.none && s.allergen.calendarFor(area)[today.month - 1] == 0) return 'Fuori stagione';
  if (s.value != null) return Fmt.grains(s.value!);
  return s.kind == DataKind.estimate ? 'Stima (valore tipico)' : SourceChip.label(s.kind);
}

// --- Diario ---
class _DiaryCta extends StatelessWidget {
  const _DiaryCta();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = DiaryEntry.day(DateTime.now());
    final diary = context.watch<DiaryState>();
    final e = diary.entryFor(today);
    final yesterday = diary.entryFor(today.subtract(const Duration(days: 1)));
    final sub = e != null
        ? '${DiaryEntry.symptomNames[e.severity]} · tocca per modificare'
        : yesterday != null
        ? 'Registra i sintomi in 10 secondi · ieri: ${DiaryEntry.symptomNames[yesterday.severity].toLowerCase()}'
        : 'Registra i sintomi in 10 secondi';
    return Material(
      color: p.pineSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () =>
            Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: today), fullscreenDialog: true)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: p.pine, shape: BoxShape.circle),
                child: Icon(e == null ? Icons.add : Icons.check, color: p.onPine),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e == null ? 'Come stai oggi?' : 'Diario di oggi fatto',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(sub, style: TextStyle(fontSize: 13, color: p.ink2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: p.ink2),
            ],
          ),
        ),
      ),
    );
  }
}
