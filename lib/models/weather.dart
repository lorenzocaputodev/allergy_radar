enum WeatherEvent { storm, rain, wind }

class HourlyWeather {
  const HourlyWeather(this.times, this.series);

  final List<DateTime> times;
  final Map<String, List<double?>> series;

  WeatherHint? hintAt(DateTime now) => WeatherHint.of(times, series, now);

  WeatherHint? hintOn(DateTime day) =>
      WeatherHint.of(times, series, DateTime(day.year, day.month, day.day, WeatherHint.firstHour), ahead: true);

  Set<int> roughHours(DateTime day) => {
    for (var i = 0; i < times.length; i++)
      if (times[i].year == day.year &&
          times[i].month == day.month &&
          times[i].day == day.day &&
          (WeatherHint.value(series, 'weather_code', i) >= WeatherHint.stormCode ||
              WeatherHint.value(series, 'wind_speed_10m', i) >= WeatherHint.windKmh))
        times[i].hour,
  };
}

class WeatherHint {
  const WeatherHint(this.event, this.at, {required this.ongoing});

  final WeatherEvent event;
  final DateTime at;
  final bool ongoing;

  static const rainMm = 1.0;
  static const windKmh = 30.0;
  static const stormCode = 95.0;
  static const firstHour = 7;
  static const lastHour = 21;
  static const keys = ['precipitation', 'weather_code', 'wind_speed_10m'];

  static double value(Map<String, List<double?>> series, String k, int i) {
    final s = series[k];
    return (s == null || i >= s.length ? null : s[i]) ?? 0;
  }

  static WeatherHint? of(List<DateTime> times, Map<String, List<double?>> series, DateTime now, {bool ahead = false}) {
    final from = DateTime(now.year, now.month, now.day, now.hour);
    final to = DateTime(now.year, now.month, now.day, lastHour);
    double v(String k, int i) => value(series, k, i);

    WeatherHint? best;
    for (final (event, offset, hit) in <(WeatherEvent, int, bool Function(int))>[
      (WeatherEvent.storm, 0, (i) => v('weather_code', i) >= stormCode),
      (WeatherEvent.rain, -1, (i) => v('precipitation', i) >= rainMm),
      (WeatherEvent.wind, 0, (i) => v('wind_speed_10m', i) >= windKmh),
    ]) {
      for (var i = 0; i < times.length; i++) {
        final at = times[i].add(Duration(hours: offset));
        if (at.isBefore(from) || at.isAfter(to) || !hit(i)) continue;
        if (best == null || at.isBefore(best.at)) best = WeatherHint(event, at, ongoing: !ahead && at == from);
        break;
      }
    }
    return best;
  }

  String get text {
    final h = ongoing ? null : '${at.hour}';
    return switch (event) {
      WeatherEvent.storm => '${h == null ? 'Temporale in corso' : 'Temporale verso le $h'}: attenzione se hai l’asma',
      WeatherEvent.rain => '${h == null ? 'Piove' : 'Pioggia dalle $h'}: pollini in calo',
      WeatherEvent.wind => 'Vento forte${h == null ? '' : ' dalle $h'}: più pollini in aria',
    };
  }
}
