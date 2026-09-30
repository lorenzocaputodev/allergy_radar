import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/allergen.dart';
import '../models/place.dart';

/// Previsioni orarie di pollini e aria (modello CAMS Europa). Gratuito, senza chiave.
class OpenMeteoClient {
  OpenMeteoClient(this._http);

  final http.Client _http;

  static const airKeys = ['ozone', 'pm2_5', 'dust'];

  Uri forecastUri(Place p) => Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
        'latitude': p.roundedLat.toStringAsFixed(2),
        'longitude': p.roundedLon.toStringAsFixed(2),
        'hourly': [...Allergens.openMeteoKeys, ...airKeys].join(','),
        'timezone': 'Europe/Rome',
        'forecast_days': '5',
      });

  Future<String> fetchForecast(Place p) async {
    final res = await _http.get(forecastUri(p)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw OpenMeteoException('Open-Meteo ha risposto ${res.statusCode}');
    return utf8.decode(res.bodyBytes);
  }

  /// Ricerca città (geocoding Open-Meteo), limitata all'Italia.
  Future<List<Place>> searchPlaces(String query) async {
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': query,
      'count': '8',
      'language': 'it',
      'countryCode': 'IT',
    });
    final res = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw OpenMeteoException('Ricerca non riuscita (${res.statusCode})');
    final results = (jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>)['results'] as List? ?? const [];
    return [
      for (final r in results.cast<Map<String, dynamic>>())
        Place(
          name: r['name'] as String,
          region: r['admin1'] as String?,
          lat: (r['latitude'] as num).toDouble(),
          lon: (r['longitude'] as num).toDouble(),
        ),
    ];
  }
}

class OpenMeteoException implements Exception {
  OpenMeteoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Serie orarie già decodificate.
class OpenMeteoData {
  OpenMeteoData(this.times, this.series);

  factory OpenMeteoData.parse(String body) {
    final hourly = (jsonDecode(body) as Map<String, dynamic>)['hourly'] as Map<String, dynamic>;
    final times = (hourly['time'] as List).map((t) => DateTime.parse(t as String)).toList();
    final series = <String, List<double?>>{};
    for (final e in hourly.entries) {
      if (e.key == 'time') continue;
      series[e.key] = (e.value as List).map((v) => (v as num?)?.toDouble()).toList();
    }
    return OpenMeteoData(times, series);
  }

  final List<DateTime> times;
  final Map<String, List<double?>> series;

  /// Valore orario combinato: per più chiavi (betulla + ontano) prende il massimo.
  double? valueAt(List<String> keys, int i) {
    double? best;
    for (final k in keys) {
      final v = series[k]?[i];
      if (v != null && (best == null || v > best)) best = v;
    }
    return best;
  }

  /// Valori per giorno, in ordine. Un giorno conta se ha almeno [minHours] ore valide.
  Map<DateTime, List<double>> byDay(List<String> keys, {int minHours = 6}) {
    final out = <DateTime, List<double>>{};
    for (var i = 0; i < times.length; i++) {
      final v = valueAt(keys, i);
      if (v == null) continue;
      final t = times[i];
      out.putIfAbsent(DateTime(t.year, t.month, t.day), () => []).add(v);
    }
    out.removeWhere((_, v) => v.length < minHours);
    return out;
  }
}
