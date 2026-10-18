import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../models/place_index.dart';
import '../services/location_service.dart';
import '../services/open_meteo_client.dart';
import '../theme/palette.dart';

class PlaceSearch extends StatefulWidget {
  const PlaceSearch({super.key, required this.onSelected, this.selected, this.showLocate = true, this.forward});

  final void Function(Place) onSelected;
  final Place? selected;
  final bool showLocate;
  final ForwardGeocoder? forward;

  @override
  State<PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<PlaceSearch> {
  static const _maxResults = 10;

  Timer? _debounce;
  List<Place> _local = const [];
  List<Place> _online = const [];
  String? _error;
  bool _loading = false;
  bool _searched = false;
  bool _locating = false;
  int _query = 0;

  Place? _found;

  PlaceIndex get _index => context.read<PlaceIndex>();

  List<Place> get _results {
    final seen = <String>{};
    return [
      for (final p in [..._local, ..._online])
        if (seen.add('${PlaceIndex.normalize(p.name)}|${PlaceIndex.normalize(p.region ?? '')}') && seen.add(p.cacheKey))
          p,
    ].take(_maxResults).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String text) {
    final query = ++_query;
    final q = text.trim();
    _debounce?.cancel();
    setState(() {
      _local = _index.search(q);
      _online = const [];
      _error = null;
      _searched = false;
      _loading = q.length >= 2;
    });
    if (q.length >= 2) _debounce = Timer(const Duration(milliseconds: 300), () => _search(q, query));
  }

  Future<void> _search(String q, int query) async {
    bool current() => mounted && query == _query;
    var online = const <Place>[];
    var failed = false;
    try {
      online = await context.read<OpenMeteoClient>().searchPlaces(q);
    } on Object {
      if (current() && _local.isEmpty) {
        try {
          online = await LocationService.searchByGeocoder(q, _index, forward: widget.forward);
        } on Object {
          failed = true;
        }
      }
    }
    if (!current()) return;
    setState(() {
      _online = online;
      _loading = false;
      _searched = true;
      _error = failed && _local.isEmpty ? 'Ricerca non riuscita. Controlla la connessione.' : null;
    });
  }

  Future<void> _useLocation() async {
    setState(() {
      _locating = true;
      _error = null;
      _found = null;
    });
    try {
      final place = await LocationService.current(
        index: _index,
        renamed: (p) {
          if (!mounted || _found?.cacheKey != p.cacheKey) return;
          setState(() => _found = p);
          widget.onSelected(p);
        },
      );
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
    final results = _results;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showLocate) ...[
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
        ],
        TextField(
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
        if (_searched && !_loading && _error == null && results.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Nessun luogo trovato. Prova con il nome del comune.', style: TextStyle(color: p.ink2)),
          ),
        for (final r in results)
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: r.region == null ? null : Text(r.region!),
            trailing: r.cacheKey == widget.selected?.cacheKey ? Icon(Icons.check, color: p.pineText) : null,
            onTap: () {
              setState(() => _found = null);
              widget.onSelected(r);
            },
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
              'Per i pollini usiamo solo la zona, arrotondata a circa 1 km. Se usi la tua posizione, il nome del comune lo '
              'trova il servizio di localizzazione di Android, che può inviare le coordinate a Google; se tarda, l’elenco dei '
              'comuni incluso nell’app.',
              style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2),
            ),
          ),
        ],
      ),
    );
  }
}
