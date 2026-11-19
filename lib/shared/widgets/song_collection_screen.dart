import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/song.dart';
import '../../features/music/providers/library_providers.dart';
import '../../features/player/providers/player_providers.dart';
import 'artwork.dart';
import 'common.dart';
import 'song_actions.dart';
import 'song_tile.dart';

/// Reusable screen for an album, artist, genre, folder or smart playlist.
class SongCollectionScreen extends ConsumerWidget {
  const SongCollectionScreen({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.artworkSong,
    this.emptyMessage = 'Songs will appear here once they are scanned.',
    this.actions,
  });

  final String title;
  final List<Song> songs;
  final String? subtitle;
  final Song? artworkSong;
  final String emptyMessage;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final handler = ref.read(audioHandlerProvider);
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};

    return Scaffold(
      appBar: AppBar(title: const SizedBox.shrink(), actions: actions),
      body: songs.isEmpty
          ? EmptyState(
              icon: Icons.music_note_rounded,
              title: 'Nothing here yet',
              message: emptyMessage,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (artworkSong != null)
                            Artwork(song: artworkSong, size: 96, radius: 16)
                          else
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: palette.accentMuted,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.queue_music_rounded,
                                size: 36,
                                color: palette.accent,
                              ),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                                if (subtitle != null &&
                                    subtitle!.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  Formatters.songCount(songs.length),
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(color: palette.accent),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => handler.playSongs(songs),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  handler.playSongs(songs, shuffle: true),
                              icon: const Icon(Icons.shuffle_rounded, size: 20),
                              label: const Text('Shuffle'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                Divider(color: palette.divider, height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return SongTile(
                        song: song,
                        isFavorite: favorites.contains(song.id),
                        onTap: () => handler.playSongs(songs, index: index),
                        onMore: () => showSongActionsSheet(context, song),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
