import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';

import '../models/place.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef ReverseGeocoder = Future<({String name, String? region})?> Function(double lat, double lon);

class LocationService {
  static const fallbackName = 'La mia posizione';

  static Future<Place> current({ReverseGeocoder? reverse, bool ask = true}) async {
    final pos = await position(ask: ask);
    return placeAt(pos.lat, pos.lon, reverse: reverse ?? androidGeocoder);
  }

  static const _channel = MethodChannel('dev.lorenzocaputo.allergyradar/location');

  static Future<({double lat, double lon})> position({bool ask = true}) async {
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
    final pos = await _channel.invokeMapMethod<String, double>('current');
    if (pos == null) throw const LocationException('Posizione non disponibile. Cerca una città.');
    return (lat: pos['lat']!, lon: pos['lon']!);
  }

  static Future<Place> placeAt(double lat, double lon, {required ReverseGeocoder reverse}) async {
    ({String name, String? region})? found;
    try {
      found = await reverse(lat, lon).timeout(const Duration(seconds: 10));
    } on Object {
      found = null;
    }
    return Place(name: found?.name ?? fallbackName, region: found?.region, lat: lat, lon: lon);
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
}
