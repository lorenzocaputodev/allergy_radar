import 'dart:convert';
import 'dart:io';

import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/station.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String fixture(String name) => File('test/fixtures/$name').readAsStringSync();

StationDirectory stationDirectory() => StationDirectory.parse(File('assets/data/stations.json').readAsStringSync());

MockClient fakeHttp({bool ispraDown = false, List<Uri>? log}) => MockClient((req) async {
  log?.add(req.url);
  if (req.url.host == 'air-quality-api.open-meteo.com') {
    return utf8Response(fixture('open_meteo_lecce.json'));
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

PollenRepository repository(DateTime now, {bool ispraDown = false, List<Uri>? log}) {
  final client = fakeHttp(ispraDown: ispraDown, log: log);
  return PollenRepository(
    openMeteo: OpenMeteoClient(client),
    pollnet: PollnetClient(client),
    stations: stationDirectory(),
    clock: () => now,
  );
}
