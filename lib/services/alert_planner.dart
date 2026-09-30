import '../models/alert_settings.dart';
import '../models/allergen.dart';
import '../models/level.dart';
import '../models/pollen_snapshot.dart';

enum AlertKind { briefing, tomorrow, diary }

class AlertMessage {
  const AlertMessage(this.kind, this.title, this.body);

  final AlertKind kind;
  final String title;
  final String body;
}

/// Decide quali avvisi mandare adesso. Nessun effetto collaterale: si testa da solo.
///
/// Il lavoro in background gira circa ogni ora; un avviso parte nella prima esecuzione
/// dopo il suo orario, entro [window], e al massimo una volta al giorno ([sentOn]).
class AlertPlanner {
  const AlertPlanner();

  static const window = Duration(hours: 3);

  List<AlertMessage> plan({
    required DateTime now,
    required AlertSettings settings,
    required String placeName,
    required List<AllergenStatus> followed,
    required Level Function(Allergen) thresholdOf,
    required bool diaryDoneToday,
    required Map<AlertKind, DateTime> sentOn,
  }) {
    final out = <AlertMessage>[];
    bool due(AlertKind k, bool enabled, int at) {
      if (!enabled) return false;
      final start = DateTime(now.year, now.month, now.day, at ~/ 60, at % 60);
      final last = sentOn[k];
      final sentToday = last != null && last.year == now.year && last.month == now.month && last.day == now.day;
      return !sentToday && !now.isBefore(start) && now.isBefore(start.add(window));
    }

    bool above(Allergen a, Level l) => l != Level.none && l >= thresholdOf(a);

    if (due(AlertKind.briefing, settings.briefing, settings.briefingAt) && followed.isNotEmpty) {
      final over = followed.where((s) => above(s.allergen, s.level)).toList();
      if (!settings.briefingOnlyAbove || over.isNotEmpty) {
        final levels = followed
            .map((s) {
              final estimate = s.kind == DataKind.estimate ? ' (media storica)' : '';
              return '${s.allergen.name}: ${s.level.label.toLowerCase()}$estimate';
            })
            .join('. ');
        final tail = over.isEmpty
            ? 'Nessun tuo allergene sopra soglia.'
            : 'Sopra la tua soglia: ${over.map((s) => s.allergen.name).join(', ')}.';
        out.add(AlertMessage(AlertKind.briefing, 'Pollini oggi a $placeName', '$levels. $tail'));
      }
    }

    if (due(AlertKind.tomorrow, settings.tomorrow, settings.tomorrowAt)) {
      final worse = <String>[];
      for (final s in followed.where((s) => s.kind == DataKind.forecast && s.series.length >= 2)) {
        final today = s.series[0];
        final next = s.series[1];
        if (next.level.index > today.level.index && above(s.allergen, next.level)) {
          worse.add(
            '${s.allergen.name}: da ${today.level.label.toLowerCase()} a ${next.level.label.toLowerCase()} '
            '(${next.value.round()} granuli/m³)',
          );
        }
      }
      if (worse.isNotEmpty) {
        out.add(AlertMessage(AlertKind.tomorrow, 'Domani peggiora a $placeName', '${worse.join('. ')}.'));
      }
    }

    if (due(AlertKind.diary, settings.diary, settings.diaryAt) && !diaryDoneToday) {
      out.add(
        const AlertMessage(
          AlertKind.diary,
          'Com’è andata oggi?',
          'Registra i sintomi in 10 secondi: servono a capire quali pollini ti danno fastidio.',
        ),
      );
    }
    return out;
  }
}
