/// Una voce del diario: come stavi in un giorno, con i pollini di quel giorno.
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
  });

  /// Giorno, senza ora.
  final DateTime date;

  /// Intensità 0–3: no, lieve, medio, forte.
  final int nose;
  final int eyes;
  final int throat;
  final int breath;

  final bool badSleep;
  final List<String> meds;

  /// Ore all'aperto: 0 meno di 1, 1 da 1 a 3, 2 più di 3. Null se non indicato.
  final int? outdoor;
  final String note;

  /// Livello (0–4) di ogni allergene al momento del salvataggio, per id.
  final Map<String, int> pollen;

  static const severityNames = ['Nessuno', 'Lievi', 'Medi', 'Forti'];
  static const symptomNames = ['Nessun sintomo', 'Sintomi lievi', 'Sintomi medi', 'Sintomi forti'];

  static DateTime day(DateTime d) => DateTime(d.year, d.month, d.day);

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get key => keyOf(date);

  /// Intensità del giorno, 0–3: il sintomo peggiore. Un naso «forte» fa una giornata brutta
  /// anche se il resto va bene; la media la farebbe sembrare lieve.
  int get severity => [nose, eyes, throat, breath].reduce((a, b) => a > b ? a : b);

  double get score => severity.toDouble();

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
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
    date: DateTime.parse(j['date'] as String),
    nose: j['nose'] as int? ?? 0,
    eyes: j['eyes'] as int? ?? 0,
    throat: j['throat'] as int? ?? 0,
    breath: j['breath'] as int? ?? 0,
    badSleep: j['badSleep'] as bool? ?? false,
    meds: (j['meds'] as List?)?.cast<String>() ?? const [],
    outdoor: j['outdoor'] as int?,
    note: j['note'] as String? ?? '',
    pollen: (j['pollen'] as Map?)?.map((k, v) => MapEntry(k as String, v as int)) ?? const {},
  );
}
