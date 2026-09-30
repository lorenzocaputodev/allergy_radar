import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  group('Thresholds', () {
    const t = Thresholds(2, 20, 70); // Urticacee

    test('classi POLLnet ai bordi', () {
      expect(t.levelOf(1.9), Level.none);
      expect(t.levelOf(2), Level.low);
      expect(t.levelOf(19.9), Level.low);
      expect(t.levelOf(20), Level.moderate);
      expect(t.levelOf(70), Level.high);
      expect(t.levelOf(209), Level.high);
      expect(t.levelOf(210), Level.veryHigh);
    });

    test('ordine dei livelli', () {
      expect(Level.high >= Level.moderate, isTrue);
      expect(Level.low >= Level.moderate, isFalse);
      expect(Level.low.max(Level.high), Level.high);
    });
  });

  group('Open-Meteo', () {
    final data = OpenMeteoData.parse(fixture('open_meteo_lecce.json'));

    test('decodifica le serie orarie', () {
      expect(data.times, hasLength(96));
      expect(data.times.first, DateTime(2026, 9, 30));
      expect(data.series.keys, containsAll(['grass_pollen', 'mugwort_pollen', 'ozone']));
    });

    test('scarta i giorni con troppe ore mancanti', () {
      final days = data.byDay(Allergens.grass.openMeteoKeys);
      expect(days.keys, [DateTime(2026, 9, 30), DateTime(2026, 10, 1), DateTime(2026, 10, 2)]);
    });

    test('più chiavi: prende il massimo ora per ora', () {
      for (var i = 0; i < 24; i++) {
        final b = data.series['birch_pollen']![i] ?? 0;
        final a = data.series['alder_pollen']![i] ?? 0;
        expect(data.valueAt(['birch_pollen', 'alder_pollen'], i), b > a ? b : a);
      }
    });

    test('invia solo coordinate arrotondate', () {
      final uri = OpenMeteoClient(fakeHttp()).forecastUri(const Place(name: 'x', lat: 40.35158, lon: 18.17497));
      expect(uri.queryParameters['latitude'], '40.35');
      expect(uri.queryParameters['longitude'], '18.17');
    });
  });

  group('POLLnet', () {
    test('legge il CSV di ISPRA', () {
      final m = PollnetClient.parseCsv(fixture('pollnet_bologna.csv'));
      expect(m, hasLength(12));
      final urti = m.where((x) => x.partId == Allergens.parietaria.pollnetId).toList();
      expect(urti.last.date, DateTime(2026, 9, 20));
      expect(urti.last.value, 73);
    });

    test('valori mancanti restano null', () {
      final m = PollnetClient.parseCsv('FID,PART_ID,REMA_CONCENTRATION,REMA_DATE\nx,1362,,2026-09-01\n');
      expect(m.single.value, isNull);
    });

    test('campi tra virgolette', () {
      expect(PollnetClient.splitCsvLine('a,"b, c",d'), ['a', 'b, c', 'd']);
      expect(PollnetClient.splitCsvLine('"x ""y"""'), ['x "y"']);
    });

    test('filtro CQL con date e codici', () {
      final uri = PollnetClient(fakeHttp())
          .concentrationsUri(118, [1362, 1330], DateTime(2026, 9, 1), DateTime(2026, 9, 30));
      expect(
        uri.queryParameters['cql_filter'],
        "STAT_ID=118 and PART_ID IN (1362,1330) and REMA_DATE between '2026-09-01' and '2026-09-30'",
      );
      expect(uri.queryParameters['outputFormat'], 'csv');
    });
  });

  group('Stazioni', () {
    final dir = stationDirectory();

    test('Lecce: solo Brindisi entro 60 km', () {
      final near = dir.near(Place.lecce);
      expect(near.map((n) => n.station.name), ['Brindisi']);
      expect(near.single.km, closeTo(38, 2));
    });

    test('area del calendario dalla stazione più vicina', () {
      expect(dir.areaOf(Place.lecce), Area.south);
      expect(dir.areaOf(const Place(name: 'Milano', lat: 45.46, lon: 9.19)), Area.north);
      expect(dir.areaOf(const Place(name: 'Roma', lat: 41.9, lon: 12.5)), Area.centre);
      expect(dir.areaOf(const Place(name: 'Cagliari', lat: 39.22, lon: 9.12)), Area.south);
      expect(dir.stations.where((s) => s.region == 'ISPRA'), isEmpty, reason: 'niente stazione di test');
    });

    test('Bologna: la prima è Bologna', () {
      final near = dir.near(const Place(name: 'Bologna', lat: 44.49, lon: 11.34));
      expect(near.first.station.name, 'Bologna');
      expect(near.first.km, lessThan(10));
    });
  });
}
