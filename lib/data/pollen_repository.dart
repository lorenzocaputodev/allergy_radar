import 'dart:convert';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';
import '../models/station.dart';
import '../models/weather.dart';
import '../services/open_meteo_client.dart';
import '../services/pollnet_client.dart';
import '../utils/days.dart';

class StationCsv {
  const StationCsv(this.stationId, this.km, this.csv);

  final int stationId;
  final double km;
  final String csv;

  Map<String, dynamic> toJson() => {'id': stationId, 'km': km, 'csv': csv};

  factory StationCsv.fromJson(Map<String, dynamic> j) =>
      StationCsv(j['id'] as int, (j['km'] as num).toDouble(), j['csv'] as String);
}

class RawPollenData {
  const RawPollenData({
    required this.place,
    required this.fetchedAt,
    required this.openMeteo,
    this.weather,
    this.measures = const [],
    this.measuresAt,
  });

  final Place place;
  final DateTime fetchedAt;
  final String openMeteo;
  final String? weather;
  final List<StationCsv> measures;
  final DateTime? measuresAt;

  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'openMeteo': openMeteo,
    'weather': ?weather,
    'measures': [for (final m in measures) m.toJson()],
    'measuresAt': ?measuresAt?.toIso8601String(),
  };

  factory RawPollenData.fromJson(Map<String, dynamic> j) {
    final legacy = j['pollnetCsv'] as String?;
    return RawPollenData(
      place: Place.fromJson(j['place'] as Map<String, dynamic>),
      fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      openMeteo: j['openMeteo'] as String,
      weather: j['weather'] as String?,
      measuresAt: j['measuresAt'] == null ? null : DateTime.parse(j['measuresAt'] as String),
      measures: [
        for (final m in (j['measures'] as List? ?? const [])) StationCsv.fromJson(m as Map<String, dynamic>),
        if (legacy != null && j['stationId'] != null)
          StationCsv(j['stationId'] as int, (j['stationKm'] as num?)?.toDouble() ?? 0, legacy),
      ],
    );
  }

  RawPollenData withMeasures(List<StationCsv> measures, {DateTime? at}) => RawPollenData(
    place: place,
    fetchedAt: fetchedAt,
    openMeteo: openMeteo,
    weather: weather,
    measures: measures,
    measuresAt: at,
  );

  String encode() => jsonEncode(toJson());

  static RawPollenData decode(String s) => RawPollenData.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class PollenRepository {
  PollenRepository({required this.openMeteo, required this.pollnet, required this.stations, DateTime Function()? clock})
    : _now = clock ?? DateTime.now;

  final OpenMeteoClient openMeteo;
  final PollnetClient pollnet;
  final StationDirectory stations;
  final DateTime Function() _now;

  static const maxMeasureAgeDays = 14;
  static const historyDays = 30;
  static const measuresFreshFor = Duration(hours: 6);
  static const ispraPause = Duration(minutes: 30);

  DateTime? _ispraPausedUntil;

  Future<RawPollenData> fetchForecast(Place place) async {
    final now = _now();
    final (om, weather) = await (openMeteo.fetchForecast(place), _weather(place)).wait;
    return RawPollenData(place: place, fetchedAt: now, openMeteo: om, weather: weather);
  }

  Future<String?> _weather(Place place) async {
    try {
      return await openMeteo.fetchWeather(place);
    } on Exception {
      return null;
    }
  }

  Future<({List<StationCsv> measures, DateTime? at})> fetchMeasures(
    Place place,
    DateTime now, {
    RawPollenData? cached,
    bool force = false,
  }) async {
    final kept = cached?.measures ?? const <StationCsv>[];
    final keptAt = cached?.measuresAt;
    if (!force && keptAt != null && now.difference(keptAt).abs() < measuresFreshFor) {
      return (measures: kept, at: keptAt);
    }
    final near = stations.near(place).take(3).toList();
    if (near.isEmpty) return (measures: const <StationCsv>[], at: now);
    if (_ispraPausedUntil case final until? when !force && now.isBefore(until)) return (measures: kept, at: keptAt);
    final ids = Allergens.measuredOnly.map((a) => a.pollnetId);
    var answered = 0;
    Future<StationCsv?> recent(NearStation near) async {
      try {
        final body = await pollnet.fetchCsv(near.station.id, ids, now.plusDays(-historyDays), now);
        answered++;
        final ok = PollnetClient.parseCsv(body)
            .any((m) => m.value != null && now.daysSince(m.date) <= maxMeasureAgeDays);
        return ok ? StationCsv(near.station.id, near.km, body) : null;
      } on Exception {
        return kept.where((m) => m.stationId == near.station.id).firstOrNull;
      }
    }

    final found = await Future.wait(near.map(recent));
    _ispraPausedUntil = answered == 0 ? now.add(ispraPause) : null;
    return (measures: found.nonNulls.toList(), at: answered == near.length ? now : keptAt);
  }

  PollenSnapshot estimates(Place place) =>
      build(RawPollenData(place: place, fetchedAt: _now(), openMeteo: _noForecast), estimated: true);

  static const _noForecast = '{"hourly":{"time":[]}}';

  PollenSnapshot build(RawPollenData raw, {bool estimated = false}) {
    final now = _now();
    final today = now.dateOnly;
    final om = OpenMeteoData.parse(raw.openMeteo);
    final sources = [
      for (final m in raw.measures)
        if (stations.stations.where((s) => s.id == m.stationId).firstOrNull case final s?)
          (NearStation(s, m.km), PollnetClient.parseCsv(m.csv)),
    ];

    final area = stations.areaOf(raw.place);
    final statuses = <String, AllergenStatus>{};
    for (final a in Allergens.all) {
      statuses[a.id] =
          (a.hasForecast
              ? _forecast(a, om, today)
              : sources.map((src) => _measured(a, src.$2, src.$1, today)).nonNulls.firstOrNull) ??
          _estimate(a, area, today);
    }
    final used = statuses.values.map((s) => s.station).nonNulls.toList()..sort((x, y) => x.km.compareTo(y.km));

    return PollenSnapshot(
      place: raw.place,
      fetchedAt: raw.fetchedAt,
      statuses: statuses,
      air: _air(om, today),
      weather: _hourlyWeather(raw.weather),
      area: area,
      measuringStation: used.firstOrNull,
      nearestStation: stations.near(raw.place).firstOrNull,
      estimated: estimated,
    );
  }

  HourlyWeather? _hourlyWeather(String? body) {
    if (body == null) return null;
    try {
      final w = OpenMeteoData.parse(body);
      return HourlyWeather(w.times, w.series);
    } on Object {
      return null;
    }
  }

  AllergenStatus? _forecast(Allergen a, OpenMeteoData om, DateTime today) {
    final days = om.byDay(a.openMeteoKeys);
    final series = [
      for (final e in days.entries)
        if (!e.key.isBefore(today)) _day(a, e.key, e.value.reduce((x, y) => x + y) / e.value.length),
    ];
    if (series.isEmpty || series.first.date != today) return null;
    final midnight = today.plusDays(1);
    final hourly = <DayValue>[];
    for (var i = 0; i < om.times.length; i++) {
      final t = om.times[i];
      final v = om.valueAt(a.openMeteoKeys, i);
      if (v != null && (t.dateOnly == today || t == midnight)) hourly.add(_day(a, t, v));
    }
    final first = series.first;
    return AllergenStatus(
      allergen: a,
      kind: DataKind.forecast,
      level: first.level,
      value: first.value,
      date: first.date,
      series: series,
      hourly: hourly,
    );
  }

  AllergenStatus? _measured(Allergen a, List<Measurement> all, NearStation station, DateTime today) {
    final valid = all.where((m) => m.partId == a.pollnetId && m.value != null).toList()
      ..sort((x, y) => x.date.compareTo(y.date));
    if (valid.isEmpty) return null;
    final last = valid.last;
    if (today.daysSince(last.date) > maxMeasureAgeDays) return null;
    return AllergenStatus(
      allergen: a,
      kind: DataKind.measured,
      level: a.thresholds.levelOf(last.value!),
      value: last.value,
      date: last.date,
      series: [for (final m in valid) _day(a, m.date, m.value!)],
      station: station,
    );
  }

  AllergenStatus _estimate(Allergen a, Area area, DateTime today) => AllergenStatus(
    allergen: a,
    kind: DataKind.estimate,
    level: Level.fromIndex(a.calendarFor(area)[today.month - 1]),
    date: today,
  );

  AirStatus _air(OpenMeteoData om, DateTime today) {
    List<double> todayValues(String k) => [
      for (var i = 0; i < om.times.length; i++)
        if (om.times[i].dateOnly == today && om.series[k]?[i] != null) om.series[k]![i]!,
    ];
    double? maxOf(List<double> v) => v.isEmpty ? null : v.reduce((a, b) => a > b ? a : b);
    final pm = todayValues('pm2_5');
    return AirStatus(
      ozoneMax: maxOf(todayValues('ozone')),
      pm25Mean: pm.isEmpty ? null : pm.reduce((a, b) => a + b) / pm.length,
      dustMax: maxOf(todayValues('dust')),
    );
  }

  DayValue _day(Allergen a, DateTime d, double v) => DayValue(d, v, a.thresholds.levelOf(v));
}
