import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../services/location_service.dart';
import '../services/open_meteo_client.dart';
import '../theme/palette.dart';

class PlaceSearch extends StatefulWidget {
  const PlaceSearch({super.key, required this.onSelected, this.selected, this.autofocus = false});

  final void Function(Place) onSelected;
  final Place? selected;
  final bool autofocus;

  @override
  State<PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<PlaceSearch> {
  Timer? _debounce;
  List<Place> _results = const [];
  String? _error;
  bool _loading = false;
  bool _locating = false;

  Place? _found;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q.trim()));
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<OpenMeteoClient>().searchPlaces(q);
      final seen = <String>{};
      final unique = [
        for (final p in r)
          if (seen.add('${p.name}|${p.region}')) p,
      ];
      if (mounted) setState(() => _results = unique);
    } on Object {
      if (mounted) setState(() => _error = 'Ricerca non riuscita. Controlla la connessione.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useLocation() async {
    setState(() {
      _locating = true;
      _error = null;
      _found = null;
    });
    try {
      final place = await LocationService.current();
      if (!mounted) return;
      setState(() => _found = place);
      widget.onSelected(place);
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on Object {
      if (mounted) setState(() => _error = 'Posizione non disponibile. Cerca una città.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _locating ? null : _useLocation,
          icon: _locating
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.my_location),
          label: const Text('Usa la mia posizione'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: p.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        if (_found case final found?) ...[const SizedBox(height: 10), _FoundPlace(place: found)],
        const SizedBox(height: 12),
        TextField(
          autofocus: widget.autofocus,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Cerca una città',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _loading
                ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2))
                : null,
            filled: true,
            fillColor: p.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: p.line),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        for (final r in _results)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: r.region == null ? null : Text(r.region!),
            trailing: r.cacheKey == widget.selected?.cacheKey ? Icon(Icons.check, color: p.pineText) : null,
            onTap: () => widget.onSelected(r),
          ),
      ],
    );
  }
}

class _FoundPlace extends StatelessWidget {
  const _FoundPlace({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final named = place.name != LocationService.fallbackName;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(color: p.pineSoft, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: p.pineText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  named ? place.name : 'Posizione trovata',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  named ? '${place.region ?? 'Italia'} · dalla tua posizione' : 'Nome del comune non disponibile',
                  style: TextStyle(fontSize: 13, color: p.ink2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlacePrivacyNote extends StatelessWidget {
  const PlacePrivacyNote({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: p.ink2, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Usiamo solo la zona, arrotondata a circa 1 km: la tua posizione esatta non lascia il telefono.',
              style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
