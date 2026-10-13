import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/models/weather.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  final day = DateTime(2026, 5, 10);
  final times = [for (var h = 0; h < 24; h++) day.add(Duration(hours: h))];
  Map<String, List<double?>> series({
    Map<int, double> rain = const {},
    Map<int, double> code = const {},
    Map<int, double> wind = const {},
  }) => {
    'precipitation': [for (var h = 0; h < 24; h++) rain[h] ?? 0],
    'weather_code': [for (var h = 0; h < 24; h++) code[h] ?? 1],
    'wind_speed_10m': [for (var h = 0; h < 24; h++) wind[h] ?? 5],
  };
  WeatherHint? at(int hour, Map<String, List<double?>> s) =>
      WeatherHint.of(times, s, day.add(Duration(hours: hour, minutes: 20)));

  test('tempo tranquillo: nessuna riga', () {
    expect(at(9, series()), isNull);
  });

  test('pioggia nel pomeriggio: il dato delle 15 è la pioggia tra le 14 e le 15', () {
    final h = at(9, series(rain: {15: 2, 16: 4}))!;
    expect(h.event, WeatherEvent.rain);
    expect(h.at.hour, 14);
    expect(h.ongoing, isFalse);
  });

  test('pioggia già passata o sotto 1 mm: ignorata', () {
    expect(at(12, series(rain: {8: 5, 14: 0.4})), isNull);
  });

  test('pioggia in corso e pioggia appena finita', () {
    expect(at(15, series(rain: {16: 2}))!.ongoing, isTrue);
    expect(at(15, series(rain: {15: 2})), isNull);
  });

  test('vince l’evento più vicino; a parità d’ora il temporale, poi la pioggia', () {
    final h = at(9, series(rain: {12: 3}, wind: {13: 40}, code: {17: 95}))!;
    expect(h.event, WeatherEvent.rain);
    expect(h.at.hour, 11);
    expect(at(9, series(rain: {12: 3}, wind: {11: 40}))!.event, WeatherEvent.rain);
    expect(at(9, series(rain: {12: 3}, code: {11: 95}))!.event, WeatherEvent.storm);
    expect(at(9, series(rain: {20: 3}, code: {17: 95}))!.event, WeatherEvent.storm);
  });

  test('vento forte senza pioggia', () {
    expect(at(9, series(wind: {13: 35}))!.event, WeatherEvent.wind);
  });

  test('dopo le 21 non si avvisa più', () {
    expect(at(10, series(rain: {23: 6}, wind: {22: 50})), isNull);
  });

  test('il repository legge il meteo e regge se manca', () async {
    final repo = repository(DateTime(2026, 9, 30, 10));
    final snap = repo.build(await repo.fetch(Place.lecce));
    final hint = snap.weather!.hintAt(DateTime(2026, 9, 30, 10))!;
    expect(hint.event, WeatherEvent.rain);
    expect(hint.at.hour, 14);
    expect(snap.weather!.hintAt(DateTime(2026, 9, 30, 15, 40))!.ongoing, isTrue);
    expect(snap.weather!.hintAt(DateTime(2026, 9, 30, 17)), isNull);
    final raw = await repo.fetch(Place.lecce);
    final noWeather = repo.build(RawPollenData(place: raw.place, fetchedAt: raw.fetchedAt, openMeteo: raw.openMeteo));
    expect(noWeather.weather, isNull);
  });
}
