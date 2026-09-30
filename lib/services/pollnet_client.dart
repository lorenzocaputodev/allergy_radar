import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Misure giornaliere della rete POLLnet, dal servizio WFS open data di ISPRA (CC BY 4.0).
///
/// Si usa l'output CSV: in quello JSON le date risultano spostate indietro di un giorno.
class PollnetClient {
  PollnetClient(this._http);

  final http.Client _http;

  static final _day = DateFormat('yyyy-MM-dd');

  Uri concentrationsUri(int stationId, Iterable<int> partIds, DateTime from, DateTime to) =>
      Uri.https('sdi.isprambiente.it', '/geoserver/om/ows', {
        'service': 'WFS',
        'version': '2.0.0',
        'request': 'GetFeature',
        'typeName': 'om:Concentrazione_pollini_spore',
        'cql_filter':
            "STAT_ID=$stationId and PART_ID IN (${partIds.join(',')}) "
            "and REMA_DATE between '${_day.format(from)}' and '${_day.format(to)}'",
        'outputFormat': 'csv',
      });

  Future<String> fetchCsv(int stationId, Iterable<int> partIds, DateTime from, DateTime to) async {
    final res = await _http.get(concentrationsUri(stationId, partIds, from, to)).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw PollnetException('ISPRA ha risposto ${res.statusCode}');
    return utf8.decode(res.bodyBytes);
  }

  static List<Measurement> parseCsv(String csv) {
    final lines = csv.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return const [];
    final header = splitCsvLine(lines.first);
    final iPart = header.indexOf('PART_ID');
    final iValue = header.indexOf('REMA_CONCENTRATION');
    final iDate = header.indexOf('REMA_DATE');
    if (iPart < 0 || iValue < 0 || iDate < 0) throw PollnetException('Formato CSV ISPRA inatteso');
    final out = <Measurement>[];
    for (final line in lines.skip(1)) {
      final f = splitCsvLine(line);
      if (f.length <= [iPart, iValue, iDate].reduce((a, b) => a > b ? a : b)) continue;
      final part = int.tryParse(f[iPart]);
      final date = DateTime.tryParse(f[iDate]);
      if (part == null || date == null) continue;
      out.add(Measurement(part, DateTime(date.year, date.month, date.day), double.tryParse(f[iValue])));
    }
    return out;
  }

  /// Split di una riga CSV con campi eventualmente tra virgolette.
  static List<String> splitCsvLine(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var quoted = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (quoted && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          quoted = !quoted;
        }
      } else if (c == ',' && !quoted) {
        out.add(buf.toString());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString());
    return out;
  }
}

class Measurement {
  const Measurement(this.partId, this.date, this.value);

  final int partId;
  final DateTime date;

  /// Null quando la stazione non ha campionato quel giorno.
  final double? value;
}

class PollnetException implements Exception {
  PollnetException(this.message);

  final String message;

  @override
  String toString() => message;
}
