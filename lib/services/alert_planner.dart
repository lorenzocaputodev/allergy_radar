import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';
import '../utils/days.dart';
import '../utils/format.dart';

enum AlertKind { briefing, tomorrow, diary }

class AlertMessage {
  const AlertMessage(this.kind, this.at, this.title, this.body);

  final AlertKind kind;
  final DateTime at;
  final String title;
  final String body;
}

class AlertPlanner {
  const AlertPlanner();

  List<AlertMessage> schedule({
    required DateTime now,
    required AlertSettings settings,
    required String placeName,
    required List<AllergenStatus> followed,
    required Level Function(Allergen) thresholdOf,
    required bool diaryDoneToday,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.plusDays(1);
    DateTime at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    DateTime next(int minutes) => at(today, minutes).isAfter(now) ? at(today, minutes) : at(tomorrow, minutes);
    DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);
    bool above(Allergen a, Level l) => l != Level.none && l >= thresholdOf(a);

    final out = <AlertMessage>[];

    if (settings.briefing && followed.isNotEmpty) {
      final when = next(settings.briefingAt);
      final levels = {for (final s in followed) s.allergen: _levelOn(s, dayOf(when))};
      final over = followed.where((s) => above(s.allergen, levels[s.allergen]!)).toList();
      if (!settings.briefingOnlyAbove || over.isNotEmpty) {
        final others = over.length < followed.length ? ' Gli altri sono più bassi.' : '';
        final body = over.isEmpty
            ? 'Oggi nessuno dei tuoi allergeni è al livello che ti dà fastidio.'
            : 'Al livello che ti dà fastidio: ${Fmt.list([for (final s in over) _named(s)])}.$others';
        out.add(AlertMessage(AlertKind.briefing, when, 'Pollini di oggi a $placeName', body));
      }
    }

    if (settings.tomorrow) {
      final when = next(settings.tomorrowAt);
      final target = dayOf(when).plusDays(1);
      final bothering = <String>[];
      for (final s in followed.where((s) => s.kind == DataKind.forecast)) {
        final v = _dayValue(s, target);
        if (v != null && above(s.allergen, v.level)) {
          bothering.add('${s.allergen.name} ${v.level.label.toLowerCase()} (${v.value.round()} granuli/m³)');
        }
      }
      if (bothering.isNotEmpty) {
        out.add(
          AlertMessage(
            AlertKind.tomorrow,
            when,
            'Domani a $placeName',
            'Al livello che ti dà fastidio: ${Fmt.list(bothering)}.',
          ),
        );
      }
    }

    if (settings.diary) {
      final todayAt = at(today, settings.diaryAt);
      out.add(
        AlertMessage(
          AlertKind.diary,
          todayAt.isAfter(now) && !diaryDoneToday ? todayAt : at(tomorrow, settings.diaryAt),
          'Com’è andata oggi?',
          'Registra i sintomi in 10 secondi: servono a capire quali pollini ti danno fastidio.',
        ),
      );
    }
    return out;
  }

  static String _named(AllergenStatus s) => switch (s.kind) {
    DataKind.forecast => s.allergen.name,
    DataKind.measured => '${s.allergen.name} (misura${s.date == null ? '' : ' del ${Fmt.shortDate(s.date!)}'})',
    DataKind.estimate => '${s.allergen.name} (stima)',
  };

  static DayValue? _dayValue(AllergenStatus s, DateTime day) => s.series.where((d) => d.date == day).firstOrNull;

  static Level _levelOn(AllergenStatus s, DateTime day) =>
      s.kind == DataKind.forecast ? (_dayValue(s, day)?.level ?? s.level) : s.level;
}
