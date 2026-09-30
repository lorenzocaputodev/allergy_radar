import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../widgets/level_widgets.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Fonti e privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const SectionCard(
            children: [
              _Item(
                icon: Icons.layers_outlined,
                title: 'Previsioni',
                text: 'Open-Meteo (Copernicus CAMS), per un’area di circa 11 km.',
              ),
              _Item(
                icon: Icons.sensors,
                title: 'Misure',
                text: 'Stazioni POLLnet di ISPRA entro 60 km, con qualche giorno di ritardo.',
              ),
              _Item(
                icon: Icons.calendar_month_outlined,
                title: 'Media storica',
                text: 'Se mancano previsione e misura: media del mese nella tua area, 2016–2025.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SectionCard(
            children: [
              _Item(
                icon: Icons.lock_outline,
                title: 'Privacy',
                text: 'Nessun account e nessuna pubblicità. Diario e impostazioni restano sul telefono.',
              ),
              _Item(
                icon: Icons.my_location,
                title: 'Posizione',
                text: 'Il nome del comune lo trova Android; a Open-Meteo va solo la posizione arrotondata a 1 km.',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'L’app informa, non sostituisce il medico.\n'
            'Dati © Copernicus/CAMS via Open-Meteo e POLLnet-SNPA/ISPRA, licenza CC BY 4.0.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.5, color: p.ink3),
          ),
        ],
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.title, required this.text});

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
