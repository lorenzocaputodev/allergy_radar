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
    expect(par.level, Level.low); // settembre: media storica 9,4 granuli/m³
    expect(par.value, isNull);

    // Brindisi è entro 60 km ma non pubblica più: interrogata, poi scartata.
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
    expect(snap[Allergens.parietaria.id]!.level, Level.low); // ottobre: media storica 8,5 granuli/m³
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
      return ++calls == 1 ? http.Response('errore', 500) : utf8Response(fixture('pollnet_bologna.csv'));
    });
    final repo = PollenRepository(
      openMeteo: OpenMeteoClient(client),
      pollnet: PollnetClient(client),
      stations: stationDirectory(),
      clock: () => DateTime(2026, 9, 25, 10),
    );
    final snap = repo.build(await repo.fetch(bologna));
    expect(calls, 2);
    expect(snap[Allergens.parietaria.id]!.kind, DataKind.measured);
  });

  test('la cache si ricostruisce identica', () async {
    final repo = repository(DateTime(2026, 9, 25, 10));
    final raw = await repo.fetch(bologna);
    final again = repo.build(RawPollenData.decode(raw.encode()));
    expect(again[Allergens.parietaria.id]!.value, 73);
    expect(again.place.name, 'Bologna');
  });
}
