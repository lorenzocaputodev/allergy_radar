import 'allergen.dart';
import 'level.dart';
import 'place.dart';
import 'station.dart';

class DayValue {
  const DayValue(this.date, this.value, this.level);

  final DateTime date;
  final double value;
  final Level level;
}

class AllergenStatus {
  const AllergenStatus({
    required this.allergen,
    required this.kind,
    required this.level,
    this.value,
    this.date,
    this.series = const [],
    this.hourly = const [],
    this.station,
  });

  final Allergen allergen;
  final DataKind kind;
  final Level level;

  /// granuli/m³: media del giorno (previsione) o misura del giorno (stazione). Null per le stime.
  final double? value;

  /// Giorno a cui si riferisce [value].
  final DateTime? date;

  /// Previsione: oggi e i giorni seguenti. Misura: storico, dal più vecchio.
  final List<DayValue> series;

  /// Solo previsione: valori orari di oggi, dalle 0 alle 24 (mezzanotte di domani).
  final List<DayValue> hourly;

  final NearStation? station;
}

class AirStatus {
  const AirStatus({this.ozoneMax, this.pm25Mean, this.dustMax});

  final double? ozoneMax;
  final double? pm25Mean;
  final double? dustMax;

  // Fasce ispirate all'indice europeo EAQI, adattate alla scala 0–4.
  static Level ozoneLevel(double v) => v < 100
      ? Level.low
      : v < 130
      ? Level.moderate
      : v < 240
      ? Level.high
      : Level.veryHigh;
  static Level pm25Level(double v) => v < 10
      ? Level.low
      : v < 25
      ? Level.moderate
      : v < 50
      ? Level.high
      : Level.veryHigh;
  static Level dustLevel(double v) => v < 20
      ? Level.none
      : v < 50
      ? Level.low
      : v < 100
      ? Level.moderate
      : v < 200
      ? Level.high
      : Level.veryHigh;
}

class PollenSnapshot {
  const PollenSnapshot({
    required this.place,
    required this.fetchedAt,
    required this.statuses,
    required this.air,
    required this.area,
    this.measuringStation,
    this.nearestStation,
  });

  final Place place;
  final DateTime fetchedAt;
  final Map<String, AllergenStatus> statuses;
  final AirStatus air;

  /// Area del calendario usata per le stime.
  final Area area;

  /// Stazione da cui arrivano le misure: entro il raggio e con dati recenti.
  final NearStation? measuringStation;

  /// Stazione più vicina entro il raggio, anche se non pubblica più.
  final NearStation? nearestStation;

  AllergenStatus? operator [](String id) => statuses[id];

  /// Livello (0–4) di ogni allergene, come lo salva il diario.
  Map<String, int> get levels => {for (final e in statuses.entries) e.key: e.value.level.index};
}
