import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../data/models/playlist.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/song_actions.dart';
import '../../music/providers/library_providers.dart';
import '../../player/providers/player_providers.dart';
import 'playlist_detail_screen.dart';
import 'smart_playlist_screen.dart';

class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final playlists = ref.watch(playlistsProvider);
    final counts = ref.watch(smartCountsProvider).value ?? const {};

    Future<void> create() async {
      final playlist = await showCreatePlaylistDialog(context, ref);
      if (playlist == null || !context.mounted) return;
      AppRoutes.push(context, PlaylistDetailScreen(playlist: playlist));
    }

    Future<void> deletePlaylist(Playlist playlist) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete playlist?'),
          content: Text(
            '"${playlist.name}" will be removed. Your music files are not '
            'affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(playlistsProvider.notifier).delete(playlist.id);
      }
    }

    Future<void> renamePlaylist(Playlist playlist) async {
      final name = await showRenamePlaylistDialog(context, playlist.name);
      if (name == null) return;
      try {
        await ref.read(playlistsProvider.notifier).rename(playlist.id, name);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('$error')));
        }
      }
    }

    Future<void> playPlaylist(Playlist playlist) async {
      final songs = await ref
          .read(playlistRepositoryProvider)
          .playlistSongs(playlist.id);
      if (!context.mounted) return;
      if (songs.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('This playlist is empty')));
        return;
      }
      await ref.read(audioHandlerProvider).playSongs(songs);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlists'),
        actions: [
          IconButton(
            tooltip: 'New playlist',
            onPressed: create,
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SectionHeader(title: 'Smart playlists'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.65,
              children: [
                for (final type in SmartPlaylist.values)
                  _SmartPlaylistCard(
                    type: type,
                    count: counts[type] ?? 0,
                    onTap: () => AppRoutes.push(
                      context,
                      SmartPlaylistScreen(type: type),
                    ),
                  ),
              ],
            ),
          ),
          SectionHeader(
            title: 'Your playlists',
            actionLabel: 'New',
            onAction: create,
          ),
          playlists.when(
            data: (items) {
              if (items.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: palette.card,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      onTap: create,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: palette.accentMuted,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.playlist_add_rounded,
                                color: palette.accent,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create your first playlist',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Collect the songs you love',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  for (final playlist in items)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: palette.card,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.queue_music_rounded,
                          color: palette.accent,
                        ),
                      ),
                      title: Text(
                        playlist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(Formatters.songCount(playlist.songCount)),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Playlist options',
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: palette.textSecondary,
                        ),
                        onSelected: (value) {
                          switch (value) {
                            case 'play':
                              playPlaylist(playlist);
                              break;
                            case 'rename':
                              renamePlaylist(playlist);
                              break;
                            case 'delete':
                              deletePlaylist(playlist);
                              break;
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'play', child: Text('Play')),
                          PopupMenuItem(value: 'rename', child: Text('Rename')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                      onTap: () => AppRoutes.push(
                        context,
                        PlaylistDetailScreen(playlist: playlist),
                      ),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('$error'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmartPlaylistCard extends StatelessWidget {
  const _SmartPlaylistCard({
    required this.type,
    required this.count,
    required this.onTap,
  });

  final SmartPlaylist type;
  final int count;
  final VoidCallback onTap;

  IconData get _icon => switch (type) {
    SmartPlaylist.favorites => Icons.favorite_rounded,
    SmartPlaylist.recentlyPlayed => Icons.history_rounded,
    SmartPlaylist.mostPlayed => Icons.trending_up_rounded,
    SmartPlaylist.recentlyAdded => Icons.new_releases_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_icon, color: palette.accent, size: 22),
              const SizedBox(height: 8),
              Text(
                type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                Formatters.songCount(count),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
