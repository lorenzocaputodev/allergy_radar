import 'dart:convert';

import 'place.dart';

/// Stazione della rete POLLnet.
class Station {
  const Station({required this.id, required this.code, required this.name, required this.region, required this.lat, required this.lon});

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

  Map<String, dynamic> toJson() => {'id': id, 'code': code, 'name': name, 'region': region, 'lat': lat, 'lon': lon};
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

  /// Oltre questa distanza il polline misurato non rappresenta più la zona.
  static const maxKm = 60.0;

  /// Stazioni entro [maxKm], dalla più vicina.
  List<NearStation> near(Place p, {double maxKm = maxKm}) {
    final list = [
      for (final s in stations) NearStation(s, distanceKm(p.lat, p.lon, s.lat, s.lon)),
    ]..sort((a, b) => a.km.compareTo(b.km));
    return list.where((n) => n.km <= maxKm).toList();
  }
}
