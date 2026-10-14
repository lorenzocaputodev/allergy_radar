import 'dart:convert';

import 'package:allergy_radar/services/backup.dart';
import 'package:allergy_radar/services/update_checker.dart';
import 'package:allergy_radar/state/update_state.dart';
import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MockClient github(String tag, {List<Uri>? log, int status = 200}) => MockClient((req) async {
    log?.add(req.url);
    return http.Response(jsonEncode({'tag_name': tag}), status);
  });

  Future<UpdateState> updates(MockClient client, {Map<String, Object> prefs = const {}}) async {
    SharedPreferences.setMockInitialValues(prefs);
    return UpdateState(await SharedPreferences.getInstance(), UpdateChecker(client), current: '1.1.2')..load();
  }

  test('confronta le versioni numero per numero', () {
    expect(UpdateChecker.isNewer('1.2.0', '1.1.2'), isTrue);
    expect(UpdateChecker.isNewer('1.1.10', '1.1.9'), isTrue);
    expect(UpdateChecker.isNewer('2.0.0', '1.9.9'), isTrue);
    expect(UpdateChecker.isNewer('1.1.2', '1.1.2'), isFalse);
    expect(UpdateChecker.isNewer('1.0.9', '1.1.2'), isFalse);
    expect(UpdateChecker.isNewer('1.2', '1.1.2'), isFalse);
    expect(UpdateChecker.isNewer('1.2.0-beta', '1.1.2'), isFalse);
  });

  test('legge la versione dal tag della release', () async {
    final log = <Uri>[];
    expect(await UpdateChecker(github('v1.2.0', log: log)).latestVersion(), '1.2.0');
    expect(log.single, UpdateChecker.latestUri);
    expect(UpdateChecker(github('nightly')).latestVersion(), throwsA(isA<UpdateException>()));
    expect(UpdateChecker(github('v1.2.0', status: 404)).latestVersion(), throwsA(isA<UpdateException>()));
  });

  test('una versione più recente è disponibile, finché non la si rimanda', () async {
    final u = await updates(github('v1.2.0'));
    expect(u.available, isNull);
    await u.check();
    expect(u.available, '1.2.0');
    await u.dismiss();
    expect(u.available, isNull);
    u.load();
    expect(u.available, isNull);
  });

  test('la release successiva ricompare dopo un rinvio', () async {
    final u = await updates(github('v1.3.0'), prefs: {'update_latest': '1.2.0', 'update_dismissed': '1.2.0'});
    expect(u.available, isNull);
    await u.check();
    expect(u.available, '1.3.0');
  });

  test('il controllo a mano fa ricomparire la versione rimandata', () async {
    final u = await updates(github('v1.2.0'), prefs: {'update_latest': '1.2.0', 'update_dismissed': '1.2.0'});
    await u.check(manual: true);
    expect(u.available, '1.2.0');
  });

  test('controlla al massimo una volta per periodo', () async {
    final log = <Uri>[];
    final u = await updates(github('v1.1.2', log: log));
    final now = DateTime(2026, 10, 14, 9);
    await withClock(Clock.fixed(now), u.checkIfDue);
    await withClock(Clock.fixed(now.add(const Duration(hours: 23))), u.checkIfDue);
    expect(log, hasLength(1));
    await withClock(Clock.fixed(now.add(const Duration(hours: 25))), u.checkIfDue);
    expect(log, hasLength(2));
    expect(u.available, isNull);
    await u.setFrequency(UpdateFrequency.week);
    await withClock(Clock.fixed(now.add(const Duration(days: 7))), u.checkIfDue);
    expect(log, hasLength(2));
    await withClock(Clock.fixed(now.add(const Duration(days: 9))), u.checkIfDue);
    expect(log, hasLength(3));
  });

  test('con «Mai» non controlla e non mostra nulla', () async {
    final log = <Uri>[];
    final u = await updates(github('v1.2.0', log: log), prefs: {'update_frequency': 'never', 'update_latest': '1.2.0'});
    await u.checkIfDue();
    expect(log, isEmpty);
    expect(u.available, isNull);
  });

  test('un errore di rete nel controllo automatico non si vede', () async {
    final u = await updates(MockClient((_) async => throw http.ClientException('offline')));
    await u.checkIfDue();
    expect(u.checking, isFalse);
    expect(u.available, isNull);
  });

  test('il backup conserva la scelta sull’avviso', () async {
    SharedPreferences.setMockInitialValues({'update_frequency': 'week', 'update_latest': '1.2.0'});
    final json = Backup.export(await SharedPreferences.getInstance(), DateTime(2026, 10, 14));
    final data = (jsonDecode(json) as Map<String, dynamic>).toString();
    expect(data, contains('update_frequency'));
    expect(data, isNot(contains('update_latest')));
  });
}
