import 'dart:io';

import 'package:allergy_radar/models/allergen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ogni allergene ha la sua tavola, dove cresce e reazioni crociate', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final a in Allergens.all) {
      expect(File(a.plate).existsSync(), isTrue, reason: a.plate);
      expect(pubspec, contains('- ${File(a.plate).parent.path.replaceAll(r'\', '/')}/'));
      expect(a.habitat.trim(), endsWith('.'), reason: a.id);
      expect(a.crossReactions.trim(), endsWith('.'), reason: a.id);
    }
    expect(Directory('assets/images/plants').listSync(), hasLength(Allergens.all.length));
  });
}
