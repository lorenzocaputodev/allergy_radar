import 'dart:convert';

import '../models/allergen.dart';
import '../models/level.dart';
import '../models/place.dart';
import '../models/pollen_snapshot.dart';
import '../models/station.dart';
import '../services/open_meteo_client.dart';
import '../services/pollnet_client.dart';

/// Risposte grezze delle fonti: sono loro a finire in cache, così l'app si ricostruisce offline.
class RawPollenData {
  const RawPollenData({
    required this.place,
    required this.fetchedAt,
    required this.openMeteo,
    this.pollnetCsv,
    this.stationId,
    this.stationKm,
  });

  final Place place;
  final DateTime fetchedAt;
  final String openMeteo;
  final String? pollnetCsv;
  final int? stationId;
  final double? stationKm;

  Map<String, dynamic> toJson() => {
    'place': place.toJson(),
    'fetchedAt': fetchedAt.toIso8601String(),
    'openMeteo': openMeteo,
    'pollnetCsv': pollnetCsv,
    'stationId': stationId,
    'stationKm': stationKm,
  };

  factory RawPollenData.fromJson(Map<String, dynamic> j) => RawPollenData(
    place: Place.fromJson(j['place'] as Map<String, dynamic>),
    fetchedAt: DateTime.parse(j['fetchedAt'] as String),
    openMeteo: j['openMeteo'] as String,
    pollnetCsv: j['pollnetCsv'] as String?,
    stationId: j['stationId'] as int?,
    stationKm: (j['stationKm'] as num?)?.toDouble(),
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

  /// Una misura più vecchia di così non descrive più la situazione attuale.
  /// ISPRA pubblica una settimana alla volta, con giorni di ritardo: con 10 giorni intere regioni restavano senza.
  static const maxMeasureAgeDays = 14;
  static const historyDays = 30;

  Future<RawPollenData> fetch(Place place) async {
    final now = _now();
    // Le due fonti sono indipendenti: si interrogano insieme.
    final (om, (csv, used)) = await (openMeteo.fetchForecast(place), _measures(place, now)).wait;
    return RawPollenData(
      place: place,
      fetchedAt: now,
      openMeteo: om,
      pollnetCsv: csv,
      stationId: used?.station.id,
      stationKm: used?.km,
    );
  }

  /// CSV della stazione più vicina con misure recenti, se c'è.
  Future<(String?, NearStation?)> _measures(Place place, DateTime now) async {
    final ids = Allergens.measuredOnly.map((a) => a.pollnetId);
    // La stazione più vicina può essere ferma: si prova la successiva, fino a tre.
    for (final near in stations.near(place).take(3)) {
      try {
        final body = await pollnet.fetchCsv(near.station.id, ids, now.subtract(const Duration(days: historyDays)), now);
        final recent = PollnetClient.parseCsv(body)
            .any((m) => m.value != null && now.difference(m.date).inDays <= maxMeasureAgeDays);
        if (recent) return (body, near);
      } on PollnetException {
        // Errore su una sola stazione: le altre possono rispondere.
        continue;
      } on Exception {
        // ISPRA non raggiungibile: si resta sulle stime, la previsione vale comunque.
        break;
      }
    }
    return (null, null);
  }

  PollenSnapshot build(RawPollenData raw) {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    final om = OpenMeteoData.parse(raw.openMeteo);
    final measures = raw.pollnetCsv == null ? const <Measurement>[] : PollnetClient.parseCsv(raw.pollnetCsv!);

    NearStation? station;
    if (raw.stationId != null) {
      final s = stations.stations.where((s) => s.id == raw.stationId).firstOrNull;
      if (s != null) station = NearStation(s, raw.stationKm ?? distanceKm(raw.place.lat, raw.place.lon, s.lat, s.lon));
    }

    final area = stations.areaOf(raw.place);
    final statuses = <String, AllergenStatus>{};
    for (final a in Allergens.all) {
      statuses[a.id] =
          (a.hasForecast ? _forecast(a, om, today) : _measured(a, measures, station, today)) ??
          _estimate(a, area, today);
    }

    return PollenSnapshot(
      place: raw.place,
      fetchedAt: raw.fetchedAt,
      statuses: statuses,
      air: _air(om, today),
      area: area,
      measuringStation: station,
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
    // Tutto oggi, fino alle 24: l'ultima ora è la mezzanotte di domani.
    final midnight = today.add(const Duration(days: 1));
    final hourly = <DayValue>[];
    for (var i = 0; i < om.times.length; i++) {
      final t = om.times[i];
      final v = om.valueAt(a.openMeteoKeys, i);
      if (v != null && (DateTime(t.year, t.month, t.day) == today || t == midnight)) hourly.add(_day(a, t, v));
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

  AllergenStatus? _measured(Allergen a, List<Measurement> all, NearStation? station, DateTime today) {
    if (station == null) return null;
    final valid = all.where((m) => m.partId == a.pollnetId && m.value != null).toList()
      ..sort((x, y) => x.date.compareTo(y.date));
    if (valid.isEmpty) return null;
    final last = valid.last;
    if (today.difference(last.date).inDays > maxMeasureAgeDays) return null;
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
        if (DateTime(om.times[i].year, om.times[i].month, om.times[i].day) == today && om.series[k]?[i] != null)
          om.series[k]![i]!,
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
