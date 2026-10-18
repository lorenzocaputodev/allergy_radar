import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import '../models/place.dart';
import '../models/place_index.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef ReverseGeocoder = Future<({String name, String? region})?> Function(double lat, double lon);
typedef ForwardGeocoder = Future<List<({double lat, double lon})>> Function(String query);

class LocationService {
  static const fallbackName = 'La mia posizione';

  static const recentFix = Duration(minutes: 10);
  static const quickWait = Duration(seconds: 4);
  static const nameTimeout = Duration(seconds: 2);
  static const lateNameTimeout = Duration(seconds: 10);

  static Future<Place> current({
    ReverseGeocoder? reverse,
    PlaceIndex? index,
    bool ask = true,
    void Function(Place)? renamed,
  }) async {
    final pos = await position(ask: ask, recent: recentFix);
    return placeAt(pos.lat, pos.lon, reverse: reverse ?? androidGeocoder, index: index, renamed: renamed);
  }

  static const _channel = MethodChannel('dev.lorenzocaputo.allergyradar/location');

  static Future<({double lat, double lon})> position({bool ask = true, Duration? recent}) async {
    if (kIsWeb || !Platform.isAndroid) {
      throw const LocationException('Posizione non disponibile. Cerca una città.');
    }
    if (await _channel.invokeMethod<bool>('enabled') != true) {
      throw const LocationException('La localizzazione del telefono è spenta.');
    }
    final permission = await _channel.invokeMethod<String>('permission', {'ask': ask});
    if (permission == 'deniedForever') {
      throw const LocationException('Permesso negato: si riattiva dalle impostazioni di Android.');
    }
    if (permission != 'granted') {
      throw const LocationException('Permesso negato. Puoi sempre cercare una città.');
    }
    final fresh = _channel.invokeMapMethod<String, double>('current');
    final quick = recent == null
        ? null
        : await _channel.invokeMapMethod<String, double>('lastKnown', {'maxAgeMs': recent.inMilliseconds});
    Map<String, double>? pos;
    if (quick == null) {
      pos = await fresh;
    } else {
      try {
        pos = await fresh.timeout(quickWait, onTimeout: () => quick) ?? quick;
      } on Object {
        pos = quick;
      }
      fresh.ignore();
    }
    if (pos == null) throw const LocationException('Posizione non disponibile. Cerca una città.');
    return (lat: pos['lat']!, lon: pos['lon']!);
  }

  static Future<Place> placeAt(
    double lat,
    double lon, {
    required ReverseGeocoder reverse,
    PlaceIndex? index,
    void Function(Place)? renamed,
  }) async {
    Place named(({String name, String? region}) f) => Place(name: f.name, region: f.region, lat: lat, lon: lon);
    final lookup = Future(() => reverse(lat, lon));
    ({String name, String? region})? found;
    try {
      found = await lookup.timeout(nameTimeout);
    } on Object {
      found = null;
    }
    if (found != null) return named(found);
    if (renamed != null) {
      unawaited(
        lookup.timeout(lateNameTimeout).then((f) {
          if (f != null) renamed(named(f));
        }, onError: (_) {}),
      );
    }
    final near = index?.nearest(lat, lon);
    return Place(name: near?.name ?? fallbackName, region: near?.region, lat: lat, lon: lon);
  }

  static Future<({String name, String? region})?> androidGeocoder(double lat, double lon) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final marks = await Geocoding().placemarkFromCoordinates(lat, lon, locale: const Locale('it'));
    for (final m in marks) {
      final name = [
        m.locality,
        m.subAdministrativeArea,
      ].firstWhere((s) => s != null && s.trim().isNotEmpty, orElse: () => null);
      if (name != null) return (name: name.trim(), region: m.administrativeArea);
    }
    return null;
  }

  static Future<List<({double lat, double lon})>> androidSearch(String query) async {
    if (kIsWeb || !Platform.isAndroid) return const [];
    final found = await Geocoding().locationFromAddress('$query, Italia', locale: const Locale('it'));
    return [for (final l in found) (lat: l.latitude, lon: l.longitude)];
  }

  static Future<List<Place>> searchByGeocoder(String query, PlaceIndex index, {ForwardGeocoder? forward}) async {
    final found = await (forward ?? androidSearch)(query).timeout(nameTimeout * 3);
    final out = <Place>[];
    for (final pos in found) {
      if (index.nearest(pos.lat, pos.lon) case final near?) {
        out.add(Place(name: near.name, region: near.region, lat: pos.lat, lon: pos.lon));
      }
    }
    return out;
  }
}
