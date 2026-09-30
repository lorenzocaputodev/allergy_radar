import '../models/allergen.dart';
import '../models/pollen_snapshot.dart';

abstract final class Fmt {
  static const _days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
  static const _short = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  static const _months = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];

  static String longDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';

  static String weekday(DateTime d, DateTime today) =>
      DateTime(d.year, d.month, d.day) == DateTime(today.year, today.month, today.day) ? 'Oggi' : _short[d.weekday - 1];

  static String time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String number(double v) {
    if (v >= 10 || v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String grains(double v) => '${number(v)} granuli/m³';

  static String month(int m) => _months[m - 1];

  static String sourceDetail(AllergenStatus s, DateTime today) => switch (s.kind) {
        DataKind.forecast => 'oggi',
        DataKind.measured =>
          '${s.station!.station.name}, ${s.station!.km.round()} km · ${s.date == null ? '' : shortDate(s.date!)}',
        DataKind.estimate => 'dal calendario',
      };
}
