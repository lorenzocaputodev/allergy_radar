import 'allergen.dart';
import 'level.dart';
import 'place.dart';
import 'station.dart';
import 'weather.dart';

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
    DataKind.forecast || DataKind.measured => series.where((d) => d.date == day).firstOrNull?.level,
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

  double? valueOf(AirMetric m) => switch (m) {
    AirMetric.ozone => ozoneMax,
    AirMetric.pm25 => pm25Mean,
    AirMetric.dust => dustMax,
  };
}

enum AirMetric {
  ozone('Ozono', 'Picco previsto oggi', [100, 130, 240], firstLevel: Level.low),
  pm25('Polveri fini', 'Media prevista oggi', [10, 25, 50], firstLevel: Level.low),
  dust('Sabbia', 'Picco previsto oggi', [20, 50, 100, 200], firstLevel: Level.none);

  const AirMetric(this.label, this.statLabel, this.limits, {required this.firstLevel});

  final String label;
  final String statLabel;
  final List<double> limits;
  final Level firstLevel;

  static const unit = 'µg/m³';

  Level levelOf(double v) => switch (this) {
    AirMetric.ozone => AirStatus.ozoneLevel(v),
    AirMetric.pm25 => AirStatus.pm25Level(v),
    AirMetric.dust => AirStatus.dustLevel(v),
  };

  String levelLabel(Level l) => this == AirMetric.dust && l == Level.none ? 'Assente' : l.label;

  List<(Level, double?, double?)> get bands => [
    for (var i = 0; i <= limits.length; i++)
      (Level.values[firstLevel.index + i], i == 0 ? null : limits[i - 1], i == limits.length ? null : limits[i]),
  ];
}

class PollenSnapshot {
  const PollenSnapshot({
    required this.place,
    required this.fetchedAt,
    required this.statuses,
    required this.air,
    required this.area,
    this.weather,
    this.measuringStation,
    this.nearestStation,
  });

  final Place place;
  final DateTime fetchedAt;
  final Map<String, AllergenStatus> statuses;
  final AirStatus air;
  final HourlyWeather? weather;

  final Area area;

  final NearStation? measuringStation;

  final NearStation? nearestStation;

  AllergenStatus? operator [](String id) => statuses[id];

  Map<String, int> levelsOn(DateTime day) => {
    for (final e in statuses.entries)
      if (e.value.levelOn(day) case final l?) e.key: l.index,
  };
}
