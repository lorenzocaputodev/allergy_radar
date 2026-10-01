import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/alert_log.dart';
import '../models/diary_entry.dart';
import '../services/alert_planner.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import 'alerts_screen.dart';
import 'log_entry_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static IconData iconOf(AlertKind k) => switch (k) {
    AlertKind.briefing => Icons.wb_sunny_outlined,
    AlertKind.tomorrow => Icons.trending_up,
    AlertKind.diary => Icons.book_outlined,
  };

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // Un avviso può arrivare mentre la schermata è aperta: si rilegge quando l'app torna in primo piano.
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
    final p = context.palette;
    final alertsOn = context.select<AppState, bool>((s) => s.alerts.anyEnabled);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Avvisi ricevuti'),
        actions: [
          IconButton(
            tooltip: 'Impostazioni degli avvisi',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlertsScreen()));
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: FutureBuilder<SharedPreferences>(
        future: SharedPreferences.getInstance(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final now = DateTime.now();
          final log = AlertLog.read(snap.data!, now);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (!alertsOn)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: p.chip,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      leading: const Icon(Icons.notifications_off_outlined),
                      title: const Text('Avvisi spenti'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AlertsScreen())),
                    ),
                  ),
                ),
              if (log.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.notifications_none, size: 40, color: p.ink3),
                      const SizedBox(height: 12),
                      Text('Nessun avviso, per ora', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 6),
                      Text('Qui trovi quelli che ti arrivano.', style: TextStyle(color: p.ink2)),
                    ],
                  ),
                ),
              for (final (i, e) in log.indexed) ...[
                if (i == 0 || !_sameDay(log[i - 1].at, e.at))
                  Padding(
                    padding: EdgeInsets.fromLTRB(4, i == 0 ? 4 : 16, 4, 8),
                    child: Text(
                      _dayLabel(e.at, now).toUpperCase(),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.ink3),
                    ),
                  ),
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: p.card,
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: p.line),
                  ),
                  child: InkWell(
                    onTap: () => _open(e),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(NotificationsScreen.iconOf(e.kind), color: p.pineText, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        e.title,
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    Text(Fmt.time(e.at), style: TextStyle(fontSize: 12, color: p.ink3)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(e.body, style: TextStyle(fontSize: 14, height: 1.4, color: p.ink2)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: p.ink3),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Il promemoria apre il diario di quel giorno; gli avvisi sui pollini riportano a Oggi.
  void _open(AlertMessage m) {
    final nav = Navigator.of(context);
    if (m.kind == AlertKind.diary) {
      nav.push(
        MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: DiaryEntry.day(m.at)), fullscreenDialog: true),
      );
    } else {
      nav.popUntil((r) => r.isFirst);
    }
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dayLabel(DateTime d, DateTime now) {
    if (_sameDay(d, now)) return 'Oggi';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Ieri';
    return Fmt.longDate(d);
  }
}
