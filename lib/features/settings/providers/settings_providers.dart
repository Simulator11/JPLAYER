import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../data/models/app_settings.dart';

/// Loaded synchronously in main() before the first frame.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
  isAutoDispose: false,
);

final settingsPresetsProvider = FutureProvider<List<EqualizerPresetRecord>>((
  ref,
) async {
  return ref.watch(settingsRepositoryProvider).equalizerPresets();
});

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> _persist(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).saveSettings(next);
  }

  Future<void> setTheme(ThemeSetting value) =>
      _persist(state.copyWith(theme: value));

  Future<void> setAmoled(bool value) => _persist(state.copyWith(amoled: value));

  Future<void> setScanOnLaunch(bool value) =>
      _persist(state.copyWith(scanOnLaunch: value));

  Future<void> setResumeLastSession(bool value) =>
      _persist(state.copyWith(resumeLastSession: value));

  Future<void> setRepeatMode(RepeatSetting value) =>
      _persist(state.copyWith(repeatMode: value));

  Future<void> setEqualizerEnabled(bool value) =>
      _persist(state.copyWith(equalizerEnabled: value));

  Future<void> setEqualizerPreset(String preset) =>
      _persist(state.copyWith(equalizerPreset: preset));

  Future<void> setCustomEqualizerGains(List<double> gains) => _persist(
    state.copyWith(
      equalizerPreset: 'Custom',
      equalizerGains: List<double>.unmodifiable(gains),
    ),
  );

  Future<void> setBassBoost(double value) =>
      _persist(state.copyWith(bassBoost: value));

  Future<void> setTrebleBoost(double value) =>
      _persist(state.copyWith(trebleBoost: value));

  Future<void> setLoudnessGain(double value) =>
      _persist(state.copyWith(loudnessGain: value));

  Future<void> resetEqualizer() => _persist(
    state.copyWith(
      equalizerPreset: 'Normal',
      equalizerGains: const [],
      bassBoost: 0,
      trebleBoost: 0,
      loudnessGain: 0,
    ),
  );

  /// Replaces in-memory settings after a backup restore.
  Future<void> reload() async {
    state = await ref.read(settingsRepositoryProvider).loadSettings();
  }
}
