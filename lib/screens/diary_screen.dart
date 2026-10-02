import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/level_widgets.dart';
import 'log_entry_screen.dart';
import 'trend_screen.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _open(DateTime d) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => LogEntryScreen(date: d), fullscreenDialog: true));

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryState>();
    final p = context.palette;
    final now = DateTime.now();
    final today = DiaryEntry.day(now);
    final todayEntry = diary.entryFor(today);
    final isCurrentMonth = _month.year == now.year && _month.month == now.month;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 6, 4, 14),
                child: Text('Diario', style: Theme.of(context).textTheme.headlineMedium),
              ),
            ),
            IconButton(
              tooltip: 'Andamento e confronti',
              icon: const Icon(Icons.show_chart),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrendScreen())),
            ),
          ],
        ),
        _TodayCard(
          entry: todayEntry,
          onOpen: () => _open(today),
          // Con i pollini di oggi, come dalla voce completa: senza, il giorno non entra nei confronti.
          onNoSymptoms: () =>
              diary.save(DiaryEntry(date: today, pollen: context.read<AppState>().snapshot?.levels ?? const {})),
        ),
        const SizedBox(height: 14),
        SectionCard(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mese precedente',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                ),
                Expanded(
                  child: Text(
                    '${Fmt.month(_month.month)[0].toUpperCase()}${Fmt.month(_month.month).substring(1)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Mese successivo',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: isCurrentMonth
                      ? null
                      : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                ),
              ],
            ),
            _MonthGrid(month: _month, today: today, diary: diary, onTap: _open),
            const _Legend(),
          ],
        ),
        const SizedBox(height: 20),
        if (diary.entries.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text('Ultimi giorni', style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final e in diary.entries.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _EntryCard(
                entry: e,
                followed: context.watch<AppState>().followedAllergens,
                onTap: () => _open(e.date),
              ),
            ),
        ] else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.line, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.book_outlined, size: 30, color: p.ink3),
                const SizedBox(height: 10),
                Text('Il diario è vuoto', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Registra come stai ogni sera: dopo ${DiaryState.minDaysForInsight} giorni vedi il confronto con i pollini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.45, color: p.ink2),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Oggi ---
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.entry, required this.onOpen, required this.onNoSymptoms});

  final DiaryEntry? entry;
  final VoidCallback onOpen;
  final VoidCallback onNoSymptoms;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = entry;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: p.pineSoft, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            e == null ? 'Oggi non hai ancora registrato' : 'Oggi: ${DiaryEntry.symptomNames[e.severity].toLowerCase()}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            e == null ? 'Bastano 10 secondi.' : 'Puoi modificarlo quando vuoi.',
            style: TextStyle(fontSize: 14, color: p.ink2),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onOpen,
                  icon: Icon(e == null ? Icons.add : Icons.edit_outlined),
                  label: Text(e == null ? 'Registra' : 'Modifica'),
                ),
              ),
              if (e == null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onNoSymptoms,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: p.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Nessun sintomo'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// --- Calendario del mese ---
class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.today, required this.diary, required this.onTap});

  final DateTime month;
  final DateTime today;
  final DiaryState diary;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = DateTime(month.year, month.month).weekday - 1;
    final cells = <Widget>[
      for (final d in ['L', 'M', 'M', 'G', 'V', 'S', 'D'])
        Center(
          child: Text(
            d,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink3),
          ),
        ),
      for (var i = 0; i < offset; i++) const SizedBox.shrink(),
      for (var d = 1; d <= days; d++) _dayCell(context, DateTime(month.year, month.month, d)),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childAspectRatio: 1.05,
      children: cells,
    );
  }

  Widget _dayCell(BuildContext context, DateTime d) {
    final p = context.palette;
    final e = diary.entryFor(d);
    final future = d.isAfter(today);
    final isToday = d == today;
    final c = e?.severity;
    final label = e == null
        ? '${d.day}, ${future ? 'futuro' : 'non registrato'}'
        : '${d.day}, ${DiaryEntry.symptomNames[c!].toLowerCase()}';
    return Semantics(
      label: label,
      button: !future,
      excludeSemantics: true,
      child: InkWell(
        onTap: future ? null : () => onTap(d),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c == null ? null : p.symFill[c],
            borderRadius: BorderRadius.circular(10),
            border: isToday
                ? Border.all(color: p.pine, width: 2)
                : c == null && !future
                ? Border.all(color: p.line, width: 1.5)
                : null,
          ),
          child: Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              color: c != null ? p.symOnFill[c] : (future ? p.line : p.ink3),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (var i = 0; i < 4; i++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: p.symFill[i], borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 6),
              Text(DiaryEntry.severityNames[i], style: TextStyle(fontSize: 12, color: p.ink2)),
              if (i > 0) ...[const SizedBox(width: 4), SeverityDots(i, color: p.ink2, size: 6)],
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: p.ink3),
              ),
            ),
            const SizedBox(width: 6),
            Text('Non registrato', style: TextStyle(fontSize: 12, color: p.ink2)),
          ],
        ),
      ],
    );
  }
}

// --- Ultimi giorni ---
const _outdoor = ['meno di 1 ora', '1–3 ore', 'più di 3 ore'];

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.followed, required this.onTap});

  final DiaryEntry entry;

  /// Solo gli allergeni seguiti: gli altri sono salvati nella voce ma qui confonderebbero.
  final List<Allergen> followed;
  final VoidCallback onTap;

  static const _names = ['No', 'lieve', 'medio', 'forte'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final e = entry;
    final parts = [
      if (e.nose > 0) 'Naso ${_names[e.nose]}',
      if (e.eyes > 0) 'Occhi ${_names[e.eyes]}',
      if (e.throat > 0) 'Gola ${_names[e.throat]}',
      if (e.breath > 0) 'Respiro ${_names[e.breath]}',
      if (e.badSleep) 'Sonno disturbato',
    ];
    final pollen = [
      for (final a in followed)
        if (e.pollen[a.id] case final l?) '${a.name} ${Level.fromIndex(l).label.toLowerCase()}',
    ];

    Widget line(String label, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(fontWeight: FontWeight.w700, color: p.ink3),
            ),
            TextSpan(text: text),
          ],
        ),
        style: TextStyle(fontSize: 14, height: 1.35, color: p.ink2),
      ),
    );

    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      Fmt.longDate(e.date),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.symFill[e.severity], borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (e.severity > 0) ...[
                          SeverityDots(e.severity, color: p.symOnFill[e.severity]),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          DiaryEntry.symptomNames[e.severity],
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: p.symOnFill[e.severity]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              line('Sintomi', parts.isEmpty ? 'nessuno' : parts.join(' · ')),
              if (e.meds.isNotEmpty) line('Farmaci', e.meds.join(', ')),
              if (e.outdoor case final o?) line('All’aperto', _outdoor[o]),
              if (pollen.isNotEmpty) line('Pollini', pollen.join(' · ')),
              if (e.note.isNotEmpty) line('Nota', e.note),
            ],
          ),
        ),
      ),
    );
  }
}
