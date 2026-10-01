import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';

enum AlertKind { briefing, tomorrow, diary }

class AlertMessage {
  const AlertMessage(this.kind, this.at, this.title, this.body);

  final AlertKind kind;
  final DateTime at;
  final String title;
  final String body;
}

/// Decide quali avvisi programmare: per ogni tipo attivo, la prossima occorrenza dopo `now`.
/// Nessun effetto collaterale: si testa da solo. Il testo usa i dati del giorno in cui l'avviso arriva.
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
    final tomorrow = today.add(const Duration(days: 1));
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
        final text = followed
            .map((s) {
              final estimate = s.kind == DataKind.estimate ? ' (stima)' : '';
              return '${s.allergen.name}: ${levels[s.allergen]!.label.toLowerCase()}$estimate';
            })
            .join('. ');
        final tail = over.isEmpty
            ? 'Niente che ti dia fastidio.'
            : 'Ti danno fastidio: ${over.map((s) => s.allergen.name).join(', ')}.';
        out.add(AlertMessage(AlertKind.briefing, when, 'Pollini di oggi a $placeName', '$text. $tail'));
      }
    }

    if (settings.tomorrow) {
      final when = next(settings.tomorrowAt);
      final target = dayOf(when).add(const Duration(days: 1));
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
            'Ti daranno fastidio: ${bothering.join(', ')}.',
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

  static DayValue? _dayValue(AllergenStatus s, DateTime day) => s.series.where((d) => d.date == day).firstOrNull;

  /// Previsione del giorno, se c'è; altrimenti il livello attuale (stima del mese o ultima misura).
  static Level _levelOn(AllergenStatus s, DateTime day) =>
      s.kind == DataKind.forecast ? (_dayValue(s, day)?.level ?? s.level) : s.level;
}
