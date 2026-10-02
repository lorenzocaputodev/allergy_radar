enum Area {
  north('Nord'),
  centre('Centro'),
  south('Sud e Isole');

  const Area(this.label);

  final String label;

  static Area ofRegion(String region) => switch (region.trim()) {
    'Piemonte' ||
    "Valle d'Aosta" ||
    'Lombardia' ||
    'Liguria' ||
    'Alto Adige' ||
    'Trentino' ||
    'Veneto' ||
    'Friuli Venezia Giulia' ||
    'Emilia Romagna' => Area.north,
    'Toscana' || 'Umbria' || 'Marche' || 'Lazio' => Area.centre,
    _ => Area.south,
  };
}
