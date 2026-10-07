import 'dart:convert';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';
import '../models/station.dart';
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
    this.measures = const [],
  });

  final Place place;
  final DateTime fetchedAt;
  final String openMeteo;
  final List<StationCsv> measures;

  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'openMeteo': openMeteo,
    'measures': [for (final m in measures) m.toJson()],
  };

  factory RawPollenData.fromJson(Map<String, dynamic> j) {
    final legacy = j['pollnetCsv'] as String?;
    return RawPollenData(
      place: Place.fromJson(j['place'] as Map<String, dynamic>),
      fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      openMeteo: j['openMeteo'] as String,
      measures: [
        for (final m in (j['measures'] as List? ?? const [])) StationCsv.fromJson(m as Map<String, dynamic>),
        if (legacy != null && j['stationId'] != null)
          StationCsv(j['stationId'] as int, (j['stationKm'] as num?)?.toDouble() ?? 0, legacy),
      ],
    );
  }

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

  Future<RawPollenData> fetch(Place place) async {
    final now = _now();
    final (om, measures) = await (openMeteo.fetchForecast(place), _measures(place, now)).wait;
    return RawPollenData(place: place, fetchedAt: now, openMeteo: om, measures: measures);
  }

  Future<List<StationCsv>> _measures(Place place, DateTime now) async {
    final ids = Allergens.measuredOnly.map((a) => a.pollnetId);
    Future<StationCsv?> recent(NearStation near) async {
      try {
        final body = await pollnet.fetchCsv(near.station.id, ids, now.plusDays(-historyDays), now);
        final ok = PollnetClient.parseCsv(body)
            .any((m) => m.value != null && now.daysSince(m.date) <= maxMeasureAgeDays);
        return ok ? StationCsv(near.station.id, near.km, body) : null;
      } on Exception {
        return null;
      }
    }

    final found = await Future.wait(stations.near(place).take(3).map(recent));
    return found.nonNulls.toList();
  }

  PollenSnapshot build(RawPollenData raw) {
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
      area: area,
      measuringStation: used.firstOrNull,
      nearestStation: stations.near(raw.place).firstOrNull,
    );
  }

  AllergenStatus? _forecast(Allergen a, OpenMeteoData om, DateTime today) {
    final days = om.byDay(a.openMeteoKeys);
    final series = [
      for (final e in days.entries)
        if (!e.key.isBefore(today)) _day(a, e.key, e.value.reduce((x, y) => x + y) / e.value.length),
    ];
    if (series.isEmpty) return null;
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
