import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  const bologna = Place(name: 'Bologna', lat: 44.49, lon: 11.34);

  test('Lecce: previsione per le graminacee, stima per la Parietaria', () async {
    final log = <Uri>[];
    final repo = repository(DateTime(2026, 9, 30, 10), log: log);
    final snap = repo.build(await repo.fetch(Place.lecce));

    final grass = snap[Allergens.grass.id]!;
    expect(grass.kind, DataKind.forecast);
    expect(grass.level, Level.none);
    expect(grass.series, hasLength(3));
    expect(grass.hourly, hasLength(25), reason: 'dalle 0 alle 24');
    expect(grass.hourly.last.date, DateTime(2026, 10, 1));

    final mugwort = snap[Allergens.mugwort.id]!;
    expect(mugwort.value, closeTo(7.0, 0.01));
    expect(mugwort.level, Level.moderate);

    final par = snap[Allergens.parietaria.id]!;
    expect(par.kind, DataKind.estimate);
    expect(par.level, Level.low);
    expect(par.value, isNull);

    expect(snap.area, Area.south);
    expect(snap.nearestStation!.station.name, 'Brindisi');
    expect(snap.measuringStation, isNull);
    expect(log.where((u) => u.host == 'sdi.isprambiente.it'), hasLength(1));

    expect(snap.air.ozoneMax, 91);
    expect(snap.air.dustMax, 3);
    expect(snap.air.pm25Mean, closeTo(8.57, 0.01));
  });

  test('vicino a una stazione attiva: Parietaria misurata', () async {
    final repo = repository(DateTime(2026, 9, 25, 10));
    final snap = repo.build(await repo.fetch(bologna));
    final par = snap[Allergens.parietaria.id]!;
    expect(par.kind, DataKind.measured);
    expect(par.value, 73);
    expect(par.level, Level.high);
    expect(par.date, DateTime(2026, 9, 20));
    expect(par.station!.station.name, 'Bologna');
    expect(par.series.map((d) => d.value), [8, 14, 10, 13, 48, 73]);
  });

  test('misura troppo vecchia: si torna alla stima', () async {
    final repo = repository(DateTime(2026, 10, 5, 10));
    final snap = repo.build(await repo.fetch(bologna));
    expect(snap[Allergens.parietaria.id]!.kind, DataKind.estimate);
    expect(snap[Allergens.parietaria.id]!.level, Level.low);
  });

  test('ISPRA giù: la previsione arriva lo stesso', () async {
    final repo = repository(DateTime(2026, 9, 25, 10), ispraDown: true);
    final snap = repo.build(await repo.fetch(bologna));
    expect(snap[Allergens.grass.id]!.kind, DataKind.forecast);
    expect(snap[Allergens.parietaria.id]!.kind, DataKind.estimate);
  });

  test('una stazione in errore non ferma le altre', () async {
    var calls = 0;
    final client = MockClient((req) async {
      if (req.url.host != 'sdi.isprambiente.it') return utf8Response(fixture('open_meteo_lecce.json'));
      calls++;
      return req.url.queryParameters['cql_filter']!.startsWith('STAT_ID=118 ')
          ? http.Response('errore', 500)
          : utf8Response(fixture('pollnet_bologna.csv'));
    });
    final repo = PollenRepository(
      openMeteo: OpenMeteoClient(client),
      pollnet: PollnetClient(client),
      stations: stationDirectory(),
      clock: () => DateTime(2026, 9, 25, 10),
    );
    final snap = repo.build(await repo.fetch(bologna));
    expect(calls, 3);
    expect(snap[Allergens.parietaria.id]!.kind, DataKind.measured);
    expect(snap.measuringStation!.station.id, isNot(118));
  });

  test('ogni allergene misurato prende la stazione più vicina con una sua misura recente', () async {
    const header =
        'FID,PART_SEQ,PART_LEVEL,PART_ID,PART_NAME_L,PART_PARENT_NAME_L,REMA_CONCENTRATION,REMA_DATE,STAT_ID,STAT_CODE,STAT_NAME_I';
    final client = MockClient((req) async {
      if (req.url.host != 'sdi.isprambiente.it') return utf8Response(fixture('open_meteo_lecce.json'));
      if (!req.url.queryParameters['cql_filter']!.startsWith('STAT_ID=118 ')) {
        return utf8Response(fixture('pollnet_bologna.csv'));
      }
      return utf8Response(
        '$header\n'
        'a,1,2,1362,Urticaceae,Urticaceae,40,2026-09-01,118,BO1,Bologna\n'
        'b,2,2,1330,Cupressaceae,Cupressaceae,12,2026-09-24,118,BO1,Bologna',
      );
    });
    final repo = PollenRepository(
      openMeteo: OpenMeteoClient(client),
      pollnet: PollnetClient(client),
      stations: stationDirectory(),
      clock: () => DateTime(2026, 9, 25, 10),
    );
    final snap = repo.build(RawPollenData.decode((await repo.fetch(bologna)).encode()));
    expect(snap[Allergens.cypress.id]!.station!.station.id, 118);
    final par = snap[Allergens.parietaria.id]!;
    expect(par.kind, DataKind.measured);
    expect(par.station!.station.id, isNot(118));
    expect(par.value, 73);
    expect(snap.measuringStation!.station.id, 118);
  });

  test('la cache del formato precedente si legge ancora', () {
    final raw = RawPollenData.decode(
      '{"place":{"name":"Bologna","region":null,"lat":44.49,"lon":11.34},"fetchedAt":"2026-09-25T10:00:00.000",'
      '"openMeteo":"{}","pollnetCsv":"x","stationId":118,"stationKm":1.5}',
    );
    expect(raw.measures.single.stationId, 118);
    expect(raw.measures.single.km, 1.5);
  });

  test('diario: solo previsioni del giorno e misure di oggi o di ieri, mai stime', () async {
    final lecce = repository(DateTime(2026, 9, 30, 10));
    final snap = lecce.build(await lecce.fetch(Place.lecce));
    final levels = snap.levelsOn(DateTime(2026, 9, 30));
    expect(levels.keys, contains(Allergens.grass.id));
    expect(levels.keys, isNot(contains(Allergens.parietaria.id)));

    final bo = repository(DateTime(2026, 9, 21, 10));
    final measured = bo.build(await bo.fetch(bologna));
    expect(measured.levelsOn(DateTime(2026, 9, 21))[Allergens.parietaria.id], Level.high.index);
    expect(measured.levelsOn(DateTime(2026, 9, 25)).keys, isNot(contains(Allergens.parietaria.id)));
  });

  test('la cache si ricostruisce identica', () async {
    final repo = repository(DateTime(2026, 9, 25, 10));
    final raw = await repo.fetch(bologna);
    final again = repo.build(RawPollenData.decode(raw.encode()));
    expect(again[Allergens.parietaria.id]!.value, 73);
    expect(again.place.name, 'Bologna');
  });
}
