import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';

/// PDF da portare all'allergologo: sintesi, confronti e diario giorno per giorno.
class ReportPdf {
  static const days = 90;

  static const _ink = PdfColor.fromInt(0xFF17201C);
  static const _muted = PdfColor.fromInt(0xFF5C6661);
  static const _line = PdfColor.fromInt(0xFFE2DED3);
  static const _zebra = PdfColor.fromInt(0xFFF7F6F1);
  static const _soft = PdfColor.fromInt(0xFFE1ECE6);
  static const _pine = PdfColor.fromInt(0xFF1F5A4A);
  static const _symptom = ['nessuno', 'lieve', 'medio', 'forte'];
  static const _months = [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ];

  static PdfColor _pdf(Color c) => PdfColor.fromInt(c.toARGB32());
  static String _date(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
  static String _days(int n) => n == 1 ? '1 giorno' : '$n giorni';
  static String _num(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1).replaceAll('.', ',');

  static Future<Uint8List> build({
    required DiaryState diary,
    required List<Allergen> allergens,
    required String placeName,
    required DateTime now,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-400.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-700.ttf'));
    const palette = AppPalette.light;
    final today = DiaryEntry.day(now);
    final from = today.subtract(const Duration(days: days - 1));
    final entries = diary.between(from, now);
    final start = entries.isEmpty ? from : entries.first.date;
    final span = today.difference(start).inDays + 1;
    final medDays = <String, int>{};
    for (final e in entries) {
      for (final m in e.meds) {
        medDays[m] = (medDays[m] ?? 0) + 1;
      }
    }
    final withMeds = entries.where((e) => e.meds.isNotEmpty).length;
    final avg = entries.isEmpty ? null : entries.fold<double>(0, (s, e) => s + e.score) / entries.length;
    final insights = [for (final a in allergens) ?diary.insight(a, now, days: days)];

    pw.Widget small(String s, {PdfColor color = _muted}) =>
        pw.Text(s, style: pw.TextStyle(fontSize: 8.5, color: color));
    pw.Widget heading(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
      child: pw.Text(s, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    );

    pw.Widget summary(String title, String value, String note) => pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.fromLTRB(10, 9, 10, 10),
        decoration: pw.BoxDecoration(color: _soft, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            small(title.toUpperCase()),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _pine),
            ),
            pw.SizedBox(height: 2),
            small(note, color: _ink),
          ],
        ),
      ),
    );

    pw.Widget cell(String s, {PdfColor? fill, PdfColor color = _ink, bool center = false}) => pw.Container(
      color: fill,
      alignment: center ? pw.Alignment.center : pw.Alignment.centerLeft,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(s, style: pw.TextStyle(fontSize: 8, color: color)),
    );
    pw.Widget symptom(int v) => cell(
      v == 0 ? '–' : _symptom[v],
      fill: _pdf(palette.symFill[v]),
      color: _pdf(palette.symOnFill[v]),
      center: true,
    );
    pw.Widget pollen(int? v) => v == null
        ? cell('', center: true)
        : cell(
            Level.fromIndex(v).label.toLowerCase(),
            fill: _pdf(palette.riskFill[v]),
            color: _pdf(palette.riskOnFill[v]),
            center: true,
          );
    pw.Widget head(String s) => pw.Container(
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 5),
      child: pw.Text(
        s,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      ),
    );

    pw.Widget swatch(Color fill, String name) => pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 9,
          height: 9,
          decoration: pw.BoxDecoration(color: _pdf(fill), borderRadius: pw.BorderRadius.circular(2)),
        ),
        pw.SizedBox(width: 4),
        small(name),
        pw.SizedBox(width: 10),
      ],
    );

    final doc = pw.Document(title: 'Diario allergie', author: 'Allergy Radar');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        theme: pw.ThemeData.withFont(
          base: regular,
          bold: bold,
        ).copyWith(defaultTextStyle: const pw.TextStyle(color: _ink, fontSize: 10)),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            small('Allergy Radar · l’app informa, non sostituisce il medico'),
            small('Pagina ${ctx.pageNumber} di ${ctx.pagesCount}'),
          ],
        ),
        build: (ctx) => [
          pw.Row(
            children: [
              pw.SizedBox(width: 34, height: 34, child: pw.CustomPaint(painter: _mark)),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Diario dei sintomi',
                      style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pine),
                    ),
                    small('Allergy Radar · $placeName'),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    start == today ? _date(today) : '${_date(start)} – ${_date(today)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  small('Generato il ${_date(now)}'),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              summary('Giorni registrati', '${entries.length}', 'su ${_days(span)}'),
              pw.SizedBox(width: 8),
              summary(
                'Intensità media',
                avg == null ? '–' : '${_num(avg)} su 3',
                avg == null ? 'nessuna voce' : _symptom[avg.round()],
              ),
              pw.SizedBox(width: 8),
              summary(
                'Giorni con farmaci',
                '$withMeds',
                medDays.isEmpty
                    ? 'nessun farmaco'
                    : medDays.entries.map((e) => '${e.key} · ${_days(e.value)}').join('\n'),
              ),
              pw.SizedBox(width: 8),
              summary(
                'Allergeni seguiti',
                '${allergens.length}',
                allergens.isEmpty ? 'nessuno' : allergens.map((a) => a.name).join(', '),
              ),
            ],
          ),
          heading('Cosa emerge'),
          if (insights.isEmpty)
            pw.Text(
              'Per un confronto servono almeno ${DiaryState.minDaysForInsight} giorni registrati, '
              'di cui almeno 3 con il polline da moderato in su e 3 sotto.',
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            )
          else
            for (final i in insights)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.RichText(
                  text: pw.TextSpan(
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                    children: [
                      pw.TextSpan(
                        text: '${i.allergen.name}: ',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.TextSpan(
                        text:
                            'intensità media ${_num(i.highMean)} nei giorni da moderato in su (${_days(i.highDays)}), '
                            '${_num(i.lowMean)} negli altri (${_days(i.lowDays)}).',
                      ),
                    ],
                  ),
                ),
              ),
          heading('Giorno per giorno'),
          if (entries.isEmpty)
            pw.Text('Nessuna voce nel periodo.', style: const pw.TextStyle(fontSize: 10, color: _muted))
          else
            pw.Table(
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              columnWidths: {
                0: const pw.FixedColumnWidth(34),
                for (var c = 1; c <= 4; c++) c: const pw.FixedColumnWidth(38),
                5: const pw.FixedColumnWidth(52),
                6: const pw.FlexColumnWidth(2),
                for (var c = 0; c < allergens.length; c++) 7 + c: const pw.FixedColumnWidth(52),
                7 + allergens.length: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: _pine),
                  repeat: true,
                  children: [
                    for (final h in ['Data', 'Naso', 'Occhi', 'Gola', 'Respiro', 'Sonno', 'Farmaci']) head(h),
                    for (final a in allergens) head(a.name),
                    head('Nota'),
                  ],
                ),
                for (final (n, e) in entries.indexed)
                  pw.TableRow(
                    decoration: n.isOdd ? const pw.BoxDecoration(color: _zebra) : null,
                    verticalAlignment: pw.TableCellVerticalAlignment.full,
                    children: [
                      cell('${e.date.day}/${e.date.month}'),
                      symptom(e.nose),
                      symptom(e.eyes),
                      symptom(e.throat),
                      symptom(e.breath),
                      cell(e.badSleep ? 'disturbato' : '', center: true),
                      cell(e.meds.join(', ')),
                      for (final a in allergens) pollen(e.pollen[a.id]),
                      cell(e.note),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 10),
          pw.Wrap(
            runSpacing: 4,
            children: [
              small('Sintomi:  '),
              for (var i = 0; i < 4; i++) swatch(palette.symFill[i], '$i ${_symptom[i]}'),
            ],
          ),
          if (allergens.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Wrap(
              runSpacing: 4,
              children: [
                small('Pollini:  '),
                for (final l in Level.values) swatch(palette.riskFill[l.index], l.label.toLowerCase()),
              ],
            ),
          ],
          pw.SizedBox(height: 10),
          small(
            'Intensità: il sintomo peggiore del giorno, da 0 a 3. Pollini: previsione Open-Meteo (CAMS), '
            'misure POLLnet-ISPRA o media storica del mese. I confronti sono correlazioni, non diagnosi.',
          ),
        ],
      ),
    );
    return doc.save();
  }

  /// Il marchio dell'app, come `RadarPainter`, con l'asse y del PDF rivolto verso l'alto.
  static void _mark(PdfGraphics g, PdfPoint size) {
    final s = size.x / 48;
    double x(double v) => v * s;
    double y(double v) => size.y - v * s;
    const stroke = 3.4;
    g
      ..setStrokeColor(_pine)
      ..setFillColor(_pine)
      ..setLineWidth(stroke * s)
      ..setLineCap(PdfLineCap.round)
      ..drawEllipse(x(24), y(24), x(20 - stroke / 2), x(20 - stroke / 2))
      ..strokePath()
      ..drawEllipse(x(24), y(24), x(11), x(11))
      ..strokePath()
      ..moveTo(x(24), y(24))
      ..lineTo(x(34.2), y(13.8))
      ..strokePath()
      ..drawEllipse(x(24), y(24), x(3.5), x(3.5))
      ..fillPath()
      ..drawEllipse(x(11.3), y(31.4), x(1.8), x(1.8))
      ..fillPath();
  }
}
