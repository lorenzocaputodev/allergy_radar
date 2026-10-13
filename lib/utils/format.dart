import '../models/allergen.dart';
import '../models/pollen_snapshot.dart';
import 'days.dart';

abstract final class Fmt {
  static const _days = ['Lunedì', 'Martedì', 'Mercoledì', 'Giovedì', 'Venerdì', 'Sabato', 'Domenica'];
  static const _short = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
  static const _months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  static String longDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

  static String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1].substring(0, 3)}';

  static String weekday(DateTime d, DateTime today) => d.isSameDay(today) ? 'Oggi' : _short[d.weekday - 1];

  static String list(List<String> items) =>
      items.length < 2 ? items.join() : '${items.sublist(0, items.length - 1).join(', ')} e ${items.last}';

  static String time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String updated(DateTime at, DateTime now) {
    if (at.isSameDay(now)) return 'aggiornato alle ${time(at)}';
    if (at.isSameDay(now.plusDays(-1))) return 'aggiornato ieri alle ${time(at)}';
    return 'aggiornato il ${shortDate(at)} alle ${time(at)}';
  }

  static String number(double v) {
    final tenth = (v * 10).floor() / 10;
    if (v >= 10 || tenth == tenth.roundToDouble()) return v.floor().toString();
    return tenth.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String mean(double v) {
    final tenth = (v * 10).round() / 10;
    return tenth == tenth.roundToDouble() ? tenth.round().toString() : tenth.toStringAsFixed(1).replaceAll('.', ',');
  }

  static String grains(double v) => '${number(v)} granuli/m³';

  static String month(int m) => _months[m - 1];

  static String initial(int m) => _months[m - 1][0].toUpperCase();

  static String? sourceDetail(AllergenStatus s) => s.kind == DataKind.measured
      ? '${s.station!.station.name}, ${s.station!.km.round()} km · ${s.date == null ? '' : shortDate(s.date!)}'
      : null;
}
