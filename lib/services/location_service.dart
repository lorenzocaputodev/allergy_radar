import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Nome del comune e regione per delle coordinate; null se non si trova.
typedef ReverseGeocoder = Future<({String name, String? region})?> Function(double lat, double lon);

/// Posizione approssimativa del telefono e nome del comune dal Geocoder di Android.
class LocationService {
  static const fallbackName = 'La mia posizione';

  static Future<Place> current({ReverseGeocoder? reverse}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('La localizzazione del telefono è spenta.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw const LocationException('Permesso negato. Puoi sempre cercare una città.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Permesso negato: si riattiva dalle impostazioni di Android.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );
    return placeAt(pos.latitude, pos.longitude, reverse: reverse ?? androidGeocoder);
  }

  /// Luogo per delle coordinate: con il nome del comune se il geocoder lo trova, altrimenti generico.
  static Future<Place> placeAt(double lat, double lon, {required ReverseGeocoder reverse}) async {
    ({String name, String? region})? found;
    try {
      found = await reverse(lat, lon).timeout(const Duration(seconds: 10));
    } on Object {
      found = null;
    }
    return Place(name: found?.name ?? fallbackName, region: found?.region, lat: lat, lon: lon);
  }

  /// Geocoder di sistema: su Android usa il servizio del telefono, altrove non c'è.
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
