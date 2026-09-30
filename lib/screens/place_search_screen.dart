import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/place.dart';
import '../services/open_meteo_client.dart';
import '../state/app_state.dart';
import '../theme/palette.dart';

class PlaceSearchScreen extends StatefulWidget {
  const PlaceSearchScreen({super.key});

  @override
  State<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  Timer? _debounce;
  List<Place> _results = const [];
  String? _error;
  bool _loading = false;

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
      if (mounted) setState(() => _results = r);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final current = context.watch<AppState>().place;
    return Scaffold(
      appBar: AppBar(title: const Text('Luogo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Cerca una città',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _loading ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2)) : null,
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: p.line)),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          for (final r in _results)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: r.region == null ? null : Text(r.region!),
              trailing: r.cacheKey == current.cacheKey ? Icon(Icons.check, color: p.pineText) : null,
              onTap: () {
                context.read<AppState>().setPlace(r);
                Navigator.of(context).pop();
              },
            ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: p.chip, borderRadius: BorderRadius.circular(16)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: p.ink2, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Le previsioni coprono un’area di circa 11 km. A Open-Meteo inviamo solo coordinate arrotondate a circa 1 km, a ISPRA solo il codice della stazione.',
                    style: TextStyle(fontSize: 13, height: 1.45, color: p.ink2),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
