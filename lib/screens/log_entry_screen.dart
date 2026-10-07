import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/diary_entry.dart';
import '../models/level.dart';
import '../state/app_state.dart';
import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../utils/format.dart';
import '../widgets/page_list.dart';

class LogEntryScreen extends StatefulWidget {
  const LogEntryScreen({super.key, required this.date});

  final DateTime date;

  @override
  State<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends State<LogEntryScreen> {
  late DiaryEntry _entry;
  late final TextEditingController _note;
  late final bool _existing;

  @override
  void initState() {
    super.initState();
    final saved = context.read<DiaryState>().entryFor(widget.date);
    _existing = saved != null;
    _entry = saved ?? DiaryEntry(date: DiaryEntry.day(widget.date));
    _note = TextEditingController(text: _entry.note);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _isToday => DiaryEntry.day(widget.date) == DiaryEntry.day(DateTime.now());

  Map<String, int> _pollenNow() {
    final snap = context.read<AppState>().snapshot;
    if (!_isToday || snap == null) return _entry.pollen;
    return snap.levelsOn(DiaryEntry.day(widget.date));
  }

  Future<void> _save({bool noSymptoms = false}) async {
    final base = noSymptoms ? DiaryEntry(date: _entry.date, meds: _entry.meds) : _entry;
    final e = base.copyWith(note: _note.text.trim(), pollen: _pollenNow());
    await context.read<DiaryState>().save(e);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare la voce?'),
        content: Text('Sintomi e note di ${Fmt.longDate(_entry.date).toLowerCase()} vanno persi.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Elimina')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<DiaryState>().delete(_entry.date);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final diary = context.watch<DiaryState>();
    final snap = context.watch<AppState>().snapshot;
    final followed = context.watch<AppState>().followedAllergens;

    Widget symptom(String title, String hint, IconData icon, int value, void Function(int) set) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, color: p.ink2, size: 22),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                hint,
                style: TextStyle(fontSize: 13, color: p.ink3),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('No')),
            ButtonSegment(value: 1, label: Text('Lieve')),
            ButtonSegment(value: 2, label: Text('Medio')),
            ButtonSegment(value: 3, label: Text('Forte')),
          ],
          selected: {value},
          showSelectedIcon: false,
          onSelectionChanged: (v) => setState(() => set(v.first)),
        ),
      ],
    );

    final pollenLine = _isToday && snap != null
        ? followed.where((a) => snap[a.id] != null).map((a) => (a, snap[a.id]!.level)).toList()
        : [
            for (final e in _entry.pollen.entries)
              if (followed.any((a) => a.id == e.key)) (Allergens.byId(e.key)!, Level.fromIndex(e.value)),
          ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Chiudi',
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_existing)
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Elimina voce', onPressed: _delete),
          TextButton(onPressed: () => _save(noSymptoms: true), child: const Text('Nessun sintomo')),
          const SizedBox(width: 8),
        ],
      ),
      body: PageList(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _isToday ? 'Come stai oggi?' : 'Come stavi?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 14),
            child: Text(Fmt.longDate(widget.date), style: TextStyle(fontSize: 14, color: p.ink3)),
          ),
          if (pollenLine.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(14)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.eco_outlined, size: 18, color: p.ink2),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: _isToday ? 'Pollini di oggi: ' : 'Pollini di quel giorno: '),
                          for (final (i, (a, l)) in pollenLine.indexed) ...[
                            if (i > 0) const TextSpan(text: ', '),
                            TextSpan(
                              text: '${a.name}: ${l.label.toLowerCase()}',
                              style: TextStyle(fontWeight: FontWeight.w700, color: p.text(l)),
                            ),
                          ],
                        ],
                      ),
                      style: TextStyle(fontSize: 13, height: 1.4, color: p.ink2),
                    ),
                  ),
                ],
              ),
            ),
          Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: p.line),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  symptom(
                    'Naso',
                    'starnuti, naso chiuso',
                    Icons.air,
                    _entry.nose,
                    (v) => _entry = _entry.copyWith(nose: v),
                  ),
                  const SizedBox(height: 20),
                  symptom(
                    'Occhi',
                    'prurito, lacrime',
                    Icons.visibility_outlined,
                    _entry.eyes,
                    (v) => _entry = _entry.copyWith(eyes: v),
                  ),
                  const SizedBox(height: 20),
                  symptom(
                    'Gola',
                    'prurito, tosse',
                    Icons.record_voice_over_outlined,
                    _entry.throat,
                    (v) => _entry = _entry.copyWith(throat: v),
                  ),
                  const SizedBox(height: 20),
                  symptom(
                    'Respiro',
                    'fiato corto, fischi',
                    Icons.monitor_heart_outlined,
                    _entry.breath,
                    (v) => _entry = _entry.copyWith(breath: v),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ho dormito male per i sintomi', style: TextStyle(fontWeight: FontWeight.w700)),
                    value: _entry.badSleep,
                    onChanged: (v) => setState(() => _entry = _entry.copyWith(badSleep: v)),
                  ),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text('Farmaci presi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in {...diary.medications, ..._entry.meds})
                        FilterChip(
                          label: Text(m),
                          selected: _entry.meds.contains(m),
                          onSelected: (on) => setState(() {
                            _entry = _entry.copyWith(
                              meds: on ? [..._entry.meds, m] : _entry.meds.where((x) => x != m).toList(),
                            );
                          }),
                        ),
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: const Text('Aggiungi'),
                        onPressed: () async {
                          final name = await askMedication(context);
                          if (name == null || !context.mounted) return;
                          await context.read<DiaryState>().addMedication(name);
                          if (!_entry.meds.contains(name)) {
                            setState(() => _entry = _entry.copyWith(meds: [..._entry.meds, name]));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Ore all’aperto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Meno di 1')),
                      ButtonSegment(value: 1, label: Text('1–3')),
                      ButtonSegment(value: 2, label: Text('Più di 3')),
                    ],
                    selected: {if (_entry.outdoor != null) _entry.outdoor!},
                    emptySelectionAllowed: true,
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(
                      () =>
                          _entry = v.isEmpty ? _entry.copyWith(clearOutdoor: true) : _entry.copyWith(outdoor: v.first),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _note,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Nota (facoltativa)',
                      hintText: 'Es. giornata in campagna, finestre aperte…',
                      filled: true,
                      fillColor: p.bg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check), label: const Text('Salva')),
        ],
      ),
    );
  }
}

Future<String?> askMedication(BuildContext context) =>
    showDialog<String>(context: context, builder: (_) => const _MedicationDialog());

class _MedicationDialog extends StatefulWidget {
  const _MedicationDialog();

  @override
  State<_MedicationDialog> createState() => _MedicationDialogState();
}

class _MedicationDialogState extends State<_MedicationDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done() {
    final n = _name.text.trim();
    Navigator.of(context).pop(n.isEmpty ? null : n);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Nuovo farmaco'),
    content: TextField(
      controller: _name,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(hintText: 'Es. Cetirizina'),
      onSubmitted: (_) => _done(),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annulla')),
      TextButton(onPressed: _done, child: const Text('Aggiungi')),
    ],
  );
}
