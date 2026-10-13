import 'package:flutter/material.dart';

import 'area.dart';
import 'level.dart';

export 'area.dart';

enum DataKind {
  forecast('Previsione'),
  measured('Misura'),
  estimate('Stima');

  const DataKind(this.label);

  final String label;
}

class Allergen {
  const Allergen({
    required this.id,
    required this.name,
    required this.family,
    required this.habitat,
    required this.crossReactions,
    required this.icon,
    required this.pollnetId,
    required this.thresholds,
    required this.calendar,
    this.openMeteoKeys = const [],
    this.inkPlate = false,
  });

  final String id;
  final String name;
  final String family;
  final String habitat;
  final String crossReactions;
  final IconData icon;

  final List<String> openMeteoKeys;

  final int pollnetId;

  final Thresholds thresholds;

  final Map<Area, List<int>> calendar;

  List<int> calendarFor(Area area) => calendar[area]!;

  final bool inkPlate;

  String get plate => 'assets/images/plants/$id.webp';

  bool get hasForecast => openMeteoKeys.isNotEmpty;
}

abstract final class Allergens {
  static const grass = Allergen(
    id: 'grass',
    name: 'Graminacee',
    family: 'Poacee',
    habitat: 'Prati, campi incolti e bordi delle strade.',
    crossReactions: 'Tra tutte le graminacee; a volte pomodoro, melone, anguria, kiwi e arancia.',
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
    habitat: 'Muri, ruderi e bordi delle strade, anche in città.',
    crossReactions: 'Rare con altri pollini e con i cibi.',
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
    habitat: 'Oliveti, giardini e viali, soprattutto al Centro-Sud.',
    crossReactions: 'Frassino e ligustro.',
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
    habitat: 'Viali, cimiteri e siepi; anche tuie e ginepri.',
    crossReactions: 'Tuia e ginepro; a volte pesca e agrumi.',
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
    habitat: 'Boschi di collina e parchi; il leccio anche in città e sulle coste.',
    crossReactions: 'Betulla, nocciolo e castagno.',
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
    habitat: 'Prati, bordi delle strade e terreni calpestati.',
    crossReactions: 'A volte melone.',
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
    habitat: 'Incolti, bordi delle strade e massicciate.',
    crossReactions: 'Ambrosia; sedano, carota, finocchio e alcune spezie.',
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
    habitat: 'Campi incolti e cantieri, soprattutto in Lombardia e Piemonte.',
    crossReactions: 'Artemisia; melone, anguria, banana e zucchina.',
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
    habitat: 'Betulla in parchi e montagna al Nord; ontano lungo i fiumi.',
    crossReactions: 'Nocciolo, carpino e quercia; mela, pera, pesca, ciliegia, nocciola, carota e sedano crudi.',
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

  static const hazel = Allergen(
    id: 'hazel',
    name: 'Nocciolo e carpino',
    family: 'Corilacee',
    habitat: 'Noccioleti, siepi e boschi; il carpino nero in collina.',
    crossReactions: 'Betulla e ontano; nocciola e mela.',
    icon: Icons.eco,
    pollnetId: 1329,
    thresholds: Thresholds(0.5, 16, 50),
    calendar: {
      Area.north: [1, 2, 2, 3, 1, 0, 0, 0, 0, 0, 0, 0],
      Area.centre: [1, 1, 1, 3, 1, 0, 0, 0, 0, 0, 0, 0],
      Area.south: [1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0],
    },
  );

  static const ash = Allergen(
    id: 'ash',
    name: 'Frassino',
    family: 'Oleacee',
    habitat: 'Boschi e viali; l’orniello sulle colline del Centro-Sud.',
    crossReactions: 'Olivo e ligustro.',
    icon: Icons.nature_people_outlined,
    pollnetId: 1417,
    thresholds: Thresholds(0.5, 5, 25),
    calendar: {
      Area.north: [1, 2, 2, 3, 3, 1, 0, 0, 0, 0, 0, 0],
      Area.centre: [1, 1, 2, 3, 3, 1, 0, 0, 0, 0, 0, 0],
      Area.south: [1, 1, 2, 2, 1, 0, 0, 0, 0, 0, 0, 1],
    },
  );

  static const plane = Allergen(
    id: 'plane',
    name: 'Platano',
    family: 'Platanacee',
    habitat: 'Viali e piazze delle città.',
    crossReactions: 'A volte nocciola, arachide e mela.',
    icon: Icons.location_city_outlined,
    pollnetId: 1351,
    thresholds: Thresholds(1, 20, 40),
    calendar: {
      Area.north: [0, 0, 1, 3, 1, 0, 0, 0, 0, 0, 0, 0],
      Area.centre: [0, 0, 2, 3, 1, 0, 0, 0, 0, 0, 0, 0],
      Area.south: [0, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0],
    },
  );

  static const chestnut = Allergen(
    id: 'chestnut',
    name: 'Castagno',
    family: 'Fagacee',
    habitat: 'Boschi di collina e montagna.',
    crossReactions: 'Quercia, betulla e nocciolo.',
    icon: Icons.terrain_outlined,
    pollnetId: 1386,
    thresholds: Thresholds(1, 20, 40),
    calendar: {
      Area.north: [0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0],
      Area.centre: [0, 0, 0, 0, 0, 2, 1, 1, 0, 0, 0, 0],
      Area.south: [0, 0, 0, 0, 0, 2, 1, 0, 0, 0, 0, 0],
    },
  );

  static const chenopod = Allergen(
    id: 'chenopod',
    name: 'Chenopodio',
    family: 'Amarantacee',
    habitat: 'Incolti, orti e bordi delle strade.',
    crossReactions: 'Amaranto e salsola.',
    icon: Icons.yard_outlined,
    pollnetId: 1327,
    thresholds: Thresholds(0.1, 5, 25),
    calendar: {
      Area.north: [0, 0, 0, 0, 1, 1, 1, 2, 2, 1, 1, 0],
      Area.centre: [0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0],
      Area.south: [1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1],
    },
  );

  static const alternaria = Allergen(
    id: 'alternaria',
    name: 'Alternaria',
    family: 'Muffa',
    habitat: 'Terreno e piante in decomposizione; spore nell’aria nei giorni caldi e ventosi.',
    crossReactions: 'Altre muffe, come il Cladosporium.',
    inkPlate: true,
    icon: Icons.bubble_chart_outlined,
    pollnetId: 1364,
    thresholds: Thresholds(1, 10, 100),
    calendar: {
      Area.north: [1, 1, 1, 2, 2, 3, 3, 3, 3, 3, 2, 1],
      Area.centre: [1, 1, 1, 1, 2, 3, 3, 3, 3, 2, 2, 1],
      Area.south: [1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 1],
    },
  );

  static const all = [
    grass,
    parietaria,
    olive,
    cypress,
    oak,
    plantago,
    mugwort,
    ragweed,
    birch,
    hazel,
    ash,
    plane,
    chestnut,
    chenopod,
    alternaria,
  ];

  static Allergen? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Iterable<String> get openMeteoKeys => all.expand((a) => a.openMeteoKeys);

  static Iterable<Allergen> get measuredOnly => all.where((a) => !a.hasForecast);
}
