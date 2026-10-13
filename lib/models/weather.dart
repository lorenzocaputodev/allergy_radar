enum WeatherEvent { storm, rain, wind }

class HourlyWeather {
  const HourlyWeather(this.times, this.series);

  final List<DateTime> times;
  final Map<String, List<double?>> series;

  WeatherHint? hintAt(DateTime now) => WeatherHint.of(times, series, now);
}

class WeatherHint {
  const WeatherHint(this.event, this.at, {required this.ongoing});

  final WeatherEvent event;
  final DateTime at;
  final bool ongoing;

  static const rainMm = 1.0;
  static const windKmh = 30.0;
  static const lastHour = 21;
  static const keys = ['precipitation', 'weather_code', 'wind_speed_10m'];

  static WeatherHint? of(List<DateTime> times, Map<String, List<double?>> series, DateTime now) {
    final from = DateTime(now.year, now.month, now.day, now.hour);
    final to = DateTime(now.year, now.month, now.day, lastHour);
    DateTime? first(bool Function(int i) hit) {
      for (var i = 0; i < times.length; i++) {
        final t = times[i];
        if (!t.isBefore(from) && !t.isAfter(to) && hit(i)) return t;
      }
      return null;
    }

    double? v(String k, int i) {
      final s = series[k];
      return s == null || i >= s.length ? null : s[i];
    }

    for (final (event, hit) in <(WeatherEvent, bool Function(int))>[
      (WeatherEvent.storm, (i) => (v('weather_code', i) ?? 0) >= 95),
      (WeatherEvent.rain, (i) => (v('precipitation', i) ?? 0) >= rainMm),
      (WeatherEvent.wind, (i) => (v('wind_speed_10m', i) ?? 0) >= windKmh),
    ]) {
      if (first(hit) case final t?) return WeatherHint(event, t, ongoing: t == from);
    }
    return null;
  }
}
