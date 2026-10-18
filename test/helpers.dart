import 'dart:convert';
import 'dart:io';

import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/models/place_index.dart';
import 'package:allergy_radar/models/station.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

PlaceIndex placeIndex() => PlaceIndex.parse(File('assets/data/places.json').readAsStringSync());

StationDirectory stationDirectory() => StationDirectory.parse(File('assets/data/stations.json').readAsStringSync());

MockClient fakeHttp({bool ispraDown = false, bool openMeteoDown = false, List<Uri>? log}) => MockClient((req) async {
  log?.add(req.url);
  if (openMeteoDown && req.url.host.endsWith('open-meteo.com')) return http.Response('errore', 503);
  if (req.url.host == 'air-quality-api.open-meteo.com') {
    return utf8Response(fixture('open_meteo_lecce.json'));
  }
  if (req.url.host == 'api.open-meteo.com') {
    return utf8Response(fixture('weather_lecce.json'));
  }
  if (req.url.host == 'geocoding-api.open-meteo.com') {
    return utf8Response(fixture('geocoding_lecce.json'));
  }
  if (req.url.host == 'sdi.isprambiente.it') {
    if (ispraDown) return http.Response('errore', 503);
    final bologna = req.url.queryParameters['cql_filter']!.startsWith('STAT_ID=118 ');
    final csv = fixture('pollnet_bologna.csv');
    return utf8Response(bologna ? csv : csv.split('\n').first);
  }
  return http.Response('not found', 404);
});

http.Response utf8Response(String body) => http.Response.bytes(utf8.encode(body), 200);

extension StartUp on AppState {
  Future<void> init() async {
    await load();
    if (onboarded && isStale) await refresh();
  }
}

extension FullFetch on PollenRepository {
  Future<RawPollenData> fetch(Place place) async {
    final forecast = await fetchForecast(place);
    final m = await fetchMeasures(place, forecast.fetchedAt);
    return forecast.withMeasures(m.measures, at: m.at);
  }
}

PollenRepository repository(DateTime now, {bool ispraDown = false, bool openMeteoDown = false, List<Uri>? log}) {
  final client = fakeHttp(ispraDown: ispraDown, openMeteoDown: openMeteoDown, log: log);
  return PollenRepository(
    openMeteo: OpenMeteoClient(client),
    pollnet: PollnetClient(client),
    stations: stationDirectory(),
    clock: () => now,
  );
}
