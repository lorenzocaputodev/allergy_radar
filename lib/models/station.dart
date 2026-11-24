import 'dart:convert';

import 'area.dart';
import 'place.dart';

class Station {
  const Station({
    required this.id,
    required this.code,
    required this.name,
    required this.region,
    required this.lat,
    required this.lon,
  });

  final int id;
  final String code;
  final String name;
  final String region;
  final double lat;
  final double lon;

  factory Station.fromJson(Map<String, dynamic> j) => Station(
    id: j['id'] as int,
    code: j['code'] as String,
    name: j['name'] as String,
    region: j['region'] as String,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
  );

  Area get area => Area.ofRegion(region);
}

class NearStation {
  const NearStation(this.station, this.km);

  final Station station;
  final double km;
}

class StationDirectory {
  StationDirectory(this.stations);

  factory StationDirectory.parse(String json) =>
      StationDirectory((jsonDecode(json) as List).map((e) => Station.fromJson(e as Map<String, dynamic>)).toList());

  final List<Station> stations;

  static const maxKm = 60.0;

  Area areaOf(Place p) => near(p, maxKm: double.infinity).firstOrNull?.station.area ?? Area.south;

  (double, double)? _sortedFor;
  List<NearStation> _sorted = const [];

  List<NearStation> near(Place p, {double maxKm = maxKm}) {
    if (_sortedFor != (p.lat, p.lon)) {
      _sorted = [for (final s in stations) NearStation(s, distanceKm(p.lat, p.lon, s.lat, s.lon))]
        ..sort((a, b) => a.km.compareTo(b.km));
      _sortedFor = (p.lat, p.lon);
    }
    return _sorted.where((n) => n.km <= maxKm).toList();
  }
}
