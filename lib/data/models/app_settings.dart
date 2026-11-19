/// User-selectable appearance mode.
enum ThemeSetting { system, light, dark }

extension ThemeSettingInfo on ThemeSetting {
  String get label {
    switch (this) {
      case ThemeSetting.system:
        return 'System';
      case ThemeSetting.light:
        return 'Light';
      case ThemeSetting.dark:
        return 'Dark';
    }
  }

  static ThemeSetting parse(String? value) {
    return ThemeSetting.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeSetting.system,
    );
  }
}

/// Repeat mode persisted between sessions.
enum RepeatSetting { off, all, one }

extension RepeatSettingInfo on RepeatSetting {
  String get label {
    switch (this) {
      case RepeatSetting.off:
        return 'Off';
      case RepeatSetting.all:
        return 'Repeat all';
      case RepeatSetting.one:
        return 'Repeat one';
    }
  }

  static RepeatSetting parse(String? value) => RepeatSetting.values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => RepeatSetting.off,
  );
}

/// All preferences that JPlayer persists locally.
class AppSettings {
  const AppSettings({
    this.theme = ThemeSetting.system,
    this.amoled = false,
    this.scanOnLaunch = true,
    this.resumeLastSession = true,
    this.equalizerEnabled = false,
    this.equalizerPreset = 'Normal',
    this.equalizerGains = const [],
    this.bassBoost = 0,
    this.trebleBoost = 0,
    this.loudnessGain = 0,
    this.repeatMode = RepeatSetting.off,
  });

  final ThemeSetting theme;

  /// Pure-black surfaces for OLED displays (dark mode only).
  final bool amoled;
  final bool scanOnLaunch;
  final bool resumeLastSession;
  final bool equalizerEnabled;
  final String equalizerPreset;

  /// Custom band gains, in dB, ordered like the device equalizer bands.
  final List<double> equalizerGains;
  final double bassBoost;
  final double trebleBoost;

  /// AndroidLoudnessEnhancer target gain in dB.
  final double loudnessGain;
  final RepeatSetting repeatMode;

  AppSettings copyWith({
    ThemeSetting? theme,
    bool? amoled,
    bool? scanOnLaunch,
    bool? resumeLastSession,
    bool? equalizerEnabled,
    String? equalizerPreset,
    List<double>? equalizerGains,
    double? bassBoost,
    double? trebleBoost,
    double? loudnessGain,
    RepeatSetting? repeatMode,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      amoled: amoled ?? this.amoled,
      scanOnLaunch: scanOnLaunch ?? this.scanOnLaunch,
      resumeLastSession: resumeLastSession ?? this.resumeLastSession,
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      equalizerGains: equalizerGains ?? this.equalizerGains,
      bassBoost: bassBoost ?? this.bassBoost,
      trebleBoost: trebleBoost ?? this.trebleBoost,
      loudnessGain: loudnessGain ?? this.loudnessGain,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }

  Map<String, Object?> toJson() => {
    'theme': theme.name,
    'amoled': amoled,
    'scanOnLaunch': scanOnLaunch,
    'resumeLastSession': resumeLastSession,
    'equalizerEnabled': equalizerEnabled,
    'equalizerPreset': equalizerPreset,
    'equalizerGains': equalizerGains,
    'bassBoost': bassBoost,
    'trebleBoost': trebleBoost,
    'loudnessGain': loudnessGain,
    'repeatMode': repeatMode.name,
  };

  factory AppSettings.fromJson(Map<String, Object?> json) {
    final rawGains = json['equalizerGains'];
    final gains = <double>[];
    if (rawGains is List) {
      for (final value in rawGains) {
        if (value is num) gains.add(value.toDouble());
      }
    }
    return AppSettings(
      theme: ThemeSettingInfo.parse(json['theme'] as String?),
      amoled: json['amoled'] as bool? ?? false,
      scanOnLaunch: json['scanOnLaunch'] as bool? ?? true,
      resumeLastSession: json['resumeLastSession'] as bool? ?? true,
      equalizerEnabled: json['equalizerEnabled'] as bool? ?? false,
      equalizerPreset: (json['equalizerPreset'] as String?) ?? 'Normal',
      equalizerGains: gains,
      bassBoost: (json['bassBoost'] as num?)?.toDouble() ?? 0,
      trebleBoost: (json['trebleBoost'] as num?)?.toDouble() ?? 0,
      loudnessGain: (json['loudnessGain'] as num?)?.toDouble() ?? 0,
      repeatMode: RepeatSettingInfo.parse(json['repeatMode'] as String?),
    );
  }
}

/// A saved custom equalizer curve.
class EqualizerPresetRecord {
  const EqualizerPresetRecord({required this.name, required this.gains});

  final String name;
  final List<double> gains;

  factory EqualizerPresetRecord.fromMap(Map<String, Object?> map) {
    final gains = <double>[];
    final raw = map['gains'];
    if (raw is String) {
      for (final part in raw.split(',')) {
        final value = double.tryParse(part.trim());
        if (value != null) gains.add(value);
      }
    }
    return EqualizerPresetRecord(
      name: (map['name'] as String?) ?? 'Custom',
      gains: gains,
    );
  }

  String get encodedGains => gains.map((g) => g.toStringAsFixed(1)).join(',');
}
