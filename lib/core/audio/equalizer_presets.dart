/// Built-in equalizer presets and the math that maps their ten anchor
/// frequencies onto whatever band layout the device's audio effect exposes.
///
/// The values here are fed into `AndroidEqualizerBand.setGain`, i.e. they are
/// applied by Android's real audio effect, not drawn decoration.
class EqualizerPresets {
  const EqualizerPresets._();

  static const String normal = 'Normal';
  static const String custom = 'Custom';

  /// Frequencies (Hz) used by the built-in presets.
  static const List<double> anchorFrequencies = [
    31,
    62,
    125,
    250,
    500,
    1000,
    2000,
    4000,
    8000,
    16000,
  ];

  /// Gain in dB at each [anchorFrequencies] position.
  static const Map<String, List<double>> builtIn = {
    normal: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    'Bass Boost': [7, 6, 5, 3, 1, 0, 0, 0, 0, 0],
    'Classical': [3, 2, 1, 0, 0, 0, 1, 2, 3, 4],
    'Dance': [6, 5, 2, 0, 0, -1, 2, 4, 5, 4],
    'Electronic': [5, 4, 1, 0, -1, 0, 2, 4, 5, 5],
    'Hip Hop': [7, 6, 4, 2, 0, -1, 0, 1, 2, 3],
    'Jazz': [3, 2, 1, 2, 0, 1, 2, 3, 3, 2],
    'Pop': [-1, 1, 3, 4, 3, 0, -1, -1, 0, 1],
    'Rock': [5, 4, 2, 0, -1, 0, 2, 3, 4, 4],
    'Vocal': [-3, -2, 0, 2, 4, 4, 3, 1, 0, -2],
  };

  static List<String> get builtInNames => builtIn.keys.toList(growable: false);

  static List<double> gainsFor(String preset) =>
      List<double>.from(builtIn[preset] ?? builtIn[normal]!);

  /// Linear interpolation of a preset's gain curve at an arbitrary frequency.
  static double interpolate(List<double> curve, double frequency) {
    if (curve.isEmpty) return 0;
    if (frequency <= anchorFrequencies.first) return curve.first;
    if (frequency >= anchorFrequencies.last) return curve.last;
    for (var i = 0; i < anchorFrequencies.length - 1; i++) {
      final low = anchorFrequencies[i];
      final high = anchorFrequencies[i + 1];
      if (frequency >= low && frequency <= high) {
        final t = (frequency - low) / (high - low);
        return curve[i] + (curve[i + 1] - curve[i]) * t;
      }
    }
    return 0;
  }

  /// How strongly the convenience "Bass" slider affects a band.
  static double bassWeight(double frequency) {
    if (frequency <= 125) return 1;
    if (frequency <= 250) return 0.6;
    if (frequency <= 500) return 0.25;
    return 0;
  }

  /// How strongly the convenience "Treble" slider affects a band.
  static double trebleWeight(double frequency) {
    if (frequency >= 8000) return 1;
    if (frequency >= 4000) return 0.6;
    if (frequency >= 2000) return 0.25;
    return 0;
  }

  /// Resolves the gains that should be applied to the device's bands.
  static List<double> effectiveGains({
    required List<double> frequencies,
    required String preset,
    required List<double> customGains,
    required double bass,
    required double treble,
    required double minDb,
    required double maxDb,
  }) {
    if (preset == custom &&
        customGains.isNotEmpty &&
        customGains.length == frequencies.length) {
      return [
        for (var i = 0; i < frequencies.length; i++)
          (customGains[i] +
                  bass * bassWeight(frequencies[i]) +
                  treble * trebleWeight(frequencies[i]))
              .clamp(minDb, maxDb)
              .toDouble(),
      ];
    }
    final curve = preset == custom && customGains.isNotEmpty
        ? customGains
        : gainsFor(preset);
    return [
      for (final frequency in frequencies)
        (interpolate(curve, frequency) +
                bass * bassWeight(frequency) +
                treble * trebleWeight(frequency))
            .clamp(minDb, maxDb)
            .toDouble(),
    ];
  }
}
