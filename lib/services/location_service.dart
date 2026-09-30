import 'package:geolocator/geolocator.dart';

import '../models/place.dart';

class LocationException implements Exception {
  const LocationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Posizione approssimativa del telefono: basta la zona, non l'indirizzo.
class LocationService {
  static Future<Place> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException('La localizzazione del telefono è spenta.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      throw const LocationException('Permesso di posizione negato. Puoi sempre cercare una città.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException('Permesso di posizione negato: si riattiva dalle impostazioni di Android.');
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 20)),
    );
    return Place(name: 'La mia posizione', lat: pos.latitude, lon: pos.longitude);
  }
}
