import 'dart:async';

import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// Il primo download resta in attesa finché il test non lo lascia andare.
class _SlowRepository extends PollenRepository {
  _SlowRepository(DateTime now)
    : super(
        openMeteo: OpenMeteoClient(fakeHttp()),
        pollnet: PollnetClient(fakeHttp()),
        stations: stationDirectory(),
        clock: () => now,
      );

  final gate = Completer<void>();
  final asked = <String>[];

  @override
  Future<RawPollenData> fetch(Place place) async {
    asked.add(place.name);
    if (asked.length == 1) await gate.future;
    return super.fetch(place);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const bologna = Place(name: 'Bologna', lat: 44.49, lon: 11.34);

  test('cambiare luogo durante un aggiornamento scarica il luogo nuovo', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final repo = _SlowRepository(DateTime(2026, 9, 25, 10));
    final state = AppState(repo, await SharedPreferences.getInstance());
    await state.load();

    final first = state.refresh();
    final change = state.setPlace(bologna);
    repo.gate.complete();
    await first;
    await change;

    expect(repo.asked, ['Lecce', 'Bologna']);
    expect(state.snapshot!.place.name, 'Bologna');
    expect(state.loading, isFalse);
  });
}
