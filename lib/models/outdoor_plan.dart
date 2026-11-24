import 'level.dart';
import 'pollen_snapshot.dart';

typedef HourSpan = (int from, int to);

class OutdoorPlan {
  const OutdoorPlan({
    required this.allergens,
    required this.others,
    required this.levels,
    required this.nowHour,
    required this.peak,
    required this.good,
    required this.avoid,
    this.rough = const {},
  });

  static const firstHour = 7;
  static const lastHour = 21;
  static const minHours = 2;

  final List<String> allergens;
  final List<AllergenStatus> others;
  final Map<int, Level> levels;
  final int nowHour;
  final Level peak;
  final List<HourSpan> good;
  final HourSpan? avoid;
  final Set<int> rough;

  static OutdoorPlan? of(List<AllergenStatus> followed, DateTime now, {Set<int> rough = const {}}) {
    final hourly = followed.where((s) => s.hourly.isNotEmpty).toList();
    if (hourly.isEmpty) return null;
    final others = [
      for (final s in followed)
        if (s.hourly.isEmpty && s.level != Level.none) s,
    ];
    final floor = others.fold(Level.none, (l, s) => l.max(s.level));

    final levels = <int, Level>{};
    for (final s in hourly) {
      for (final h in s.hourly) {
        final d = h.date;
        if (d.year != now.year || d.month != now.month || d.day != now.day) continue;
        if (d.hour < firstHour || d.hour > lastHour) continue;
        levels[d.hour] = (levels[d.hour] ?? Level.none).max(h.level);
      }
    }
    final ahead = [
      for (var h = now.hour.clamp(firstHour, lastHour + 1); h <= lastHour; h++)
        if (levels[h] case final l?) (h, l.max(floor)),
    ];
    if (ahead.length < minHours) return null;
    final peak = ahead.fold(Level.none, (l, e) => l.max(e.$2));
    if (peak.index < Level.moderate.index) return null;

    final calm = ahead.where((e) => !rough.contains(e.$1));
    if (calm.isEmpty) return null;
    final best = calm.fold(peak, (l, e) => e.$2.index < l.index ? e.$2 : l);
    if (best == peak) return null;
    final good = _runs(
      ahead,
      (h, l) => l == best && !rough.contains(h),
    ).where((r) => r.$2 - r.$1 + 1 >= minHours).take(2).toList();
    if (good.isEmpty) return null;
    return OutdoorPlan(
      allergens: [for (final s in hourly) s.allergen.name],
      others: others,
      levels: levels,
      nowHour: now.hour,
      peak: peak,
      good: good,
      avoid: _runs(ahead, (h, l) => l == peak).firstOrNull,
      rough: {
        for (final h in rough)
          if (h >= firstHour && h <= lastHour) h,
      },
    );
  }

  static List<HourSpan> _runs(List<(int, Level)> hours, bool Function(int, Level) hit) {
    final out = <HourSpan>[];
    HourSpan? run;
    for (final (h, l) in hours) {
      if (hit(h, l) && run != null && h == run.$2 + 1) {
        run = (run.$1, h);
        continue;
      }
      if (run != null) out.add(run);
      run = hit(h, l) ? (h, h) : null;
    }
    if (run != null) out.add(run);
    return out;
  }

  String goodSpan(HourSpan s) {
    final (from, to) = s;
    if (from <= nowHour) return 'prima delle ${to + 1}';
    if (to >= lastHour) return 'dopo le $from';
    return 'tra le $from e le ${to + 1}';
  }

  String avoidSpan(HourSpan s) {
    final (from, to) = s;
    if (from <= nowHour) return 'fino alle ${to + 1}';
    if (to >= lastHour) return 'dalle $from in poi';
    return 'dalle $from alle ${to + 1}';
  }

  String goodText(String joiner) => good.map(goodSpan).join(joiner);
}
