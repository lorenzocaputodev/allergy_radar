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
    double v(String k, int i) {
      final s = series[k];
      return (s == null || i >= s.length ? null : s[i]) ?? 0;
    }

    WeatherHint? best;
    for (final (event, offset, hit) in <(WeatherEvent, int, bool Function(int))>[
      (WeatherEvent.storm, 0, (i) => v('weather_code', i) >= 95),
      (WeatherEvent.rain, -1, (i) => v('precipitation', i) >= rainMm),
      (WeatherEvent.wind, 0, (i) => v('wind_speed_10m', i) >= windKmh),
    ]) {
      for (var i = 0; i < times.length; i++) {
        final at = times[i].add(Duration(hours: offset));
        if (at.isBefore(from) || at.isAfter(to) || !hit(i)) continue;
        if (best == null || at.isBefore(best.at)) best = WeatherHint(event, at, ongoing: at == from);
        break;
      }
    }
    return best;
  }
}
