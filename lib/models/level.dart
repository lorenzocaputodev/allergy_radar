/// Livello di rischio 0–4, uguale per tutti gli allergeni.
enum Level {
  none('Nessuno'),
  low('Basso'),
  moderate('Moderato'),
  high('Alto'),
  veryHigh('Molto alto');

  const Level(this.label);

  final String label;

  bool operator >=(Level other) => index >= other.index;

  Level max(Level other) => index >= other.index ? this : other;

  static Level fromIndex(int i) => Level.values[i.clamp(0, 4)];
}

/// Soglie in granuli/m³: classi POLLnet (bassa, media, alta).
/// «Molto alto» è un'estensione dell'app: 3 volte la soglia alta.
class Thresholds {
  const Thresholds(this.low, this.moderate, this.high);

  final double low;
  final double moderate;
  final double high;

  double get veryHigh => high * 3;

  Level levelOf(double value) {
    if (value < low) return Level.none;
    if (value < moderate) return Level.low;
    if (value < high) return Level.moderate;
    if (value < veryHigh) return Level.high;
    return Level.veryHigh;
  }
}
