import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/level.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/level_widgets.dart';
import '../widgets/settings_group.dart';
import 'allergen_detail_screen.dart';

class AllergensScreen extends StatelessWidget {
  const AllergensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final followed = state.followedAllergens;
    final others = Allergens.all.where((a) => !state.followed.contains(a.id)).toList();

    Widget row(Allergen a) {
      final on = state.followed.contains(a.id);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: AllergenGlyph(a, size: 40),
            title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(a.hasForecast ? 'Previsione giornaliera' : 'Misura o stima'),
            trailing: Switch(value: on, onChanged: (v) => state.setFollowed(a, v)),
            onTap: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => AllergenDetailScreen(allergenId: a.id))),
          ),
          if (on)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Mi dà fastidio da', style: TextStyle(fontSize: 13, color: p.ink2)),
                  const SizedBox(height: 6),
                  SegmentedButton<Level>(
                    segments: const [
                      ButtonSegment(value: Level.low, label: Text('Basso')),
                      ButtonSegment(value: Level.moderate, label: Text('Moderato')),
                      ButtonSegment(value: Level.high, label: Text('Alto')),
                    ],
                    selected: {state.thresholdOf(a)},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => state.setThreshold(a, v.first),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('I miei allergeni')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Text(
              'La soglia decide quando un allergene conta per la tua giornata e per gli avvisi.',
              style: TextStyle(fontSize: 14, height: 1.4, color: p.ink2),
            ),
          ),
          if (followed.isNotEmpty) ...[
            const SettingsLabel('Seguiti'),
            SettingsGroup([for (final a in followed) row(a)]),
          ],
          if (others.isNotEmpty) ...[
            const SettingsLabel('Altri'),
            SettingsGroup([for (final a in others) row(a)]),
          ],
        ],
      ),
    );
  }
}
