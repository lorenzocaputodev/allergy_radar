import 'dart:async';

import 'package:allergy_radar/data/pollen_repository.dart';
import 'package:allergy_radar/models/allergen.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/place.dart';
import 'package:allergy_radar/services/alerts_service.dart';
import 'package:allergy_radar/services/open_meteo_client.dart';
import 'package:allergy_radar/services/pollnet_client.dart';
import 'package:allergy_radar/services/widget_bridge.dart';
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
  Future<RawPollenData> fetchForecast(Place place) async {
    asked.add(place.name);
    if (asked.length == 1) await gate.future;
    return super.fetchForecast(place);
  }
}

class _StuckIspraRepository extends PollenRepository {
  _StuckIspraRepository(DateTime now)
    : super(
        openMeteo: OpenMeteoClient(fakeHttp()),
        pollnet: PollnetClient(fakeHttp()),
        stations: stationDirectory(),
        clock: () => now,
      );

  final gate = Completer<void>();

  @override
  Future<({List<StationCsv> measures, DateTime? at})> fetchMeasures(
    Place place,
    DateTime now, {
    RawPollenData? cached,
    bool force = false,
  }) async {
    await gate.future;
    return super.fetchMeasures(place, now, cached: cached, force: force);
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

  test('aggiornare di nuovo durante un aggiornamento aspetta quello in corso, senza riscaricare', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final repo = _SlowRepository(DateTime(2026, 9, 25, 10));
    final state = AppState(repo, await SharedPreferences.getInstance());
    await state.load();

    final first = state.refresh();
    var secondDone = false;
    final second = state.refresh().then((_) => secondDone = true);
    await pumpEventQueue();
    expect(secondDone, isFalse, reason: 'il pull-to-refresh resta aperto finché arrivano i dati');
    repo.gate.complete();
    await first;
    await second;

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

  test('ISPRA lento: la previsione si vede subito, le misure arrivano dopo', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'place': '{"name":"Bologna","region":null,"lat":44.49,"lon":11.34}',
    });
    final repo = _StuckIspraRepository(DateTime(2026, 9, 25, 10));
    final state = AppState(repo, await SharedPreferences.getInstance());
    await state.load();

    final done = state.refresh();
    await pumpEventQueue();
    expect(state.loading, isTrue);
    expect(state.snapshot!.fetchedAt, DateTime(2026, 9, 25, 10));
    expect(state.snapshot![Allergens.parietaria.id]!.kind, DataKind.estimate);

    repo.gate.complete();
    await done;
    expect(state.loading, isFalse);
    expect(state.snapshot![Allergens.parietaria.id]!.kind, DataKind.measured);
  });

  test('ISPRA giù: restano le misure già scaricate, con la loro data', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'place': '{"name":"Bologna","region":null,"lat":44.49,"lon":11.34}',
    });
    final prefs = await SharedPreferences.getInstance();
    final first = AppState(repository(DateTime(2026, 9, 25, 10)), prefs);
    await first.load();
    await first.refresh();

    final later = AppState(repository(DateTime(2026, 9, 26, 10), ispraDown: true), prefs);
    await later.load();
    await later.refresh();
    final par = later.snapshot![Allergens.parietaria.id]!;
    expect(later.snapshot!.fetchedAt, DateTime(2026, 9, 26, 10));
    expect(par.kind, DataKind.measured);
    expect(par.date, DateTime(2026, 9, 20));
    expect(later.error, isNull);
  });

  test('Open-Meteo giù al primo avvio: stime dichiarate, e si riprova al prossimo giro', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final state = AppState(
      repository(DateTime(2026, 9, 30, 10), openMeteoDown: true),
      await SharedPreferences.getInstance(),
    );
    await state.load();
    await state.refresh();
    expect(state.estimatesOnly, isTrue);
    expect(state.snapshot!.statuses.values.every((s) => s.kind == DataKind.estimate), isTrue);
    expect(state.error, contains('stime'));
    expect(state.isStale, isTrue);
  });

  test('stime di ripiego: il widget non dice «aggiornato»', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final state = AppState(
      repository(DateTime(2026, 9, 30, 10), openMeteoDown: true),
      await SharedPreferences.getInstance(),
    );
    await state.load();
    await state.refresh();
    expect(WidgetBridge.encode(state), contains('"updated":""'));
  });

  test('widget aggiornato dal background appena arriva la previsione, senza aspettare ISPRA', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'place': '{"name":"Bologna","region":null,"lat":44.49,"lon":11.34}',
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = _StuckIspraRepository(DateTime(2026, 9, 25, 10));
    final app = AppState(repo, prefs);
    await app.load();

    final done = AlertsService.refreshWidget(prefs, app, manual: true);
    await pumpEventQueue();
    expect(app.loading, isTrue, reason: 'ISPRA non ha ancora risposto');
    expect(prefs.getString('widget_data'), contains('Bologna'));
    expect(prefs.getString('widget_data'), contains('2026-09-25T10:00'));

    repo.gate.complete();
    await done;
    expect(app.loading, isFalse);
  });

  test('cambiare luogo non aspetta l’aggiornamento del luogo vecchio', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final repo = _SlowRepository(DateTime(2026, 9, 25, 10));
    final state = AppState(repo, await SharedPreferences.getInstance());
    await state.load();

    final old = state.refresh();
    await state.setPlace(bologna);
    expect(state.snapshot!.place.name, 'Bologna');
    expect(state.loading, isTrue, reason: 'Lecce è ancora in corso');
    repo.gate.complete();
    await old;
    expect(state.snapshot!.place.name, 'Bologna');
    expect(state.loading, isFalse);
  });

  test('il nome arrivato dopo rinomina il luogo senza riscaricare', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState(repository(DateTime(2026, 9, 30, 10)), prefs);
    await state.load();
    await state.setPlace(const Place(name: 'Lecce', lat: 40.36, lon: 18.17));
    final before = state.snapshot;
    await state.rename(const Place(name: 'San Cesario di Lecce', region: 'Puglia', lat: 40.36, lon: 18.17));
    expect(state.place.name, 'San Cesario di Lecce');
    expect(state.saved.first.name, 'San Cesario di Lecce');
    expect(state.snapshot, same(before));
    expect(prefs.getString(AppState.kPlace), contains('San Cesario'));
    await state.rename(const Place(name: 'Altrove', lat: 45.0, lon: 9.0));
    expect(state.place.name, 'San Cesario di Lecce');
  });

  test('con le sole stime: niente dati veri, e riscegliere lo stesso luogo riprova', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final prefs = await SharedPreferences.getInstance();
    final down = AppState(repository(DateTime(2026, 9, 30, 10), openMeteoDown: true), prefs);
    await down.load();
    await down.refresh();
    expect(down.snapshot, isNotNull);
    expect(down.hasData, isFalse);

    final log = <Uri>[];
    final up = AppState(repository(DateTime(2026, 9, 30, 10), log: log), prefs);
    await up.load();
    await up.refresh();
    expect(up.hasData, isTrue);
  });

  test('misure scaricate da poco: ISPRA non viene richiamato', () async {
    SharedPreferences.setMockInitialValues({
      'onboarded': true,
      'place': '{"name":"Bologna","region":null,"lat":44.49,"lon":11.34}',
    });
    final prefs = await SharedPreferences.getInstance();
    final first = AppState(repository(DateTime(2026, 9, 25, 10)), prefs);
    await first.load();
    await first.refresh();

    final log = <Uri>[];
    final later = AppState(repository(DateTime(2026, 9, 25, 12), log: log), prefs);
    await later.load();
    await later.refresh();
    expect(log.where((u) => u.host == 'sdi.isprambiente.it'), isEmpty);
    expect(later.snapshot![Allergens.parietaria.id]!.kind, DataKind.measured);
    expect(later.snapshot!.fetchedAt, DateTime(2026, 9, 25, 12));
  });

  test('riscegliere il luogo attivo non cancella i dati', () async {
    SharedPreferences.setMockInitialValues({'onboarded': true});
    final state = AppState(repository(DateTime(2026, 9, 30, 10)), await SharedPreferences.getInstance());
    await state.load();
    await state.refresh();
    final before = state.snapshot;
    await state.setPlace(Place.lecce);
    expect(state.snapshot, same(before));
  });

  group('luoghi', () {
    Place at(String name, double lat) => Place(name: name, lat: lat, lon: 18.17);

    Future<AppState> fresh() async {
      SharedPreferences.setMockInitialValues({'onboarded': true});
      final state = AppState(repository(DateTime(2026, 9, 30, 10)), await SharedPreferences.getInstance());
      await state.load();
      return state;
    }

    test('i luoghi scelti si salvano: il più recente in cima, niente doppioni, al massimo 5', () async {
      final state = await fresh();
      for (final (i, name) in ['A', 'B', 'C', 'D', 'E', 'F'].indexed) {
        await state.setPlace(at(name, 40.0 + i));
      }
      await state.setPlace(at('D di nuovo', 43));
      expect(state.saved.map((p) => p.name), ['D di nuovo', 'F', 'E', 'C', 'B']);

      await state.forget(state.saved[1]);
      final again = AppState(repository(DateTime(2026, 9, 30, 10)), await SharedPreferences.getInstance());
      await again.load();
      expect(again.saved.map((p) => p.name), ['D di nuovo', 'E', 'C', 'B']);
      expect(AppState.backupKeys, containsAll([AppState.kPlaces, AppState.kFollowLocation]));
    });

    test('seguire la posizione: cambia luogo solo oltre 5 km e non riempie i luoghi salvati', () async {
      final state = await fresh();
      await state.startFollowing(at('Qui', 40.35));
      expect(state.followLocation, isTrue);
      expect(state.place.name, 'Qui');
      expect(state.saved, isEmpty);

      var described = 0;
      Future<void> moveTo(String name, double lat) => state.follow(() async => (lat: lat, lon: 18.17), (la, lo) async {
        described++;
        return Place(name: name, lat: la, lon: lo);
      });

      await moveTo('Poco più in là', 40.37);
      expect(state.place.name, 'Qui');
      expect(described, 0, reason: 'sotto i 5 km il nome del comune non si cerca');
      await moveTo('Altrove', 40.5);
      expect(state.place.name, 'Altrove');
      await state.follow(() async => throw Exception('GPS spento'), (la, lo) async => at('Mai', la));
      expect(state.place.name, 'Altrove');
    });

    test('due ritorni nell’app ravvicinati chiedono la posizione una volta sola', () async {
      final state = await fresh();
      await state.startFollowing(at('Qui', 40.35));
      var asked = 0;
      final gate = Completer<void>();
      Future<({double lat, double lon})> slow() async {
        asked++;
        await gate.future;
        return (lat: 40.35, lon: 18.17);
      }

      final first = state.follow(slow, (la, lo) async => at('Mai', la));
      final second = state.follow(slow, (la, lo) async => at('Mai', la));
      gate.complete();
      await first;
      await second;
      expect(asked, 1);
    });

    test('scegliere un luogo a mano smette di seguire la posizione', () async {
      final state = await fresh();
      await state.startFollowing(at('Qui', 40.35));
      await state.setPlace(at('Roma', 41.9));
      expect(state.followLocation, isFalse);
      await state.follow(() async => (lat: 40.5, lon: 18.17), (la, lo) async => at('Altrove', la));
      expect(state.place.name, 'Roma');
    });
  });
}
