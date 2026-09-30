import 'package:flutter/material.dart';

import 'area.dart';
import 'level.dart';

export 'area.dart';

enum DataKind { forecast, measured, estimate }

class Allergen {
  const Allergen({
    required this.id,
    required this.name,
    required this.family,
    required this.icon,
    required this.pollnetId,
    required this.thresholds,
    required this.calendar,
    this.openMeteoKeys = const [],
  });

  final String id;
  final String name;
  final String family;
  final IconData icon;

  /// Variabili orarie di Open-Meteo; vuoto se il modello non lo calcola.
  final List<String> openMeteoKeys;

  /// PART_ID della banca dati POLLnet (ISPRA).
  final int pollnetId;

  final Thresholds thresholds;

  /// Livello tipico per mese (0–3), da gennaio a dicembre, per area: mediana delle medie
  /// mensili delle stazioni POLLnet dell'area, 2016–2025. Si rigenera con tool/build_calendar.mjs.
  final Map<Area, List<int>> calendar;

  List<int> calendarFor(Area area) => calendar[area]!;

  bool get hasForecast => openMeteoKeys.isNotEmpty;
}

abstract final class Allergens {
  static const grass = Allergen(
    id: 'grass',
    name: 'Graminacee',
    family: 'Poacee',
    icon: Icons.grass,
    openMeteoKeys: ['grass_pollen'],
    pollnetId: 1352,
    thresholds: Thresholds(0.5, 10, 30),
    calendar: {
      Area.north: [0, 0, 1, 3, 3, 3, 2, 1, 1, 1, 0, 0],
      Area.centre: [0, 0, 1, 2, 3, 3, 2, 1, 1, 1, 0, 0],
      Area.south: [0, 1, 1, 2, 3, 2, 1, 1, 1, 1, 1, 0],
    },
  );

  static const parietaria = Allergen(
    id: 'parietaria',
    name: 'Parietaria',
    family: 'Urticacee',
    icon: Icons.local_florist_outlined,
    pollnetId: 1362,
    thresholds: Thresholds(2, 20, 70),
    calendar: {
      Area.north: [0, 0, 0, 2, 2, 2, 2, 2, 2, 1, 0, 0],
      Area.centre: [0, 1, 1, 2, 2, 2, 2, 2, 1, 1, 1, 0],
      Area.south: [1, 2, 2, 3, 3, 2, 2, 1, 1, 1, 1, 1],
    },
  );

  static const olive = Allergen(
    id: 'olive',
    name: 'Olivo',
    family: 'Oleacee',
    icon: Icons.eco_outlined,
    openMeteoKeys: ['olive_pollen'],
    pollnetId: 1391,
    thresholds: Thresholds(0.5, 5, 25),
    calendar: {
      Area.north: [0, 0, 0, 1, 2, 2, 0, 0, 0, 0, 0, 0],
      Area.centre: [0, 0, 0, 1, 3, 3, 1, 0, 0, 0, 0, 0],
      Area.south: [0, 0, 0, 2, 3, 3, 1, 0, 0, 0, 0, 0],
    },
  );

  static const cypress = Allergen(
    id: 'cypress',
    name: 'Cipresso',
    family: 'Cupressacee',
    icon: Icons.park_outlined,
    pollnetId: 1330,
    thresholds: Thresholds(4, 30, 90),
    calendar: {
      Area.north: [1, 3, 3, 2, 1, 1, 0, 0, 0, 0, 0, 0],
      Area.centre: [2, 3, 3, 3, 1, 1, 0, 0, 0, 0, 0, 1],
      Area.south: [1, 3, 3, 2, 1, 0, 0, 0, 0, 0, 1, 1],
    },
  );

  static const oak = Allergen(
    id: 'oak',
    name: 'Quercia',
    family: 'Fagacee',
    icon: Icons.nature_outlined,
    pollnetId: 1384,
    thresholds: Thresholds(1, 20, 40),
    calendar: {
      Area.north: [0, 0, 1, 3, 2, 1, 0, 0, 0, 0, 0, 0],
      Area.centre: [0, 0, 1, 3, 3, 3, 1, 0, 0, 0, 0, 0],
      Area.south: [0, 0, 1, 3, 3, 1, 1, 0, 0, 0, 0, 0],
    },
  );

  static const plantago = Allergen(
    id: 'plantago',
    name: 'Piantaggine',
    family: 'Plantaginacee',
    icon: Icons.grain,
    pollnetId: 1350,
    thresholds: Thresholds(0.1, 0.4, 2),
    calendar: {
      Area.north: [0, 0, 0, 1, 3, 3, 3, 3, 2, 0, 0, 0],
      Area.centre: [0, 0, 1, 2, 3, 3, 3, 3, 2, 1, 0, 0],
      Area.south: [0, 0, 2, 3, 3, 3, 3, 2, 2, 1, 0, 0],
    },
  );

  static const mugwort = Allergen(
    id: 'mugwort',
    name: 'Artemisia',
    family: 'Composite',
    icon: Icons.filter_vintage_outlined,
    openMeteoKeys: ['mugwort_pollen'],
    pollnetId: 1379,
    thresholds: Thresholds(0.1, 5, 25),
    calendar: {
      Area.north: [0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0],
      Area.centre: [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0],
      Area.south: [0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0],
    },
  );

  static const ragweed = Allergen(
    id: 'ragweed',
    name: 'Ambrosia',
    family: 'Composite',
    icon: Icons.spa_outlined,
    openMeteoKeys: ['ragweed_pollen'],
    pollnetId: 1378,
    thresholds: Thresholds(0.1, 5, 25),
    calendar: {
      Area.north: [0, 0, 0, 0, 0, 0, 1, 2, 2, 1, 0, 0],
      Area.centre: [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
      Area.south: [0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0],
    },
  );

  static const birch = Allergen(
    id: 'birch',
    name: 'Betulla e ontano',
    family: 'Betulacee',
    icon: Icons.forest_outlined,
    openMeteoKeys: ['birch_pollen', 'alder_pollen'],
    pollnetId: 1323,
    thresholds: Thresholds(0.5, 16, 50),
    calendar: {
      Area.north: [1, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 0],
      Area.centre: [1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0],
      Area.south: [0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    },
  );

  static const alternaria = Allergen(
    id: 'alternaria',
    name: 'Alternaria',
    family: 'Muffa',
    icon: Icons.bubble_chart_outlined,
    pollnetId: 1364,
    thresholds: Thresholds(1, 10, 100),
    calendar: {
      Area.north: [1, 1, 1, 2, 2, 3, 3, 3, 3, 3, 2, 1],
      Area.centre: [1, 1, 1, 1, 2, 3, 3, 3, 3, 2, 2, 1],
      Area.south: [1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1],
    },
  );

  static const all = [grass, parietaria, olive, cypress, oak, plantago, mugwort, ragweed, birch, alternaria];

  static Allergen? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Iterable<String> get openMeteoKeys => all.expand((a) => a.openMeteoKeys);

  static Iterable<Allergen> get measuredOnly => all.where((a) => !a.hasForecast);
}
