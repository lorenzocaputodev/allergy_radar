import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/allergen.dart';
import '../models/place.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/level_widgets.dart';
import '../widgets/place_search.dart';

/// Primo avvio: benvenuto, allergeni, luogo, riepilogo.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  final Set<String> _allergens = {Allergens.grass.id, Allergens.parietaria.id};
  Place? _place;

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      0 => _Welcome(onStart: _next),
      1 => _Step(
        step: 1,
        title: 'A cosa sei allergico?',
        subtitle: 'Scegli quelli che conosci o sospetti. Puoi cambiarli quando vuoi.',
        onBack: _back,
        action: FilledButton(
          onPressed: _allergens.isEmpty ? null : _next,
          child: Text(_allergens.isEmpty ? 'Scegline almeno uno' : 'Continua · ${_allergens.length} scelti'),
        ),
        children: [
          for (final a in Allergens.all)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _AllergenChoice(
                allergen: a,
                selected: _allergens.contains(a.id),
                onChanged: (on) => setState(() => on ? _allergens.add(a.id) : _allergens.remove(a.id)),
              ),
            ),
          const SizedBox(height: 4),
          const _Hint(
            icon: Icons.help_outline,
            text: 'Non ne sei sicuro? Scegli quelli che sospetti: il diario ti aiuterà a capirlo.',
          ),
        ],
      ),
      2 => _Step(
        step: 2,
        title: 'Dove vuoi seguire i pollini?',
        subtitle: 'Ci serve una zona, non il tuo indirizzo.',
        onBack: _back,
        action: FilledButton(
          onPressed: _place == null ? null : _next,
          child: Text(_place == null ? 'Scegli una città' : 'Continua con ${_place!.name}'),
        ),
        children: [
          PlaceSearch(selected: _place, onSelected: (p) => setState(() => _place = p)),
          const SizedBox(height: 16),
          const PlacePrivacyNote(),
        ],
      ),
      _ => _Step(
        step: 3,
        title: 'Tutto pronto',
        onBack: _back,
        action: FilledButton(
          onPressed: () => context.read<AppState>().completeOnboarding(_place!, _allergens),
          child: const Text('Vai a Oggi'),
        ),
        children: [_Summary(place: _place!, allergens: _allergens)],
      ),
    };
    return Scaffold(body: SafeArea(child: page));
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget point(IconData i, String title, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.pineSoft, borderRadius: BorderRadius.circular(14)),
            child: Icon(i, color: p.pineText),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: TextStyle(fontSize: 14, height: 1.45, color: p.ink2)),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            children: [
              Row(
                children: [
                  Icon(Icons.radar, size: 40, color: p.pineText),
                  const SizedBox(width: 10),
                  const Flexible(
                    child: Text(
                      'Allergy Radar',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppFonts.display, fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Sappi prima cosa c’è nell’aria.',
                style: TextStyle(fontFamily: AppFonts.display, fontSize: 40, height: 1.05, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              Text(
                'Pollini della tua zona e i tuoi sintomi, in un posto solo.',
                style: TextStyle(fontSize: 17, height: 1.45, color: p.ink2),
              ),
              const SizedBox(height: 32),
              point(
                Icons.layers_outlined,
                'Oggi e i prossimi giorni',
                '10 allergeni, con la fonte sempre in vista: previsione, misura o media storica.',
              ),
              point(
                Icons.book_outlined,
                'Un diario da 10 secondi',
                'Dopo due settimane vedi quali pollini ti danno davvero fastidio.',
              ),
              point(Icons.lock_outline, 'Senza account', 'Niente pubblicità. I tuoi dati restano sul telefono.'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: onStart, child: const Text('Inizia')),
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.step,
    required this.title,
    required this.onBack,
    required this.action,
    required this.children,
    this.subtitle,
  });

  final int step;
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final Widget action;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
          child: Row(
            children: [
              IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back), tooltip: 'Indietro'),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    for (var i = 1; i <= 3; i++) ...[
                      if (i > 1) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 5,
                          decoration: BoxDecoration(
                            color: i <= step ? p.pine : p.track,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('$step di 3', style: TextStyle(fontSize: 13, color: p.ink3)),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, style: TextStyle(fontSize: 15, height: 1.45, color: p.ink2)),
              ],
              const SizedBox(height: 18),
              ...children,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: SizedBox(width: double.infinity, child: action),
        ),
      ],
    );
  }
}

class _AllergenChoice extends StatelessWidget {
  const _AllergenChoice({required this.allergen, required this.selected, required this.onChanged});

  final Allergen allergen;
  final bool selected;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? p.pine : p.line, width: selected ? 2 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => onChanged(v ?? false),
        secondary: AllergenGlyph(allergen, size: 44),
        title: Text(allergen.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(allergen.hasForecast ? 'Previsione giornaliera' : 'Misura di stazione o media storica'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: p.ink2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2)),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.place, required this.allergens});

  final Place place;
  final Set<String> allergens;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final names = Allergens.all.where((a) => allergens.contains(a.id)).map((a) => a.name).join(', ');
    Widget row(IconData i, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(i, color: p.pineText),
          const SizedBox(width: 14),
          SizedBox(
            width: 80,
            child: Text(k, style: TextStyle(fontSize: 15, color: p.ink2)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          gap: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          children: [
            row(Icons.place_outlined, 'Zona', place.name),
            const Divider(),
            row(Icons.eco_outlined, 'Allergeni', names),
          ],
        ),
        const SizedBox(height: 14),
        const _Hint(
          icon: Icons.book_outlined,
          text:
              'Un consiglio: registra come stai ogni sera. Dopo due settimane vedrai a quale livello '
              'di polline iniziano i tuoi sintomi.',
        ),
      ],
    );
  }
}
