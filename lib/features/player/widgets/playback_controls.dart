import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../providers/player_providers.dart';

/// Seek bar bound to the playback engine. Drag state is local so the thumb
/// follows the finger instead of snapping back to the position stream.
class PlaybackProgress extends ConsumerStatefulWidget {
  const PlaybackProgress({super.key});

  @override
  ConsumerState<PlaybackProgress> createState() => _PlaybackProgressState();
}

class _PlaybackProgressState extends ConsumerState<PlaybackProgress> {
  double? _dragMilliseconds;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final engineDuration = ref.watch(durationProvider).value;
    final song = ref.watch(currentSongProvider).value;
    final duration = engineDuration ?? song?.duration ?? Duration.zero;
    final max = duration.inMilliseconds.toDouble();
    final value =
        _dragMilliseconds ??
        position.inMilliseconds.clamp(0, max.toInt()).toDouble();
    final handler = ref.read(audioHandlerProvider);

    return Column(
      children: [
        Slider(
          value: max > 0 ? value.clamp(0, max) : 0,
          max: max > 0 ? max : 1,
          onChanged: max > 0
              ? (next) => setState(() => _dragMilliseconds = next)
              : null,
          onChangeEnd: max > 0
              ? (next) async {
                  await handler.seek(Duration(milliseconds: next.round()));
                  if (mounted) setState(() => _dragMilliseconds = null);
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              Text(
                Formatters.duration(
                  Duration(milliseconds: value.clamp(0, max).round()),
                ),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                Formatters.duration(duration),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class PlaybackControls extends ConsumerWidget {
  const PlaybackControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final playback = ref.watch(playbackStateProvider).value;
    final playing = playback?.playing ?? false;
    final repeat = playback?.repeatMode ?? AudioServiceRepeatMode.none;
    final shuffle =
        (playback?.shuffleMode ?? AudioServiceShuffleMode.none) !=
        AudioServiceShuffleMode.none;
    final handler = ref.read(audioHandlerProvider);

    final repeatIcon = repeat == AudioServiceRepeatMode.one
        ? Icons.repeat_one_rounded
        : Icons.repeat_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
          onPressed: handler.toggleShuffle,
          iconSize: 24,
          color: shuffle ? palette.accent : palette.textSecondary,
          icon: const Icon(Icons.shuffle_rounded),
        ),
        IconButton(
          tooltip: 'Previous',
          onPressed: handler.skipToPrevious,
          iconSize: 38,
          color: palette.textPrimary,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton.filled(
          tooltip: playing ? 'Pause' : 'Play',
          onPressed: handler.togglePlayPause,
          iconSize: 40,
          style: IconButton.styleFrom(
            backgroundColor: palette.accent,
            foregroundColor: palette.onAccent,
            fixedSize: const Size(72, 72),
            shape: const CircleBorder(),
            elevation: 0,
          ),
          icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
        ),
        IconButton(
          tooltip: 'Next',
          onPressed: handler.skipToNext,
          iconSize: 38,
          color: palette.textPrimary,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        IconButton(
          tooltip: repeat == AudioServiceRepeatMode.none
              ? 'Repeat off'
              : repeat == AudioServiceRepeatMode.one
              ? 'Repeat one'
              : 'Repeat all',
          onPressed: handler.cycleRepeat,
          iconSize: 24,
          color: repeat == AudioServiceRepeatMode.none
              ? palette.textSecondary
              : palette.accent,
          icon: Icon(repeatIcon),
        ),
      ],
    );
  }
}

class PlayerActionButton extends StatelessWidget {
  const PlayerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? palette.accent : palette.textSecondary,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? palette.accent : palette.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
