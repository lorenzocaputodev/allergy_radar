import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../state/diary_state.dart';
import '../utils/format.dart';

/// PDF da portare all'allergologo: diario, farmaci e pollini di un periodo.
class ReportPdf {
  static const days = 90;

  static const _ink = PdfColor.fromInt(0xFF17201C);
  static const _muted = PdfColor.fromInt(0xFF5C6661);
  static const _line = PdfColor.fromInt(0xFFE2DED3);
  static const _pine = PdfColor.fromInt(0xFF1F5A4A);
  static const _symptom = ['–', 'lieve', 'medio', 'forte'];

  static Future<Uint8List> build({
    required DiaryState diary,
    required List<Allergen> allergens,
    required String placeName,
    required DateTime now,
  }) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-400.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Figtree-700.ttf'));
    final from = DiaryEntry.day(now).subtract(const Duration(days: days - 1));
    final entries = diary.between(from, now);
    final medDays = <String, int>{};
    for (final e in entries) {
      for (final m in e.meds) {
        medDays[m] = (medDays[m] ?? 0) + 1;
      }
    }
    final avg = entries.isEmpty ? null : entries.fold<double>(0, (s, e) => s + e.score) / entries.length;

    pw.Widget label(String s) => pw.Text(s, style: const pw.TextStyle(fontSize: 9, color: _muted));
    pw.Widget para(String s) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Text(s, style: const pw.TextStyle(fontSize: 10, lineSpacing: 2)),
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
            label('Allergy Radar · l’app informa, non sostituisce il medico'),
            label('Pagina ${ctx.pageNumber} di ${ctx.pagesCount}'),
          ],
        ),
        build: (ctx) => [
          pw.Text(
            'Diario dei sintomi',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: _pine),
          ),
          pw.SizedBox(height: 4),
          label(
            '${Fmt.shortDate(from)} ${from.year} – ${Fmt.shortDate(now)} ${now.year} · $placeName · '
            'generato il ${Fmt.longDate(now).toLowerCase()}',
          ),
          pw.SizedBox(height: 16),
          pw.Text('Riepilogo', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          para('Giorni registrati: ${entries.length} su $days.'),
          if (avg != null) para('Intensità media dei sintomi (sintomo peggiore del giorno, 0–3): ${Fmt.number(avg)}.'),
          para(
            'Farmaci: ${medDays.isEmpty ? 'nessuno registrato' : medDays.entries.map((e) => '${e.key} ${e.value} giorni').join(', ')}.',
          ),
          para('Allergeni seguiti: ${allergens.map((a) => a.name).join(', ')}.'),
          for (final a in allergens)
            if (diary.insight(a, now, days: days) case final i?)
              para(
                '${a.name}: sintomi medi ${Fmt.number(i.highMean)} nei giorni da moderato in su '
                '(${i.highDays}), ${Fmt.number(i.lowMean)} negli altri (${i.lowDays}).',
              ),
          pw.SizedBox(height: 14),
          pw.Text('Giorno per giorno', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          if (entries.isEmpty)
            para('Nessuna voce nel periodo.')
          else
            pw.TableHelper.fromTextArray(
              headers: ['Data', 'Naso', 'Occhi', 'Gola', 'Respiro', 'Sonno', 'Farmaci', 'Pollini', 'Nota'],
              data: [
                for (final e in entries)
                  [
                    '${e.date.day}/${e.date.month}',
                    _symptom[e.nose],
                    _symptom[e.eyes],
                    _symptom[e.throat],
                    _symptom[e.breath],
                    e.badSleep ? 'disturbato' : '',
                    e.meds.join(', '),
                    [
                      for (final a in allergens)
                        if (e.pollen[a.id] case final l?) '${a.name} ${Level.fromIndex(l).label.toLowerCase()}',
                    ].join(', '),
                    e.note,
                  ],
              ],
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: _pine),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
              border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
              columnWidths: {
                0: const pw.FixedColumnWidth(34),
                6: const pw.FlexColumnWidth(2),
                7: const pw.FlexColumnWidth(3),
                8: const pw.FlexColumnWidth(3),
              },
            ),
          pw.SizedBox(height: 14),
          label(
            'Livelli dei pollini: previsione Open-Meteo (CAMS), misure POLLnet-ISPRA o media storica del mese. '
            'I confronti sono correlazioni, non diagnosi.',
          ),
        ],
      ),
    );
    return doc.save();
  }
}
