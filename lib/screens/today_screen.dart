import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../models/outdoor_plan.dart';
import '../models/pollen_snapshot.dart';
import '../models/weather.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../state/update_state.dart';
import '../theme/palette.dart';
import '../utils/days.dart';
import '../utils/format.dart';
import '../widgets/air_sheet.dart';
import '../widgets/allergen_card.dart';
import '../widgets/level_widgets.dart';
import '../widgets/outdoor_sheet.dart';
import '../widgets/update_card.dart';
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
    final above = s.aboveThreshold;
    final update = context.watch<UpdateState>().available;
    final now = clock.now();

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
                              Icon(s.followLocation ? Icons.near_me_outlined : Icons.place_outlined, color: p.ink),
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
              snap == null ? Fmt.longDate(now) : '${Fmt.longDate(now)} · ${Fmt.updated(snap.fetchedAt, now)}',
              style: TextStyle(fontSize: 14, color: p.ink3),
            ),
          ),
          if (s.error != null) _Banner(message: s.error!),
          if (update != null) UpdateCard(version: update),
          if (snap == null && s.loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (snap == null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: FilledButton.icon(
                  onPressed: s.refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ),
            )
          else ...[
            _Hero(state: s),
            const SizedBox(height: 14),
            const _SectionTitle('I tuoi allergeni'),
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
                  aboveThreshold: above.contains(st),
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
class _Hero extends StatefulWidget {
  const _Hero({required this.state});

  final AppState state;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  Timer? _tick;
  late final AppLifecycleListener _life;

  static String _names(List<String> names) => names.length > 3 ? '${names.length} allergeni' : Fmt.list(names);

  @override
  void initState() {
    super.initState();
    _life = AppLifecycleListener(onResume: () => setState(() {}));
    _arm();
  }

  void _arm() {
    final now = clock.now();
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    _tick = Timer(next.difference(now), () {
      if (!mounted) return;
      if (widget.state.onboarded && widget.state.isStale) unawaited(widget.state.refresh());
      setState(() {});
      _arm();
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final p = context.palette;
    final level = state.dayLevel;
    final above = state.aboveThreshold;
    final followed = state.followedStatuses;

    final summary = followed.isEmpty
        ? 'Scegli i tuoi allergeni da Profilo.'
        : above.isEmpty
        ? null
        : 'Sopra la tua soglia: ${Fmt.list([for (final s in above) s.allergen.name])}.';
    final estimated = [for (final s in followed.where((s) => s.kind == DataKind.estimate)) s.allergen.name];
    final now = clock.now();
    final weather = level == Level.none ? null : state.snapshot?.weather?.hintAt(now);
    final plan = OutdoorPlan.of(followed, now);

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
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    level.label,
                    style: TextStyle(
                      fontFamily: AppFonts.display,
                      fontSize: 44,
                      height: 1,
                      fontWeight: FontWeight.w600,
                      color: p.onHero,
                    ),
                  ),
                ),
                if (state.dayLevelSource case final kind? when kind != DataKind.forecast) ...[
                  const SizedBox(width: 10),
                  Text(
                    kind.label.toLowerCase(),
                    style: TextStyle(fontSize: 16, color: p.onHero.withValues(alpha: 0.85)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            RiskBar(level, track: p.heroTrack),
            for (final line in [
              if (summary != null) Text(summary),
              if (weather != null) _WeatherLine(weather),
              if (plan != null)
                _HeroLine(
                  Icons.schedule,
                  'Meglio uscire ${plan.goodText(' o ')}',
                  onTap: () => showOutdoorSheet(context, plan),
                ),
              if (estimated.isNotEmpty)
                Text(
                  'Stima: ${_names(estimated)}',
                  style: TextStyle(fontSize: 13, color: p.onHero.withValues(alpha: 0.85)),
                ),
            ]) ...[const SizedBox(height: 12), line],
          ],
        ),
      ),
    );
  }
}

class _WeatherLine extends StatelessWidget {
  const _WeatherLine(this.hint);

  final WeatherHint hint;

  @override
  Widget build(BuildContext context) {
    final h = hint.ongoing ? null : '${hint.at.hour}';
    final (icon, text) = switch (hint.event) {
      WeatherEvent.storm => (
        Icons.thunderstorm_outlined,
        '${h == null ? 'Temporale in corso' : 'Temporale verso le $h'}: attenzione se hai l’asma',
      ),
      WeatherEvent.rain => (Icons.water_drop_outlined, '${h == null ? 'Piove' : 'Pioggia dalle $h'}: pollini in calo'),
      WeatherEvent.wind => (Icons.air, 'Vento forte${h == null ? '' : ' dalle $h'}: più pollini in aria'),
    };
    return _HeroLine(icon, text);
  }
}

class _HeroLine extends StatelessWidget {
  const _HeroLine(this.icon, this.text, {this.onTap});

  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.palette.onHero;
    final row = Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600, color: color),
          ),
        ),
        if (onTap != null) Icon(Icons.chevron_right, size: 20, color: color.withValues(alpha: 0.7)),
      ],
    );
    if (onTap == null) return row;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row),
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
        : [for (var i = 0; i < 4; i++) today.plusDays(i)];

    String source(AllergenStatus s) => Fmt.sourceOf(s);

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
            final sourceStyle = TextStyle(fontSize: 12, color: p.ink3);
            final widest = [
              widestText(context, statuses.map((s) => s.allergen.name), _nameStyle),
              widestText(context, statuses.map(source), sourceStyle),
            ].reduce((a, b) => a > b ? a : b);
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
                              Text(source(s), style: sourceStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    Widget tile(AirMetric m) {
      final v = air.valueOf(m);
      final level = v == null ? null : m.levelOf(v);
      return Expanded(
        child: Material(
          color: p.chip,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => showAirSheet(context, m, v),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: p.ink3),
                        ),
                      ),
                      Icon(Icons.info_outline, size: 14, color: p.ink3),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    level == null ? '–' : m.levelLabel(level),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: level == null ? p.ink3 : p.text(level),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    v == null ? '' : '${v.floor()} ${AirMetric.unit}',
                    style: TextStyle(fontSize: 12, color: p.ink2),
                  ),
                ],
              ),
            ),
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
            Text(
              'Smog e sabbia possono peggiorare i sintomi. Tocca un riquadro per saperne di più.',
              style: TextStyle(fontSize: 13, color: p.ink3),
            ),
          ],
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              tile(AirMetric.ozone),
              const SizedBox(width: 8),
              tile(AirMetric.pm25),
              const SizedBox(width: 8),
              tile(AirMetric.dust),
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
                            _othersNote(s, context.read<AppState>().area, clock.now()),
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
  final source = Fmt.capital(Fmt.sourceOf(s));
  if (s.kind == DataKind.estimate) {
    return s.allergen.calendarFor(area)[today.month - 1] == 0 ? '$source: fuori stagione' : '$source (valore tipico)';
  }
  final value = s.value;
  return value == null ? source : '$source · ${Fmt.grains(value)}';
}

// --- Diario ---
class _DiaryCta extends StatelessWidget {
  const _DiaryCta();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = DiaryEntry.day(clock.now());
    final diary = context.watch<DiaryState>();
    final e = diary.entryFor(today);
    final yesterday = diary.entryFor(today.plusDays(-1));
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
                      e == null ? 'Come stai oggi?' : 'Diario di oggi registrato',
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
