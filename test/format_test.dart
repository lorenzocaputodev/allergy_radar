import 'package:allergy_radar/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('i numeri dei granuli: niente «0,0», una cifra decimale solo se serve', () {
    expect(Fmt.number(0), '0');
    expect(Fmt.number(0.03), '0');
    expect(Fmt.number(0.06), '0,1');
    expect(Fmt.number(2.96), '3');
    expect(Fmt.number(7.04), '7');
    expect(Fmt.number(7.25), '7,3');
    expect(Fmt.number(9.97), '10');
    expect(Fmt.number(73.4), '73');
  });
}
