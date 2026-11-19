import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/song.dart';
import '../../features/player/providers/player_providers.dart';
import 'common.dart';
import 'song_tile.dart';

Future<void> showQueueSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const QueueSheet(),
  );
}

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final queue = ref.watch(queueSongsProvider).value ?? const <Song>[];
    final currentIndex = ref.watch(playbackStateProvider).value?.queueIndex;
    final handler = ref.read(audioHandlerProvider);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Play queue',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          Formatters.songCount(queue.length),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
            Divider(color: palette.divider, height: 1),
            Expanded(
              child: queue.isEmpty
                  ? const EmptyState(
                      icon: Icons.queue_music_rounded,
                      title: 'Queue is empty',
                      message: 'Play a song and it will appear here.',
                      compact: true,
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: queue.length,
                      onReorderItem: handler.reorderQueue,
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isCurrent = index == currentIndex;
                        return SongTile(
                          key: ValueKey('queue_${song.id}_$index'),
                          song: song,
                          selected: isCurrent,
                          subtitle: isCurrent
                              ? 'Now playing · ${song.displayArtist}'
                              : null,
                          onTap: () => handler.skipToQueueItem(index),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Remove from queue',
                                visualDensity: VisualDensity.compact,
                                iconSize: 20,
                                onPressed: () =>
                                    handler.removeQueueItemAt(index),
                                icon: const Icon(Icons.close_rounded),
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(
                                  Icons.drag_handle_rounded,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
