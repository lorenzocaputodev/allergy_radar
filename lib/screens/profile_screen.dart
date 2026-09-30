import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/allergen.dart';
import '../models/station.dart';
import '../services/alerts_service.dart';
import '../services/backup.dart';
import '../services/file_service.dart';
import '../services/report_pdf.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../widgets/level_widgets.dart';
import 'alerts_screen.dart';
import 'allergen_detail_screen.dart';
import 'log_entry_screen.dart';
import 'place_search_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diary = context.watch<DiaryState>();
    final p = context.palette;
    final measuring = state.snapshot?.measuringStation;
    final nearest = state.snapshot?.nearestStation;
    final stationText = measuring != null
        ? 'Misure dalla stazione di ${measuring.station.name} (${measuring.km.round()} km)'
        : nearest != null
        ? 'La stazione più vicina (${nearest.station.name}, ${nearest.km.round()} km) non pubblica dati recenti'
        : 'Nessuna stazione di misura entro ${StationDirectory.maxKm.round()} km';
    final a = state.alerts;
    final t = AlertSettingsEditor.time;
    final alertsText = [
      if (a.briefing) 'briefing alle ${t(a.briefingAt)}',
      if (a.tomorrow) 'domani peggiora alle ${t(a.tomorrowAt)}',
      if (a.diary) 'diario alle ${t(a.diaryAt)}',
    ].join(', ');

    Widget label(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        s.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.ink3),
      ),
    );

    Widget group(List<Widget> rows) => Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[if (i > 0) const Divider(), rows[i]],
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
          child: Text('Profilo', style: Theme.of(context).textTheme.headlineMedium),
        ),
        label('Luogo'),
        group([
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(
              '${state.place.name} · ${state.area.label}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(stationText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlaceSearchScreen())),
          ),
        ]),
        label('I miei allergeni'),
        group([
          for (final a in Allergens.all)
            ListTile(
              leading: AllergenGlyph(a, size: 40),
              title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                state.followed.contains(a.id)
                    ? 'Soglia: ${state.thresholdOf(a).label}'
                    : (a.hasForecast ? 'Previsione giornaliera' : 'Misura di stazione o media storica'),
              ),
              trailing: Switch(value: state.followed.contains(a.id), onChanged: (v) => state.setFollowed(a, v)),
              onTap: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => AllergenDetailScreen(allergenId: a.id))),
            ),
        ]),
        label('Avvisi'),
        group([
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Avvisi', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(alertsText.isEmpty ? 'Spenti' : alertsText),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlertsScreen())),
          ),
        ]),
        label('Farmaci'),
        group([
          for (final m in diary.medications)
            ListTile(
              leading: const Icon(Icons.medication_outlined),
              title: Text(m),
              trailing: IconButton(
                tooltip: 'Rimuovi $m',
                icon: const Icon(Icons.close),
                onPressed: () => diary.removeMedication(m),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Aggiungi un farmaco'),
            onTap: () async {
              final name = await askMedication(context);
              if (name != null) await diary.addMedication(name);
            },
          ),
        ]),
        label('Aspetto'),
        SectionCard(
          children: [
            const Text('Tema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
                ButtonSegment(value: ThemeMode.light, label: Text('Chiaro')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Scuro')),
              ],
              selected: {state.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (v) => state.setThemeMode(v.first),
            ),
          ],
        ),
        if (FileService.isSupported) ...[
          label('Dati'),
          group([
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF per l’allergologo'),
              subtitle: const Text('Diario, farmaci e pollini degli ultimi 90 giorni'),
              onTap: () => _exportPdf(context),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Esporta il diario in CSV'),
              onTap: () => _exportCsv(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Esporta backup'),
              subtitle: const Text('Impostazioni e diario in un file .json'),
              onTap: () => _exportBackup(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Importa backup'),
              subtitle: const Text('Sostituisce impostazioni e diario di questo telefono'),
              onTap: () => _importBackup(context),
            ),
          ]),
        ],
        label('Fonti e privacy'),
        const SectionCard(
          children: [
            _Source(
              icon: Icons.layers_outlined,
              title: 'Previsioni',
              text:
                  'Open-Meteo, modello CAMS Europa (Copernicus). Celle di circa 11 km, oggi e i prossimi giorni. '
                  'Graminacee, olivo, ambrosia, artemisia, betulla, ontano; ozono, PM2.5, polvere.',
            ),
            _Source(
              icon: Icons.sensors,
              title: 'Misure',
              text:
                  'Rete POLLnet (ISPRA e ARPA), open data CC BY 4.0. Valori giornalieri pubblicati con alcuni giorni '
                  'di ritardo. Usiamo solo stazioni entro 60 km e misure degli ultimi 10 giorni.',
            ),
            _Source(
              icon: Icons.calendar_month_outlined,
              title: 'Media storica',
              text:
                  'Quando non c’è né previsione né misura, il livello è la media del mese nelle stazioni della tua area '
                  '(Nord, Centro o Sud e Isole, 2016–2025). È sempre indicato come stima.',
            ),
            _Source(
              icon: Icons.lock_outline,
              title: 'Privacy',
              text:
                  'Nessun account, nessuna analisi d’uso, nessun server nostro. A Open-Meteo solo coordinate '
                  'arrotondate a circa 1 km, a ISPRA solo il codice della stazione. Diario e impostazioni restano sul telefono.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Allergy Radar · L’app informa, non sostituisce il medico.\n'
          'Dati © Copernicus/CAMS via Open-Meteo (CC BY 4.0) · POLLnet-SNPA/ISPRA (CC BY 4.0).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: p.ink3),
        ),
      ],
    );
  }
}

String _stamp(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void _toast(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

Future<void> _report(BuildContext context, Future<FileResult> Function() save, String done) async {
  try {
    final r = await save();
    if (context.mounted && r == FileResult.saved) _toast(context, done);
  } on Object {
    if (context.mounted) _toast(context, 'Salvataggio non riuscito.');
  }
}

Future<void> _exportPdf(BuildContext context) {
  final state = context.read<AppState>();
  final diary = context.read<DiaryState>();
  final now = DateTime.now();
  return _report(context, () async {
    final bytes = await ReportPdf.build(
      diary: diary,
      allergens: state.followedAllergens,
      placeName: state.place.name,
      now: now,
    );
    return FileService.saveBytes('allergy-radar-diario-${_stamp(now)}.pdf', bytes, mime: 'application/pdf');
  }, 'PDF salvato.');
}

Future<void> _exportCsv(BuildContext context) {
  final diary = context.read<DiaryState>();
  final now = DateTime.now();
  return _report(
    context,
    () => FileService.saveText(
      'allergy-radar-diario-${_stamp(now)}.csv',
      Backup.diaryCsv(diary.entries),
      mime: 'text/csv',
    ),
    'CSV salvato.',
  );
}

Future<void> _exportBackup(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final now = DateTime.now();
  if (!context.mounted) return;
  return _report(
    context,
    () => FileService.saveText(
      'allergy-radar-backup-${_stamp(now)}.json',
      Backup.export(prefs, now),
      mime: 'application/json',
    ),
    'Backup salvato.',
  );
}

Future<void> _importBackup(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Importare un backup?'),
      content: const Text('Impostazioni e diario di questo telefono vengono sostituiti da quelli del file.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Importa')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final state = context.read<AppState>();
  final diary = context.read<DiaryState>();
  try {
    final json = await FileService.openText(extensions: ['json'], mimes: ['application/json']);
    if (json == null) return;
    final prefs = await SharedPreferences.getInstance();
    final entries = await Backup.restore(prefs, json);
    diary.reload();
    await state.load();
    await AlertsService.sync(state.alerts);
    if (context.mounted) _toast(context, 'Backup importato: $entries giorni di diario.');
    await state.refresh();
  } on FormatException catch (e) {
    if (context.mounted) _toast(context, e.message);
  } on Object {
    if (context.mounted) _toast(context, 'Importazione non riuscita.');
  }
}

class _Source extends StatelessWidget {
  const _Source({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: p.pineText, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2)),
            ],
          ),
        ),
      ],
    );
  }
}
