import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/audio/equalizer_presets.dart';
import '../../../shared/widgets/common.dart';
import '../providers/equalizer_controller.dart';

class EqualizerScreen extends ConsumerWidget {
  const EqualizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(equalizerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Equalizer'),
        actions: [
          IconButton(
            tooltip: 'Reload audio effects',
            onPressed: () => ref.read(equalizerProvider.notifier).retry(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Equalizer unavailable',
          message: '$error',
          actionLabel: 'Try again',
          onAction: () => ref.read(equalizerProvider.notifier).retry(),
        ),
        data: (state) => state.available
            ? _EqualizerBody(state: state)
            : _Unavailable(state: state),
      ),
    );
  }
}

class _Unavailable extends ConsumerWidget {
  const _Unavailable({required this.state});

  final EqualizerUiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        EmptyState(
          icon: Icons.equalizer_rounded,
          title: 'Audio effects are not ready',
          message:
              state.message ??
              'Start playing a song, then open the equalizer again.',
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'JPlayer uses Android\'s system Equalizer and LoudnessEnhancer '
            'audio effects, so the sound changes for real. Not every phone '
            'exposes these effects; when the device does not support them no '
            'fake sliders are shown.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: () => ref.read(equalizerProvider.notifier).retry(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

class _EqualizerBody extends ConsumerWidget {
  const _EqualizerBody({required this.state});

  final EqualizerUiState state;

  Future<void> _savePreset(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _PresetNameDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    await ref.read(equalizerProvider.notifier).saveCustomPreset(name.trim());
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Preset "${name.trim()}" saved')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final controller = ref.read(equalizerProvider.notifier);
    final customPresets =
        ref.watch(equalizerCustomPresetsProvider).value ?? const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.equalizer_rounded,
                size: 20,
                color: palette.accent,
              ),
            ),
            title: const Text('Enable equalizer'),
            subtitle: const Text('Applied live to Android audio output'),
            value: state.enabled,
            onChanged: controller.setEnabled,
          ),
        ),
        const SizedBox(height: 20),
        Text('Presets', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in EqualizerPresets.builtInNames)
              ChoiceChip(
                label: Text(name),
                selected: state.preset == name,
                onSelected: (_) => controller.setPreset(name),
              ),
            if (state.preset == EqualizerPresets.custom)
              const ChoiceChip(
                label: Text('Custom'),
                selected: true,
                onSelected: null,
              ),
            for (final preset in customPresets)
              InputChip(
                label: Text(preset.name),
                onPressed: () => controller.selectCustomPreset(preset),
                onDeleted: () => controller.deleteCustomPreset(preset.name),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text('Bands', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            Text(
              '${state.minDb.round()}…${state.maxDb.round()} dB',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 240,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(18),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                for (final band in state.bands)
                  SizedBox(
                    width: 54,
                    child: _BandSlider(
                      band: band,
                      min: state.minDb,
                      max: state.maxDb,
                      onChanged: (value) =>
                          controller.setBandGain(band.index, value),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _LabeledSlider(
          label: 'Bass',
          value: state.bass,
          min: -10,
          max: 10,
          valueLabel: _dbLabel(state.bass),
          onChanged: controller.setBass,
        ),
        _LabeledSlider(
          label: 'Treble',
          value: state.treble,
          min: -10,
          max: 10,
          valueLabel: _dbLabel(state.treble),
          onChanged: controller.setTreble,
        ),
        _LabeledSlider(
          label: 'Loudness boost',
          value: state.loudness,
          min: 0,
          max: 10,
          valueLabel: _dbLabel(state.loudness),
          onChanged: controller.setLoudness,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  await controller.reset();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Equalizer reset')),
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Reset'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _savePreset(context, ref),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save preset'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'These sliders control the device\'s real Android Equalizer '
                  'and LoudnessEnhancer effects. Bass and Treble are shortcuts '
                  'that shape the low and high bands. Some phones expose five '
                  'bands, others ten.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _dbLabel(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)} dB';

class _BandSlider extends StatelessWidget {
  const _BandSlider({
    required this.band,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final EqualizerBandState band;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Text(
          band.gain.toStringAsFixed(1),
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: palette.accent, fontSize: 10),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: RotatedBox(
            quarterTurns: 3,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 5.5,
                ),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: band.gain.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _formatHz(band.centerFrequency),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.valueLabel,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const Spacer(),
              Text(
                valueLabel,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: palette.accent),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PresetNameDialog extends StatefulWidget {
  const _PresetNameDialog();

  @override
  State<_PresetNameDialog> createState() => _PresetNameDialogState();
}

class _PresetNameDialogState extends State<_PresetNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save equalizer preset'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Preset name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

String _formatHz(double frequency) {
  if (frequency >= 1000) {
    final value = frequency / 1000;
    return '${value.toStringAsFixed(frequency >= 10000 ? 0 : 1)}k';
  }
  return '${frequency.round()}';
}
