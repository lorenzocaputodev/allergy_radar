import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/station.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/level_widgets.dart';
import 'allergen_detail_screen.dart';
import 'place_search_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = context.palette;
    final measuring = state.snapshot?.measuringStation;
    final nearest = state.snapshot?.nearestStation;
    final stationText = measuring != null
        ? 'Misure dalla stazione di ${measuring.station.name} (${measuring.km.round()} km)'
        : nearest != null
            ? 'La stazione più vicina (${nearest.station.name}, ${nearest.km.round()} km) non pubblica dati recenti'
            : 'Nessuna stazione di misura entro ${StationDirectory.maxKm.round()} km';

    Widget label(String s) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(s.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.ink3)),
        );

    Widget group(List<Widget> rows) => Material(
          color: p.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: p.line)),
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
            title: Text(state.place.name, style: const TextStyle(fontWeight: FontWeight.w600)),
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
                    : (a.hasForecast ? 'Previsione giornaliera' : 'Misura di stazione o stima'),
              ),
              trailing: Switch(value: state.followed.contains(a.id), onChanged: (v) => state.setFollowed(a, v)),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AllergenDetailScreen(allergenId: a.id)),
              ),
            ),
        ]),
        label('Fonti e privacy'),
        SectionCard(
          children: [
            _Source(
              icon: Icons.layers_outlined,
              title: 'Previsioni',
              text: 'Open-Meteo, modello CAMS Europa (Copernicus). Celle di circa 11 km, oggi e i prossimi giorni. '
                  'Graminacee, olivo, ambrosia, artemisia, betulla, ontano; ozono, PM2.5, polvere.',
            ),
            _Source(
              icon: Icons.sensors,
              title: 'Misure',
              text: 'Rete POLLnet (ISPRA e ARPA), open data CC BY 4.0. Valori giornalieri pubblicati con alcuni giorni di ritardo. '
                  'Usiamo solo stazioni entro 60 km e misure degli ultimi 10 giorni.',
            ),
            _Source(
              icon: Icons.calendar_month_outlined,
              title: 'Stime',
              text: 'Quando non c’è né previsione né misura, il livello viene dal calendario stagionale ed è sempre marcato come stima.',
            ),
            _Source(
              icon: Icons.lock_outline,
              title: 'Privacy',
              text: 'Nessun account, nessuna analisi d’uso. A Open-Meteo solo coordinate arrotondate a circa 1 km. Tutto il resto resta sul telefono.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Allergy Radar 0.1 · L’app informa, non sostituisce il medico.\n'
          'Dati © Copernicus/CAMS via Open-Meteo (CC BY 4.0) · POLLnet-SNPA/ISPRA (CC BY 4.0).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.5, color: p.ink3),
        ),
      ],
    );
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
