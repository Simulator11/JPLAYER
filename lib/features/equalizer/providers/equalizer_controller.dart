import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/audio/equalizer_presets.dart';
import '../../../core/providers/core_providers.dart';
import '../../../data/models/app_settings.dart';
import '../../player/providers/player_providers.dart';
import '../../settings/providers/settings_providers.dart';

class EqualizerBandState {
  const EqualizerBandState({
    required this.index,
    required this.centerFrequency,
    required this.gain,
  });

  final int index;
  final double centerFrequency;
  final double gain;
}

class EqualizerUiState {
  const EqualizerUiState({
    required this.available,
    required this.enabled,
    required this.preset,
    required this.bands,
    required this.minDb,
    required this.maxDb,
    required this.bass,
    required this.treble,
    required this.loudness,
    this.message,
  });

  final bool available;
  final bool enabled;
  final String preset;
  final List<EqualizerBandState> bands;
  final double minDb;
  final double maxDb;
  final double bass;
  final double treble;
  final double loudness;
  final String? message;

  static const EqualizerUiState unavailable = EqualizerUiState(
    available: false,
    enabled: false,
    preset: 'Normal',
    bands: [],
    minDb: -12,
    maxDb: 12,
    bass: 0,
    treble: 0,
    loudness: 0,
    message:
        'Play a song first, then reopen the equalizer. Some devices do '
        'not expose audio effects at all.',
  );
}

final equalizerCustomPresetsProvider =
    FutureProvider<List<EqualizerPresetRecord>>((ref) {
      return ref.watch(settingsRepositoryProvider).equalizerPresets();
    });

final equalizerProvider =
    AsyncNotifierProvider<EqualizerController, EqualizerUiState>(
      EqualizerController.new,
      isAutoDispose: false,
    );

class EqualizerController extends AsyncNotifier<EqualizerUiState> {
  @override
  Future<EqualizerUiState> build() => _load();

  Future<EqualizerUiState> _load() async {
    final settings = ref.read(settingsProvider);
    final handler = ref.read(audioHandlerProvider);
    final parameters = await handler.equalizerParameters();
    if (parameters == null || parameters.bands.isEmpty) {
      return EqualizerUiState(
        available: false,
        enabled: settings.equalizerEnabled,
        preset: settings.equalizerPreset,
        bands: const [],
        minDb: -12,
        maxDb: 12,
        bass: settings.bassBoost,
        treble: settings.trebleBoost,
        loudness: settings.loudnessGain,
        message: handler.effectsSupported
            ? 'Audio effects become available once playback starts.'
            : 'The equalizer is only available on Android devices.',
      );
    }

    final frequencies = [
      for (final band in parameters.bands) band.centerFrequency,
    ];
    final effective = EqualizerPresets.effectiveGains(
      frequencies: frequencies,
      preset: settings.equalizerPreset,
      customGains: settings.equalizerGains,
      bass: settings.bassBoost,
      treble: settings.trebleBoost,
      minDb: parameters.minDecibels,
      maxDb: parameters.maxDecibels,
    );

    return EqualizerUiState(
      available: true,
      enabled: settings.equalizerEnabled,
      preset: settings.equalizerPreset,
      bands: [
        for (var i = 0; i < parameters.bands.length; i++)
          EqualizerBandState(
            index: i,
            centerFrequency: parameters.bands[i].centerFrequency,
            gain: i < effective.length ? effective[i] : 0,
          ),
      ],
      minDb: parameters.minDecibels,
      maxDb: parameters.maxDecibels,
      bass: settings.bassBoost,
      treble: settings.trebleBoost,
      loudness: settings.loudnessGain,
    );
  }

  Future<void> retry() async {
    state = const AsyncLoading<EqualizerUiState>();
    state = await AsyncValue.guard(_load);
  }

  Future<void> setEnabled(bool enabled) async {
    await ref.read(settingsProvider.notifier).setEqualizerEnabled(enabled);
    await _apply();
  }

  Future<void> setPreset(String preset) async {
    await ref.read(settingsProvider.notifier).setEqualizerPreset(preset);
    await _apply();
  }

  Future<void> setBandGain(int index, double gain) async {
    final current = state.value;
    if (current == null || !current.available) return;
    final settings = ref.read(settingsProvider);
    final base = EqualizerPresets.effectiveGains(
      frequencies: [for (final band in current.bands) band.centerFrequency],
      preset: current.preset,
      customGains: settings.equalizerGains,
      bass: 0,
      treble: 0,
      minDb: current.minDb,
      maxDb: current.maxDb,
    );
    if (index < 0 || index >= base.length) return;
    base[index] = gain.clamp(current.minDb, current.maxDb).toDouble();
    await ref.read(settingsProvider.notifier).setCustomEqualizerGains(base);
    await _apply();
  }

  Future<void> setBass(double value) async {
    await ref.read(settingsProvider.notifier).setBassBoost(value);
    await _apply();
  }

  Future<void> setTreble(double value) async {
    await ref.read(settingsProvider.notifier).setTrebleBoost(value);
    await _apply();
  }

  Future<void> setLoudness(double value) async {
    await ref.read(settingsProvider.notifier).setLoudnessGain(value);
    await _apply();
  }

  Future<void> reset() async {
    await ref.read(settingsProvider.notifier).resetEqualizer();
    await _apply();
  }

  Future<void> saveCustomPreset(String name) async {
    final current = state.value;
    if (current == null) return;
    final gains = [for (final band in current.bands) band.gain];
    await ref.read(settingsRepositoryProvider).saveEqualizerPreset(name, gains);
    ref.invalidate(equalizerCustomPresetsProvider);
  }

  Future<void> selectCustomPreset(EqualizerPresetRecord preset) async {
    await ref
        .read(settingsProvider.notifier)
        .setCustomEqualizerGains(preset.gains);
    await _apply();
  }

  Future<void> deleteCustomPreset(String name) async {
    await ref.read(settingsRepositoryProvider).deleteEqualizerPreset(name);
    ref.invalidate(equalizerCustomPresetsProvider);
  }

  Future<void> _apply() async {
    final handler = ref.read(audioHandlerProvider);
    final settings = ref.read(settingsProvider);
    await handler.applyEqualizer(settings);
    state = await AsyncValue.guard(_load);
  }
}
