import 'level.dart';
import 'pollen_snapshot.dart';

typedef HourSpan = (int from, int to);

class OutdoorPlan {
  const OutdoorPlan({
    required this.allergens,
    required this.levels,
    required this.nowHour,
    required this.good,
    required this.avoid,
  });

  static const firstHour = 7;
  static const lastHour = 21;
  static const minHours = 2;

  final List<String> allergens;
  final Map<int, Level> levels;
  final int nowHour;
  final List<HourSpan> good;
  final HourSpan? avoid;

  static OutdoorPlan? of(List<AllergenStatus> followed, DateTime now) {
    final hourly = followed.where((s) => s.hourly.isNotEmpty).toList();
    if (hourly.isEmpty) return null;
    final floor = followed.where((s) => s.hourly.isEmpty).fold(Level.none, (l, s) => l.max(s.level));

    final levels = <int, Level>{};
    for (final s in hourly) {
      for (final h in s.hourly) {
        final d = h.date;
        if (d.year != now.year || d.month != now.month || d.day != now.day) continue;
        if (d.hour < firstHour || d.hour > lastHour) continue;
        levels[d.hour] = (levels[d.hour] ?? floor).max(h.level);
      }
    }
    final ahead = [
      for (var h = now.hour.clamp(firstHour, lastHour + 1); h <= lastHour; h++)
        if (levels[h] case final l?) (h, l),
    ];
    if (ahead.length < minHours) return null;
    final peak = ahead.fold(Level.none, (l, e) => l.max(e.$2));
    if (peak.index < Level.moderate.index) return null;

    final best = ahead.fold(peak, (l, e) => e.$2.index < l.index ? e.$2 : l);
    if (best == peak) return null;
    final good = _runs(ahead, (l) => l == best).where((r) => r.$2 - r.$1 + 1 >= minHours).take(2).toList();
    if (good.isEmpty) return null;
    return OutdoorPlan(
      allergens: [for (final s in hourly) s.allergen.name],
      levels: levels,
      nowHour: now.hour,
      good: good,
      avoid: _runs(ahead, (l) => l == peak).firstOrNull,
    );
  }

  static List<HourSpan> _runs(List<(int, Level)> hours, bool Function(Level) hit) {
    final out = <HourSpan>[];
    HourSpan? run;
    for (final (h, l) in hours) {
      if (hit(l) && run != null && h == run.$2 + 1) {
        run = (run.$1, h);
        continue;
      }
      if (run != null) out.add(run);
      run = hit(l) ? (h, h) : null;
    }
    if (run != null) out.add(run);
    return out;
  }

  String span(HourSpan s) {
    final (from, to) = s;
    if (from <= nowHour) return 'prima delle ${to + 1}';
    if (to >= lastHour) return 'dopo le $from';
    return 'tra le $from e le ${to + 1}';
  }

  String get goodText => good.map(span).join(' o ');
}
