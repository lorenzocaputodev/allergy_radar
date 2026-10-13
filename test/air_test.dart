import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/pollen_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('livelli dell’aria ai bordi delle soglie', () {
    expect(AirMetric.ozone.levelOf(99.9), Level.low);
    expect(AirMetric.ozone.levelOf(100), Level.moderate);
    expect(AirMetric.ozone.levelOf(240), Level.veryHigh);
    expect(AirMetric.pm25.levelOf(9), Level.low);
    expect(AirMetric.pm25.levelOf(49.9), Level.high);
    expect(AirMetric.dust.levelOf(19), Level.none);
    expect(AirMetric.dust.levelOf(200), Level.veryHigh);
  });

  test('la scala del foglio copre tutti i livelli senza buchi', () {
    for (final m in AirMetric.values) {
      final bands = m.bands;
      expect(bands.first.$2, isNull);
      expect(bands.last.$3, isNull);
      for (var i = 1; i < bands.length; i++) {
        expect(bands[i].$2, bands[i - 1].$3);
        expect(m.levelOf(bands[i].$2!), bands[i].$1);
      }
      expect(bands.last.$1, Level.veryHigh);
    }
  });
}
