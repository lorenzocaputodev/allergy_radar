import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/allergen_card.dart';
import '../widgets/level_widgets.dart';
import 'allergen_detail_screen.dart';
import 'place_search_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = context.palette;
    final snap = s.snapshot;
    final now = DateTime.now();

    void openDetail(AllergenStatus st) => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AllergenDetailScreen(allergenId: st.allergen.id)),
        );

    return RefreshIndicator(
      onRefresh: s.refresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 12, 0),
            child: Row(
              children: [
                Flexible(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PlaceSearchScreen()),
                    ),
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
                const SizedBox(width: 12),
                if (s.loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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
            const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
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
            const SizedBox(height: 4),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _Forecast(state: s, today: now)),
            const SizedBox(height: 14),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _Air(air: snap.air)),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF2B3430), borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              const Icon(Icons.wifi_off, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 14))),
            ],
          ),
        ),
      );
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final level = state.dayLevel;
    final above = state.aboveThreshold;
    final followed = state.followedStatuses;
    final below = followed.where((s) => !above.contains(s)).toList();

    String summary;
    if (followed.isEmpty) {
      summary = 'Scegli i tuoi allergeni da Profilo.';
    } else if (above.isEmpty) {
      summary = 'Nessun tuo allergene sopra soglia.';
    } else {
      final names = above.map((s) => s.allergen.name).join(' e ');
      summary = above.length == 1 ? '$names è sopra la tua soglia.' : '$names sono sopra la tua soglia.';
    }
    if (above.isNotEmpty && below.isNotEmpty) {
      summary += ' ${below.map((s) => '${s.allergen.name}: ${s.level.label.toLowerCase()}').join(', ')}.';
    }
    final estimated = above.any((s) => s.kind == DataKind.estimate);

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
              'LA TUA GIORNATA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.onHero.withValues(alpha: 0.85)),
            ),
            const SizedBox(height: 6),
            Text(
              level.label,
              style: TextStyle(fontFamily: AppFonts.display, fontSize: 44, height: 1, fontWeight: FontWeight.w600, color: p.onHero),
            ),
            const SizedBox(height: 14),
            RiskBar(level, track: p.heroTrack),
            const SizedBox(height: 14),
            Text(summary),
            if (estimated) ...[
              const SizedBox(height: 10),
              Text(
                'Parte del livello è una stima dal calendario: non ci sono stazioni di misura vicine.',
                style: TextStyle(fontSize: 13, color: p.onHero.withValues(alpha: 0.85)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Forecast extends StatelessWidget {
  const _Forecast({required this.state, required this.today});

  final AppState state;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final withForecast = state.followedStatuses.where((s) => s.kind == DataKind.forecast).toList();
    final without = state.followedStatuses.where((s) => s.kind != DataKind.forecast).toList();
    if (state.followedStatuses.isEmpty) return const SizedBox.shrink();
    final days = withForecast.isEmpty ? <DateTime>[] : withForecast.first.series.take(5).map((d) => d.date).toList();

    return SectionCard(
      children: [
        Row(
          children: [
            Expanded(child: Text('Prossimi giorni', style: Theme.of(context).textTheme.titleLarge)),
            Text('granuli/m³', style: TextStyle(fontSize: 12, color: p.ink3)),
          ],
        ),
        if (days.isNotEmpty)
          Row(
            children: [
              const SizedBox(width: 96),
              for (final d in days)
                Expanded(
                  child: Text(
                    Fmt.weekday(d, today),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: p.ink2, fontWeight: d == days.first ? FontWeight.w700 : FontWeight.w500),
                  ),
                ),
            ],
          ),
        for (final s in withForecast)
          Row(
            children: [
              SizedBox(width: 96, child: Text(s.allergen.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              for (final d in days)
                Expanded(child: _DayCell(value: s.series.where((x) => x.date == d).firstOrNull)),
            ],
          ),
        for (final s in without)
          Row(
            children: [
              SizedBox(width: 96, child: Text(s.allergen.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line, width: 1.5),
                  ),
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: s.kind == DataKind.measured ? 'Nessuna previsione. Ultima misura: ' : 'Nessuna previsione. Stima: '),
                      TextSpan(text: s.level.label, style: TextStyle(fontWeight: FontWeight.w700, color: p.text(s.level))),
                    ]),
                    style: TextStyle(fontSize: 13, color: p.ink2, height: 1.35),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.value});

  final DayValue? value;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = value;
    return Column(
      children: [
        Tooltip(
          message: v?.level.label ?? 'Nessun dato',
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: v == null ? p.track : p.fill(v.level), borderRadius: BorderRadius.circular(9)),
          ),
        ),
        const SizedBox(height: 4),
        Text(v == null ? '–' : Fmt.number(v.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink2)),
      ],
    );
  }
}

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
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: p.ink3)),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: level == null ? p.ink3 : p.text(level))),
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
            Text('Ozono, polveri fini e sabbia del Sahara peggiorano i sintomi da polline.', style: TextStyle(fontSize: 13, color: p.ink3)),
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

class _Others extends StatelessWidget {
  const _Others({required this.statuses, required this.onTap});

  final List<AllergenStatus> statuses;
  final void Function(AllergenStatus) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (statuses.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      gap: 4,
      children: [
        Text('Altri pollini in zona', style: Theme.of(context).textTheme.titleLarge),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Non li segui, ma sono nell’aria.', style: TextStyle(fontSize: 13, color: p.ink3)),
        ),
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
                        Text(s.allergen.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        Text(
                          _othersNote(s, DateTime.now()),
                          style: TextStyle(fontSize: 12, color: p.ink3),
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

String _othersNote(AllergenStatus s, DateTime today) {
  if (s.level == Level.none && s.allergen.calendar[today.month - 1] == 0) return 'Fuori stagione';
  if (s.value != null) return Fmt.grains(s.value!);
  return SourceChip.label(s.kind);
}
