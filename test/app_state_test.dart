import 'dart:async';

import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:allergy_radar/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

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

  test('il tema del widget è scuro di base, e si salva', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(_SlowRepository(DateTime(2026, 9, 25, 10)), prefs);
    await state.load();
    expect(state.widgetDark, isTrue);

    await state.setWidgetDark(false);
    expect(prefs.getString(AppState.kWidgetTheme), 'light');
    final again = AppState(_SlowRepository(DateTime(2026, 9, 25, 10)), prefs);
    await again.load();
    expect(again.widgetDark, isFalse);
    expect(AppState.backupKeys, contains(AppState.kWidgetTheme));
  });

  test('al ritorno nell’app si usa la cache più recente scritta dal background', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final app = AppState(repository(DateTime(2026, 9, 30, 8)), prefs);
    await app.load();
    await app.refresh();
    expect(app.snapshot!.fetchedAt, DateTime(2026, 9, 30, 8));

    final background = AppState(repository(DateTime(2026, 9, 30, 11)), prefs);
    await background.load();
    await background.refresh();
    await app.syncCache();
    expect(app.snapshot!.fetchedAt, DateTime(2026, 9, 30, 11));

    final older = AppState(repository(DateTime(2026, 9, 30, 9)), prefs);
    await older.load();
    await older.refresh();
    await app.syncCache();
    expect(app.snapshot!.fetchedAt, DateTime(2026, 9, 30, 11));
  });

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

  test('aggiornare di nuovo lo stesso luogo durante un aggiornamento non lo riscarica', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final repo = _SlowRepository(DateTime(2026, 9, 25, 10));
    final state = AppState(repo, await SharedPreferences.getInstance());
    await state.load();

    final first = state.refresh();
    await state.refresh();
    repo.gate.complete();
    await first;

    expect(repo.asked, ['Lecce']);
    expect(state.snapshot, isNotNull);
  });

  test('il livello del giorno dice quando viene solo da una stima', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'followed': ['parietaria'],
    });
    final repo = _SlowRepository(DateTime(2026, 4, 15, 10))..gate.complete();
    final state = AppState(repo, await SharedPreferences.getInstance());
    await state.load();
    await state.refresh();
    expect(state.followedStatuses.single.kind, DataKind.estimate);
    expect(state.dayLevel, isNot(Level.none));
    expect(state.dayLevelSource, DataKind.estimate);
  });

  test('le preferenze assenti tornano ai valori iniziali', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'thresholds': '{"grass":3}',
      'followed': ['olive'],
    });
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(_SlowRepository(DateTime(2026, 9, 25, 10)), prefs);
    await state.load();
    expect(state.personal, isNotEmpty);

    await prefs.remove('thresholds');
    await prefs.remove('followed');
    await state.load();
    expect(state.personal, isEmpty);
    expect(state.followed, {'grass', 'parietaria'});
  });

  test('impostazioni rovinate: valori predefiniti, niente eccezioni', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'place': '{rotto',
      'thresholds': '[1]',
      'alerts': 'x',
      'followed': ['grass'],
    });
    final state = AppState(_SlowRepository(DateTime(2026, 9, 25, 10)), await SharedPreferences.getInstance());
    await state.load();
    expect(state.onboarded, isTrue);
    expect(state.place.name, 'Lecce');
    expect(state.personal, isEmpty);
    expect(state.alerts.anyEnabled, isTrue);
    expect(state.followed, {'grass'});
  });
}
