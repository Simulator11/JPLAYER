import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/routes.dart';
import '../../app/theme/colors.dart';
import '../../features/player/providers/player_providers.dart';
import 'artwork.dart';

/// Persistent player bar shown above the bottom navigation.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(currentSongProvider).value;
    if (song == null) return const SizedBox.shrink();

    final palette = context.palette;
    final playback = ref.watch(playbackStateProvider).value;
    final playing = playback?.playing ?? false;
    final handler = ref.read(audioHandlerProvider);

    return Material(
      color: palette.surface,
      child: InkWell(
        onTap: () => AppRoutes.pushPlayer(context),
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: palette.divider, width: 0.7)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _MiniProgress(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    Artwork(song: song, size: 44, radius: 9),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: palette.textPrimary),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            song.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: handler.togglePlayPause,
                      tooltip: playing ? 'Pause' : 'Play',
                      iconSize: 30,
                      color: palette.textPrimary,
                      icon: Icon(
                        playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                    IconButton(
                      onPressed: handler.skipToNext,
                      tooltip: 'Next',
                      iconSize: 26,
                      color: palette.textPrimary,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProgress extends ConsumerWidget {
  const _MiniProgress();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(durationProvider).value;
    final palette = context.palette;
    final value = duration == null || duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    return SizedBox(
      height: 2,
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2,
        backgroundColor: Colors.transparent,
        valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
      ),
    );
  }
}
