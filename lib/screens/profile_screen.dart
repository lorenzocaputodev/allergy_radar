import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/station.dart';
import '../services/backup.dart';
import '../services/file_service.dart';
import '../services/report_pdf.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../widgets/settings_group.dart';
import 'alerts_screen.dart';
import 'allergens_screen.dart';
import 'info_screen.dart';
import 'medications_screen.dart';
import 'place_search_screen.dart';

/// Indice delle impostazioni: luogo in testa, poi profilo, notifiche, dati e app.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diary = context.watch<DiaryState>();
    final p = context.palette;
    final measuring = state.snapshot?.measuringStation;
    final stationText = measuring != null
        ? 'Misure da ${measuring.station.name}, ${measuring.km.round()} km'
        : 'Nessuna stazione attiva entro ${StationDirectory.maxKm.round()} km';
    final a = state.alerts;
    final t = AlertSettingsEditor.time;
    final alertsText = [
      if (a.briefing) 'Mattino ${t(a.briefingAt)}',
      if (a.tomorrow) 'Sera ${t(a.tomorrowAt)}',
      if (a.diary) 'Diario ${t(a.diaryAt)}',
    ].join(' · ');

    void go(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

    ListTile nav(IconData icon, String title, String? subtitle, Widget screen, {int lines = 1}) => ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle, maxLines: lines, overflow: TextOverflow.ellipsis),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => go(screen),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
          child: Text('Profilo', style: Theme.of(context).textTheme.headlineMedium),
        ),
        Material(
          color: p.pineSoft,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => go(const PlaceSearchScreen()),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.place_outlined, color: p.pineText, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.place.name,
                          style: const TextStyle(
                            fontFamily: AppFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text('${state.area.label} · $stationText', style: TextStyle(fontSize: 13, color: p.ink2)),
                      ],
                    ),
                  ),
                  Text(
                    'Cambia',
                    style: TextStyle(fontWeight: FontWeight.w600, color: p.pineText),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SettingsLabel('Il tuo profilo'),
        SettingsGroup([
          nav(
            Icons.eco_outlined,
            'I miei allergeni',
            state.followedAllergens.isEmpty ? 'Nessuno' : state.followedAllergens.map((x) => x.name).join(', '),
            const AllergensScreen(),
          ),
          nav(
            Icons.medication_outlined,
            'Farmaci',
            diary.medications.isEmpty ? 'Nessuno' : diary.medications.join(', '),
            const MedicationsScreen(),
          ),
        ]),
        const SettingsLabel('Notifiche'),
        SettingsGroup([
          nav(
            Icons.notifications_outlined,
            'Avvisi',
            alertsText.isEmpty ? 'Spenti' : alertsText,
            const AlertsScreen(),
            lines: 2,
          ),
        ]),
        if (FileService.isSupported) ...[
          const SettingsLabel('I tuoi dati'),
          SettingsGroup([
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF per l’allergologo'),
              subtitle: const Text('Ultimi 90 giorni'),
              onTap: () => _exportPdf(context),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Diario in CSV'),
              onTap: () => _exportCsv(context),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Esporta backup'),
              onTap: () => _exportBackup(context),
            ),
            ListTile(
              leading: const Icon(Icons.upload_outlined),
              title: const Text('Importa backup'),
              onTap: () => _importBackup(context),
            ),
          ]),
        ],
        const SettingsLabel('App'),
        SettingsGroup([
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Tema', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
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
          ),
          nav(Icons.info_outline, 'Fonti e privacy', null, const InfoScreen()),
        ]),
        const SizedBox(height: 16),
        Text(
          'Allergy Radar · l’app informa, non sostituisce il medico',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: p.ink3),
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
  final followed = context.read<AppState>().followedAllergens;
  final now = DateTime.now();
  return _report(
    context,
    () => FileService.saveText(
      'allergy-radar-diario-${_stamp(now)}.csv',
      Backup.diaryCsv(diary.entries, followed: followed),
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
    if (context.mounted) _toast(context, 'Backup importato: $entries giorni di diario.');
    await state.refresh();
  } on FormatException catch (e) {
    if (context.mounted) _toast(context, e.message);
  } on Object {
    if (context.mounted) _toast(context, 'Importazione non riuscita.');
  }
}
