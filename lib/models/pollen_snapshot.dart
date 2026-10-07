import '../utils/days.dart';
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

  final double? value;

  final DateTime? date;

  final List<DayValue> series;

  final List<DayValue> hourly;

  final NearStation? station;

  Level? levelOn(DateTime day) => switch (kind) {
    DataKind.forecast => series.where((d) => d.date == day).firstOrNull?.level,
    DataKind.measured => date != null && day.daysSince(date!) <= 1 ? level : null,
    DataKind.estimate => null,
  };
}

class AirStatus {
  const AirStatus({this.ozoneMax, this.pm25Mean, this.dustMax});

  final double? ozoneMax;
  final double? pm25Mean;
  final double? dustMax;

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

  final Area area;

  final NearStation? measuringStation;

  final NearStation? nearestStation;

  AllergenStatus? operator [](String id) => statuses[id];

  Map<String, int> levelsOn(DateTime day) => {
    for (final e in statuses.entries)
      if (e.value.levelOn(day) case final l?) e.key: l.index,
  };
}
