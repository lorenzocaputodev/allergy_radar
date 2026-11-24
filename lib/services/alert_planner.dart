import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';
import '../models/weather.dart';
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

  static DateTime nextAt(DateTime now, int minutes) {
    final at = DateTime(now.year, now.month, now.day, minutes ~/ 60, minutes % 60);
    return at.isAfter(now) ? at : DateTime(now.year, now.month, now.day + 1, minutes ~/ 60, minutes % 60);
  }

  List<AlertMessage> schedule({
    required DateTime now,
    required AlertSettings settings,
    required String placeName,
    required List<AllergenStatus> followed,
    required Level Function(Allergen) thresholdOf,
    required bool diaryDoneToday,
    bool followingPlace = false,
    DateTime? placeFixedAt,
    HourlyWeather? weather,
  }) {
    final today = now.dateOnly;
    final tomorrow = today.plusDays(1);
    DateTime at(DateTime day, int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
    DateTime next(int minutes) => nextAt(now, minutes);
    bool above(Allergen a, Level l) => l != Level.none && l >= thresholdOf(a);
    String where(DateTime when) {
      if (!followingPlace) return '';
      if (placeFixedAt == null) return ' Luogo dell’ultima posizione nota.';
      if (when.difference(placeFixedAt) <= Place.followOldAfter) return '';
      return ' Luogo dell’ultima posizione letta, ${Fmt.moment(placeFixedAt, when)}.';
    }

    final out = <AlertMessage>[];

    if (settings.briefing && followed.isNotEmpty) {
      final when = next(settings.briefingAt);
      final levels = {for (final s in followed) s.allergen: _levelOn(s, when.dateOnly)};
      final current = followed.where((s) => s.isCurrent(when)).toList();
      final over = current.where((s) => above(s.allergen, levels[s.allergen]!)).toList();
      if (!settings.briefingOnlyAbove || over.isNotEmpty) {
        final rest = [
          for (final s in current)
            if (!over.contains(s)) levels[s.allergen]!,
        ];
        final lowest = over.fold(
          Level.veryHigh,
          (l, s) => levels[s.allergen]!.index < l.index ? levels[s.allergen]! : l,
        );
        final others = rest.isEmpty
            ? ''
            : rest.every((l) => l.index < lowest.index)
            ? ' Gli altri sono più bassi.'
            : ' Gli altri non sono da tenere d’occhio.';
        final body = over.isEmpty
            ? current.length < followed.length
                  ? 'Nessun allergene da tenere d’occhio tra quelli con dati recenti.'
                  : 'Nessun allergene da tenere d’occhio.'
            : '${Fmt.list([for (final s in over) _named(s, levels[s.allergen]!, when)])}.$others';
        final pollen = current.any((s) => levels[s.allergen] != Level.none);
        final sky = pollen ? weather?.hintAt(when, ahead: true) : null;
        out.add(
          AlertMessage(
            AlertKind.briefing,
            when,
            'Pollini di oggi a $placeName',
            '$body${sky == null ? '' : ' ${sky.text}.'}${where(when)}',
          ),
        );
      }
    }

    if (settings.tomorrow) {
      final when = next(settings.tomorrowAt);
      final target = when.dateOnly.plusDays(1);
      final bothering = <String>[];
      for (final s in followed.where((s) => s.kind == DataKind.forecast)) {
        final v = _dayValue(s, target);
        if (v != null && above(s.allergen, v.level)) {
          bothering.add('${s.allergen.at(v.level)} (${Fmt.grains(v.value)})');
        }
      }
      if (bothering.isNotEmpty) {
        final sky = weather?.hintOn(target);
        out.add(
          AlertMessage(
            AlertKind.tomorrow,
            when,
            'Domani a $placeName',
            '${Fmt.list(bothering)}.${sky == null ? '' : ' ${sky.text}.'}${where(when)}',
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
          'Bastano 10 secondi: col tempo scopri quali pollini ti danno fastidio.',
        ),
      );
    }
    return out;
  }

  static String _named(AllergenStatus s, Level level, DateTime now) {
    if (s.kind == DataKind.forecast) return s.allergen.at(level);
    return '${s.allergen.at(level)} (${Fmt.sourceOf(s, now: now)})';
  }

  static DayValue? _dayValue(AllergenStatus s, DateTime day) => s.series.where((d) => d.date == day).firstOrNull;

  static Level _levelOn(AllergenStatus s, DateTime day) =>
      s.kind == DataKind.forecast ? (_dayValue(s, day)?.level ?? s.level) : s.level;
}
