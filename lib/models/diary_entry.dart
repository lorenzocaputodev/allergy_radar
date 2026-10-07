import '../utils/days.dart';

class DiaryEntry {
  const DiaryEntry({
    required this.date,
    this.nose = 0,
    this.eyes = 0,
    this.throat = 0,
    this.breath = 0,
    this.badSleep = false,
    this.meds = const [],
    this.outdoor,
    this.note = '',
    this.pollen = const {},
    this.place,
  });

  final DateTime date;

  final int nose;
  final int eyes;
  final int throat;
  final int breath;

  final bool badSleep;
  final List<String> meds;

  final int? outdoor;
  final String note;

  final Map<String, int> pollen;

  final String? place;

  static const severityNames = ['Nessuno', 'Lievi', 'Medi', 'Forti'];
  static const symptomNames = ['Nessun sintomo', 'Sintomi lievi', 'Sintomi medi', 'Sintomi forti'];

  static DateTime day(DateTime d) => d.dateOnly;

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get key => keyOf(date);

  int get severity => [nose, eyes, throat, breath].reduce((a, b) => a > b ? a : b);

  double get score => severity.toDouble();

  static int medicationScore(String name) => name.toLowerCase().contains('cortison') ? 2 : 1;

  int get medScore => meds.fold(0, (m, name) => m > medicationScore(name) ? m : medicationScore(name));

  int get combinedScore => severity + medScore;

  DiaryEntry copyWith({
    int? nose,
    int? eyes,
    int? throat,
    int? breath,
    bool? badSleep,
    List<String>? meds,
    int? outdoor,
    bool clearOutdoor = false,
    String? note,
    Map<String, int>? pollen,
    String? place,
  }) => DiaryEntry(
    date: date,
    nose: nose ?? this.nose,
    eyes: eyes ?? this.eyes,
    throat: throat ?? this.throat,
    breath: breath ?? this.breath,
    badSleep: badSleep ?? this.badSleep,
    meds: meds ?? this.meds,
    outdoor: clearOutdoor ? null : (outdoor ?? this.outdoor),
    note: note ?? this.note,
    pollen: pollen ?? this.pollen,
    place: place ?? this.place,
  );

  Map<String, dynamic> toJson() => {
    'date': key,
    'nose': nose,
    'eyes': eyes,
    'throat': throat,
    'breath': breath,
    'badSleep': badSleep,
    'meds': meds,
    'outdoor': outdoor,
    'note': note,
    'pollen': pollen,
    if (place != null) 'place': place,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    date: DateTime.parse(j['date'] as String),
    nose: j['nose'] as int? ?? 0,
    eyes: j['eyes'] as int? ?? 0,
    throat: j['throat'] as int? ?? 0,
    breath: j['breath'] as int? ?? 0,
    badSleep: j['badSleep'] as bool? ?? false,
    meds: [for (final m in j['meds'] as List? ?? const []) m as String],
    outdoor: j['outdoor'] as int?,
    note: j['note'] as String? ?? '',
    pollen: (j['pollen'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ?? const {},
    place: j['place'] as String?,
  );
}
