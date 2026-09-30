import 'dart:math' as math;

class Place {
  const Place({required this.name, required this.lat, required this.lon, this.region});

  final String name;
  final String? region;
  final double lat;
  final double lon;

  static const lecce = Place(name: 'Lecce', region: 'Puglia', lat: 40.3515, lon: 18.1750);

  /// Coordinate arrotondate a 0,01° (~1 km): l'unica cosa che esce dal telefono.
  double get roundedLat => (lat * 100).round() / 100;
  double get roundedLon => (lon * 100).round() / 100;

  Map<String, dynamic> toJson() => {'name': name, 'region': region, 'lat': lat, 'lon': lon};

  factory Place.fromJson(Map<String, dynamic> j) => Place(
    name: j['name'] as String,
    region: j['region'] as String?,
    lat: (j['lat'] as num).toDouble(),
    lon: (j['lon'] as num).toDouble(),
  );

  String get cacheKey => '${roundedLat.toStringAsFixed(2)},${roundedLon.toStringAsFixed(2)}';
}

/// Distanza in km (formula dell'emisenoverso).
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a =
      math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}
