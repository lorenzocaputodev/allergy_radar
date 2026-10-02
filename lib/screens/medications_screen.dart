import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/diary_state.dart';
import '../theme/palette.dart';
import '../widgets/settings_group.dart';
import 'log_entry_screen.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Farmaci')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
            child: Text(
              'Compaiono nel diario, da spuntare quando li prendi.',
              style: TextStyle(fontSize: 14, color: context.palette.ink2),
            ),
          ),
          SettingsGroup([
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
        ],
      ),
    );
  }
}
