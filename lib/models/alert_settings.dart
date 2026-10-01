/// Quali avvisi mandare e a che ora. Gli orari sono minuti dalla mezzanotte.
class AlertSettings {
  const AlertSettings({
    this.briefing = true,
    this.briefingAt = 7 * 60 + 30,
    this.briefingOnlyAbove = false,
    this.tomorrow = true,
    this.tomorrowAt = 19 * 60,
    this.diary = true,
    this.diaryAt = 21 * 60,
  });

  final bool briefing;
  final int briefingAt;

  final bool briefingOnlyAbove;

  final bool tomorrow;
  final int tomorrowAt;

  final bool diary;
  final int diaryAt;

  bool get anyEnabled => briefing || tomorrow || diary;

  static const off = AlertSettings(briefing: false, tomorrow: false, diary: false);

  AlertSettings copyWith({
    bool? briefing,
    int? briefingAt,
    bool? briefingOnlyAbove,
    bool? tomorrow,
    int? tomorrowAt,
    bool? diary,
    int? diaryAt,
  }) => AlertSettings(
    briefing: briefing ?? this.briefing,
    briefingAt: briefingAt ?? this.briefingAt,
    briefingOnlyAbove: briefingOnlyAbove ?? this.briefingOnlyAbove,
    tomorrow: tomorrow ?? this.tomorrow,
    tomorrowAt: tomorrowAt ?? this.tomorrowAt,
    diary: diary ?? this.diary,
    diaryAt: diaryAt ?? this.diaryAt,
  );

  Map<String, dynamic> toJson() => {
    'briefing': briefing,
    'briefingAt': briefingAt,
    'briefingOnlyAbove': briefingOnlyAbove,
    'tomorrow': tomorrow,
    'tomorrowAt': tomorrowAt,
    'diary': diary,
    'diaryAt': diaryAt,
  };

  factory AlertSettings.fromJson(Map<String, dynamic> j) {
    const d = AlertSettings();
    return AlertSettings(
      briefing: j['briefing'] as bool? ?? d.briefing,
      briefingAt: j['briefingAt'] as int? ?? d.briefingAt,
      briefingOnlyAbove: j['briefingOnlyAbove'] as bool? ?? d.briefingOnlyAbove,
      tomorrow: j['tomorrow'] as bool? ?? d.tomorrow,
      tomorrowAt: j['tomorrowAt'] as int? ?? d.tomorrowAt,
      diary: j['diary'] as bool? ?? d.diary,
      diaryAt: j['diaryAt'] as int? ?? d.diaryAt,
    );
  }
}
