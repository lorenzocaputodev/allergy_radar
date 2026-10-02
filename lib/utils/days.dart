extension Days on DateTime {
  DateTime plusDays(int n) => DateTime(year, month, day + n, hour, minute, second, millisecond, microsecond);

  int daysSince(DateTime other) =>
      DateTime.utc(year, month, day).difference(DateTime.utc(other.year, other.month, other.day)).inDays;
}
