import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/place_search.dart';

class PlaceSearchScreen extends StatelessWidget {
  const PlaceSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final current = context.watch<AppState>().place;
    return Scaffold(
      appBar: AppBar(title: const Text('Luogo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PlaceSearch(
            autofocus: true,
            selected: current,
            onSelected: (r) {
              context.read<AppState>().setPlace(r);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 16),
          const PlacePrivacyNote(),
        ],
      ),
    );
  }
}
