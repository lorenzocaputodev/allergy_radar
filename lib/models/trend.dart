import '../utils/days.dart';
import 'diary_entry.dart';
import 'level.dart';

enum TrendStep { day, week, month }

class TrendBucket {
  const TrendBucket({required this.from, required this.to, required this.entries, required this.allergenId});

  final DateTime from;
  final DateTime to;
  final List<DiaryEntry> entries;
  final String allergenId;

  static TrendStep stepFor(int period) => switch (period) {
    <= 30 => TrendStep.day,
    <= 90 => TrendStep.week,
    _ => TrendStep.month,
  };

  static List<TrendBucket> build({
    required List<DiaryEntry> entries,
    required String allergenId,
    required int period,
    required DateTime today,
  }) {
    final end = today.dateOnly;
    final List<(DateTime, DateTime)> spans = switch (stepFor(period)) {
      TrendStep.day => [for (var i = period - 1; i >= 0; i--) (end.plusDays(-i), end.plusDays(-i))],
      TrendStep.week => [
        for (var w = (period / 7).ceil() - 1; w >= 0; w--) (end.plusDays(-7 * w - 6), end.plusDays(-7 * w)),
      ],
      TrendStep.month => [
        for (var m = 11; m >= 0; m--)
          (DateTime(end.year, end.month - m), m == 0 ? end : DateTime(end.year, end.month - m + 1).plusDays(-1)),
      ],
    };
    return [
      for (final (from, to) in spans)
        TrendBucket(
          from: from,
          to: to,
          allergenId: allergenId,
          entries: [
            for (final e in entries)
              if (!e.date.isBefore(from) && !e.date.isAfter(to)) e,
          ],
        ),
    ];
  }

  int get logged => entries.length;

  Level? get pollen {
    Level? top;
    for (final e in entries) {
      if (e.pollen[allergenId] case final l?) top = (top ?? Level.none).max(Level.fromIndex(l));
    }
    return top;
  }

  double? get symptoms => entries.isEmpty ? null : entries.map((e) => e.severity).reduce((a, b) => a + b) / logged;
}
