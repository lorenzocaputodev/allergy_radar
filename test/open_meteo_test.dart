import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

void main() {
  Future<int> calls(List<int> codes) async {
    var n = 0;
    final client = OpenMeteoClient(
      MockClient((_) async {
        final code = codes[n++ < codes.length ? n - 1 : codes.length - 1];
        return code == 200 ? utf8Response(fixture('open_meteo_lecce.json')) : http.Response('errore', code);
      }),
    );
    try {
      await client.fetchForecast(Place.lecce);
    } on OpenMeteoException {
      return -n;
    }
    return n;
  }

  test('errore del server: un nuovo tentativo, che può riuscire', () async {
    expect(await calls([503, 200]), 2);
    expect(await calls([500, 500]), -2);
  });

  test('richiesta rifiutata o troppe richieste: niente nuovo tentativo', () async {
    expect(await calls([400]), -1);
    expect(await calls([429]), -1);
  });
}
