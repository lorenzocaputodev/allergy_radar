import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../services/location_service.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';
import '../widgets/page_list.dart';
import '../widgets/place_search.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  bool _locating = false;
  String? _error;

  Future<void> _follow(bool on) async {
    final app = context.read<AppState>();
    if (!on) return app.stopFollowing();
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final here = await LocationService.current();
      if (!mounted) return;
      unawaited(app.startFollowing(here));
      Navigator.of(context).pop();
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) setState(() => _error = 'Posizione non disponibile. Cerca una città.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _choose(Place place) {
    unawaited(context.read<AppState>().setPlace(place));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Luogo')),
      body: PageList(
        padding: const EdgeInsets.all(16),
        children: [
          Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.line),
            ),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              secondary: _locating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(Icons.near_me_outlined, color: p.pineText),
              title: const Text('Segui la mia posizione', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                _locating ? 'Cerco la tua posizione…' : _error ?? 'Il luogo si aggiorna quando apri l’app.',
                style: TextStyle(color: _error == null ? p.ink3 : Theme.of(context).colorScheme.error),
              ),
              value: app.followLocation,
              onChanged: _locating ? null : _follow,
            ),
          ),
          if (app.saved.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
              child: Text(
                'I TUOI LUOGHI',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: p.ink3),
              ),
            ),
            Material(
              color: p.card,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: p.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final s in app.saved)
                    ListTile(
                      leading: Icon(
                        !app.followLocation && s.cacheKey == app.place.cacheKey ? Icons.check : Icons.place_outlined,
                        color: p.pineText,
                      ),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: s.region == null ? null : Text(s.region!),
                      trailing: IconButton(
                        tooltip: 'Togli ${s.name}',
                        icon: Icon(Icons.close, color: p.ink3),
                        onPressed: () => unawaited(app.forget(s)),
                      ),
                      onTap: () => _choose(s),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          PlaceSearch(showLocate: false, selected: app.followLocation ? null : app.place, onSelected: _choose),
          const SizedBox(height: 16),
          const PlacePrivacyNote(),
        ],
      ),
    );
  }
}
