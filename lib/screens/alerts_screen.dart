import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_settings.dart';
import '../models/diary_entry.dart';
import '../services/alert_planner.dart';
import '../services/alerts_service.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../widgets/page_list.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => setState(() {}));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final diary = context.watch<DiaryState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Avvisi')),
      body: PageList(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AlertSettingsEditor(
            value: state.alerts,
            notes: _notes(state, diary, DateTime.now()),
            onChanged: (a) async {
              if (a.anyEnabled && !state.alerts.anyEnabled) await AlertsService.requestPermission();
              await state.setAlerts(a);
            },
          ),
          const SizedBox(height: 16),
          const _Check(),
        ],
      ),
    );
  }

  static Map<AlertKind, String> _notes(AppState app, DiaryState diary, DateTime now) {
    final diaryDone = diary.entryFor(DiaryEntry.day(now)) != null;
    final planned = {
      for (final m in const AlertPlanner().schedule(
        now: now,
        settings: app.alerts,
        placeName: app.place.name,
        followed: app.followedStatuses,
        thresholdOf: app.thresholdOf,
        diaryDoneToday: diaryDone,
      ))
        m.kind: m.at,
    };
    String next(DateTime at) =>
        '${DiaryEntry.day(at) == DiaryEntry.day(now) ? 'oggi' : 'domani'} alle ${AlertSettingsEditor.time(at.hour * 60 + at.minute)}';
    final briefing = planned[AlertKind.briefing];
    final tomorrow = planned[AlertKind.tomorrow];
    final reminder = planned[AlertKind.diary];
    return {
      AlertKind.briefing: briefing == null
          ? 'Niente in programma: nessun allergene ti darà fastidio.'
          : 'Prossimo: ${next(briefing)}',
      AlertKind.tomorrow: tomorrow == null
          ? 'Niente in programma: domani nessun allergene ti darà fastidio.'
          : 'Prossimo: ${next(tomorrow)}',
      if (reminder != null)
        AlertKind.diary: diaryDone && DiaryEntry.day(reminder) != DiaryEntry.day(now)
            ? 'Oggi hai già registrato: prossimo ${next(reminder)}'
            : 'Prossimo: ${next(reminder)}',
    };
  }
}

class AlertSettingsEditor extends StatelessWidget {
  const AlertSettingsEditor({super.key, required this.value, required this.onChanged, this.notes = const {}});

  final AlertSettings value;
  final void Function(AlertSettings) onChanged;

  final Map<AlertKind, String> notes;

  static const _switchWidth = 52.0;

  static String time(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    Future<void> pick(int current, void Function(int) set) async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        helpText: 'Scegli l’ora',
      );
      if (t != null) set(t.hour * 60 + t.minute);
    }

    Widget block({
      required IconData icon,
      required String title,
      required String subtitle,
      required bool on,
      required void Function(bool) toggle,
      int? at,
      void Function(int)? setAt,
      String? note,
      Widget? extra,
    }) => Column(
      children: [
        SwitchListTile(
          secondary: Icon(icon),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(subtitle),
          value: on,
          onChanged: toggle,
        ),
        if (on && at != null)
          ListTile(
            leading: const SizedBox(width: 24),
            title: Text('Ora', style: TextStyle(fontSize: 15, color: p.ink2)),
            subtitle: note == null ? null : Text(note, style: TextStyle(fontSize: 13, color: p.ink3)),
            trailing: SizedBox(
              width: _switchWidth,
              child: Text(
                time(at),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            onTap: () => pick(at, setAt!),
          ),
        if (on && extra != null) extra,
      ],
    );

    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          block(
            icon: Icons.wb_sunny_outlined,
            title: 'Pollini di oggi',
            subtitle: 'La mattina, cosa ti dà fastidio oggi.',
            on: value.briefing,
            toggle: (v) => onChanged(value.copyWith(briefing: v)),
            at: value.briefingAt,
            setAt: (m) => onChanged(value.copyWith(briefingAt: m)),
            note: notes[AlertKind.briefing],
            extra: SwitchListTile(
              secondary: const SizedBox(width: 24),
              title: Text('Solo se qualcosa ti dà fastidio', style: TextStyle(fontSize: 15, color: p.ink2)),
              value: value.briefingOnlyAbove,
              onChanged: (v) => onChanged(value.copyWith(briefingOnlyAbove: v)),
            ),
          ),
          const Divider(),
          block(
            icon: Icons.trending_up,
            title: 'Allerta per domani',
            subtitle: 'La sera, se domani un tuo allergene ti darà fastidio.',
            on: value.tomorrow,
            toggle: (v) => onChanged(value.copyWith(tomorrow: v)),
            at: value.tomorrowAt,
            setAt: (m) => onChanged(value.copyWith(tomorrowAt: m)),
            note: notes[AlertKind.tomorrow],
          ),
          const Divider(),
          block(
            icon: Icons.book_outlined,
            title: 'Promemoria diario',
            subtitle: 'Solo se oggi non hai ancora registrato.',
            on: value.diary,
            toggle: (v) => onChanged(value.copyWith(diary: v)),
            at: value.diaryAt,
            setAt: (m) => onChanged(value.copyWith(diaryAt: m)),
            note: notes[AlertKind.diary],
          ),
        ],
      ),
    );
  }
}

class _Check extends StatefulWidget {
  const _Check();

  @override
  State<_Check> createState() => _CheckState();
}

class _CheckState extends State<_Check> {
  late Future<(bool, bool)> _status = _read();
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => setState(() => _status = _read()));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  static Future<(bool, bool)> _read() async => (await AlertsService.enabled(), await AlertsService.exact());

  Future<void> _test() async {
    final sent = await AlertsService.sendTest();
    if (!mounted || sent) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le notifiche dell’app sono spente.')));
  }

  Future<void> _makeExact() async {
    final app = context.read<AppState>();
    final diary = context.read<DiaryState>();
    if (await AlertsService.requestExact()) {
      await AlertsService.reschedule(await SharedPreferences.getInstance(), app, diary);
    }
    if (mounted) setState(() => _status = _read());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return FutureBuilder<(bool, bool)>(
      future: _status,
      builder: (context, snap) {
        final (enabled, exact) = snap.data ?? (true, true);
        final off = AlertsService.isSupported && !enabled;
        final delayed = AlertsService.isSupported && enabled && !exact;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(off ? Icons.notifications_off_outlined : Icons.schedule, color: p.ink2, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      off
                          ? 'Le notifiche dell’app sono spente: riattivale da Impostazioni › App › Allergy Radar.'
                          : delayed
                          ? 'Possono arrivare fino a un’ora in ritardo.'
                          : 'Arrivano all’orario scelto, anche ad app chiusa.',
                      style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2),
                    ),
                  ),
                ],
              ),
              if (AlertsService.isSupported && !off) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (delayed)
                      FilledButton.tonalIcon(
                        onPressed: _makeExact,
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                        icon: const Icon(Icons.alarm_on, size: 18),
                        label: const Text('Falli arrivare in orario'),
                      ),
                    OutlinedButton.icon(
                      onPressed: _test,
                      icon: const Icon(Icons.notifications_active_outlined, size: 18),
                      label: const Text('Avviso di prova'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
