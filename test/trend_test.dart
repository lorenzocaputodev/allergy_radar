import 'package:allergy_radar/models/diary_entry.dart';
import 'package:allergy_radar/models/level.dart';
import 'package:allergy_radar/models/trend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 10, 13, 18);
  DiaryEntry entry(int month, int day, int nose, int pollen) =>
      DiaryEntry(date: DateTime(2026, month, day), nose: nose, pollen: {'parietaria': pollen});

  List<TrendBucket> build(int period, List<DiaryEntry> entries) =>
      TrendBucket.build(entries: entries, allergenId: 'parietaria', period: period, today: today);

  test('30 giorni: un elemento per giorno, l’ultimo è oggi', () {
    final b = build(30, [entry(10, 13, 2, 3)]);
    expect(b, hasLength(30));
    expect(b.first.from, DateTime(2026, 9, 14));
    expect(b.last.from, DateTime(2026, 10, 13));
    expect(b.last.symptoms, 2);
    expect(b.last.pollen, Level.high);
    expect(b.first.symptoms, isNull);
  });

  test('3 mesi: 13 settimane di 7 giorni, l’ultima finisce oggi', () {
    final b = build(90, [entry(10, 7, 1, 1), entry(10, 10, 3, 3), entry(10, 6, 2, 2)]);
    expect(b, hasLength(13));
    expect(b.last.from, DateTime(2026, 10, 7));
    expect(b.last.to, DateTime(2026, 10, 13));
    expect(b.last.logged, 2);
    expect(b.last.symptoms, 2);
    expect(b.last.pollen, Level.high);
    expect(b[11].logged, 1);
    for (final w in b) {
      expect(w.to.difference(w.from).inDays, 6);
    }
  });

  test('1 anno: 12 mesi di calendario, l’ultimo arriva a oggi', () {
    final b = build(365, [entry(11, 30, 1, 1), entry(10, 1, 2, 4), entry(2, 28, 1, 0)]);
    expect(b, hasLength(12));
    expect(b.first.from, DateTime(2025, 11, 1));
    expect(b.first.to, DateTime(2025, 11, 30));
    expect(b.first.logged, 0, reason: 'il 30 novembre 2026 è nel futuro, non nel 2025');
    expect(b[3].from, DateTime(2026, 2, 1));
    expect(b[3].to, DateTime(2026, 2, 28));
    expect(b[3].pollen, Level.none);
    expect(b.last.from, DateTime(2026, 10, 1));
    expect(b.last.to, DateTime(2026, 10, 13));
    expect(b.last.pollen, Level.veryHigh);
  });

  test('senza dati del polline il livello resta vuoto, non «nessuno»', () {
    final b = build(30, [DiaryEntry(date: DateTime(2026, 10, 13))]);
    expect(b.last.pollen, isNull);
    expect(b.last.symptoms, 0);
  });
}
