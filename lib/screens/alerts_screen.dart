import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/alert_settings.dart';
import '../services/alerts_service.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Avvisi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          AlertSettingsEditor(
            value: state.alerts,
            onChanged: (a) async {
              if (a.anyEnabled && !state.alerts.anyEnabled) await AlertsService.requestPermission();
              await state.setAlerts(a);
              await AlertsService.sync(a);
            },
          ),
          const SizedBox(height: 16),
          const _BatteryNote(),
        ],
      ),
    );
  }
}

/// Interruttori e orari degli avvisi. Usato anche nel primo avvio.
class AlertSettingsEditor extends StatelessWidget {
  const AlertSettingsEditor({super.key, required this.value, required this.onChanged});

  final AlertSettings value;
  final void Function(AlertSettings) onChanged;

  /// Larghezza di un interruttore Material 3: l'ora si centra sotto di lui.
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
            title: 'Briefing del mattino',
            subtitle: 'I livelli di oggi dei tuoi allergeni.',
            on: value.briefing,
            toggle: (v) => onChanged(value.copyWith(briefing: v)),
            at: value.briefingAt,
            setAt: (m) => onChanged(value.copyWith(briefingAt: m)),
            extra: SwitchListTile(
              secondary: const SizedBox(width: 24),
              title: Text('Solo nei giorni sopra la tua soglia', style: TextStyle(fontSize: 15, color: p.ink2)),
              value: value.briefingOnlyAbove,
              onChanged: (v) => onChanged(value.copyWith(briefingOnlyAbove: v)),
            ),
          ),
          const Divider(),
          block(
            icon: Icons.trending_up,
            title: 'Domani peggiora',
            subtitle: 'La sera, se domani un tuo allergene sale sopra soglia.',
            on: value.tomorrow,
            toggle: (v) => onChanged(value.copyWith(tomorrow: v)),
            at: value.tomorrowAt,
            setAt: (m) => onChanged(value.copyWith(tomorrowAt: m)),
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
          ),
        ],
      ),
    );
  }
}

class _BatteryNote extends StatelessWidget {
  const _BatteryNote();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.battery_alert_outlined, color: p.ink2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Possono arrivare con qualche minuto di ritardo. Se non arrivano, togli l’app dal risparmio batteria.',
              style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
