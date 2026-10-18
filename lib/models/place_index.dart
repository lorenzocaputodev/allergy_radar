import 'dart:convert';

import 'place.dart';

class PlaceIndex {
  PlaceIndex(this.places);

  factory PlaceIndex.parse(String json) {
    final data = jsonDecode(json) as Map<String, dynamic>;
    final regions = (data['regions'] as List).cast<String>();
    return PlaceIndex([
      for (final r in (data['places'] as List).cast<List<dynamic>>())
        Place(
          name: r[0] as String,
          region: regions[r[1] as int],
          lat: (r[2] as num).toDouble(),
          lon: (r[3] as num).toDouble(),
        ),
    ]);
  }

  final List<Place> places;
  late final List<String> _keys = [for (final p in places) normalize(p.name)];
  late final List<String> _compact = [for (final k in _keys) k.replaceAll(' ', '')];

  static const nearKm = 25.0;

  static const _plain = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ä': 'a',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
    'ñ': 'n',
  };

  static String normalize(String s) {
    final out = StringBuffer();
    var space = true;
    for (final c in s.toLowerCase().split('')) {
      final plain = _plain[c] ?? c;
      final unit = plain.codeUnitAt(0);
      if ((unit >= 0x61 && unit <= 0x7a) || (unit >= 0x30 && unit <= 0x39)) {
        out.write(plain);
        space = false;
      } else if (!space) {
        out.write(' ');
        space = true;
      }
    }
    return out.toString().trimRight();
  }

  List<Place> search(String query, {int limit = 8}) {
    final q = normalize(query);
    if (q.length < 2) return const [];
    final compact = q.replaceAll(' ', '');
    final exact = <Place>[];
    final prefix = <Place>[];
    final word = <Place>[];
    for (var i = 0; i < places.length; i++) {
      final k = _keys[i];
      if (k == q) {
        exact.add(places[i]);
      } else if (k.startsWith(q) || _compact[i].startsWith(compact)) {
        prefix.add(places[i]);
      } else if (k.contains(' $q')) {
        word.add(places[i]);
      }
    }
    return [...exact, ...prefix, ...word].take(limit).toList();
  }

  Place? nearest(double lat, double lon, {double maxKm = nearKm}) {
    Place? best;
    var bestKm = maxKm;
    for (final p in places) {
      if ((p.lat - lat).abs() > 0.3 || (p.lon - lon).abs() > 0.4) continue;
      final km = distanceKm(lat, lon, p.lat, p.lon);
      if (km <= bestKm) {
        best = p;
        bestKm = km;
      }
    }
    return best;
  }
}
