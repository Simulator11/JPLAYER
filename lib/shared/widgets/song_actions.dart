import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../core/providers/core_providers.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../features/music/providers/library_providers.dart';
import '../../features/player/providers/player_providers.dart';
import 'artwork.dart';

Future<void> showSongActionsSheet(BuildContext context, Song song) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _SongActionsSheet(song: song),
  );
}

class _SongActionsSheet extends ConsumerWidget {
  const _SongActionsSheet({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};
    final isFavorite = favorites.contains(song.id);
    final handler = ref.read(audioHandlerProvider);

    void run(Future<void> Function() action) {
      Navigator.of(context).pop();
      action();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            leading: Artwork(song: song, size: 52, radius: 10),
            title: Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            subtitle: Text(
              '${song.displayArtist} · ${song.displayAlbum}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Divider(color: palette.divider, height: 1),
          _ActionTile(
            icon: Icons.play_arrow_rounded,
            label: 'Play now',
            onTap: () => run(() => handler.playSongs([song])),
          ),
          _ActionTile(
            icon: Icons.queue_play_next_rounded,
            label: 'Play next',
            onTap: () => run(() => handler.addToQueue([song], playNext: true)),
          ),
          _ActionTile(
            icon: Icons.playlist_add_rounded,
            label: 'Add to queue',
            onTap: () => run(() => handler.addToQueue([song])),
          ),
          _ActionTile(
            icon: Icons.playlist_add_check_rounded,
            label: 'Add to playlist',
            onTap: () {
              final target = Navigator.of(context).context;
              Navigator.of(context).pop();
              showAddToPlaylistSheet(target, [song]);
            },
          ),
          _ActionTile(
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: isFavorite ? 'Remove from favorites' : 'Add to favorites',
            onTap: () async {
              Navigator.of(context).pop();
              await ref.read(favoritesProvider.notifier).toggle(song.id);
            },
          ),
          _ActionTile(
            icon: Icons.info_outline_rounded,
            label: 'Song info',
            onTap: () {
              final target = Navigator.of(context).context;
              Navigator.of(context).pop();
              showSongInfoDialog(target, song);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 22),
      leading: Icon(icon, size: 22),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      onTap: onTap,
    );
  }
}

Future<void> showAddToPlaylistSheet(BuildContext context, List<Song> songs) {
  if (songs.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(songs: songs),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.songs});

  final List<Song> songs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final playlists = ref.watch(playlistsProvider);
    final messenger = ScaffoldMessenger.of(context);

    Future<void> addTo(Playlist playlist) async {
      final added = await ref.read(playlistsProvider.notifier).addSongs(
        playlist.id,
        [for (final song in songs) song.id],
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == 0
                ? 'Already in "${playlist.name}"'
                : 'Added ${Formatters.songCount(added)} to "${playlist.name}"',
          ),
        ),
      );
    }

    Future<void> createAndAdd() async {
      final playlist = await showCreatePlaylistDialog(context, ref);
      if (playlist == null) return;
      final added = await ref.read(playlistsProvider.notifier).addSongs(
        playlist.id,
        [for (final song in songs) song.id],
      );
      if (!context.mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Added ${Formatters.songCount(added)} to "${playlist.name}"',
          ),
        ),
      );
    }

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.5,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to playlist',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    Formatters.songCount(songs.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Divider(color: palette.divider, height: 1),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: palette.accentMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.add_rounded, color: palette.accent),
              ),
              title: const Text('New playlist'),
              onTap: createAndAdd,
            ),
            Expanded(
              child: playlists.when(
                data: (items) {
                  if (items.isEmpty) {
                    return const Center(
                      child: Text('No playlists yet. Create your first one.'),
                    );
                  }
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final playlist = items[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: Icon(
                          Icons.queue_music_rounded,
                          color: palette.textSecondary,
                        ),
                        title: Text(playlist.name),
                        subtitle: Text(
                          Formatters.songCount(playlist.songCount),
                        ),
                        onTap: () => addTo(playlist),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text('$error')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Playlist?> showCreatePlaylistDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _PlaylistNameDialog(
      title: 'New playlist',
      confirmLabel: 'Create',
    ),
  );
  if (name == null || name.trim().isEmpty) return null;
  try {
    return await ref.read(playlistsProvider.notifier).create(name.trim());
  } on PlaylistNameConflict catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.toString())));
    }
    return null;
  }
}

Future<String?> showRenamePlaylistDialog(
  BuildContext context,
  String currentName,
) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PlaylistNameDialog(
      title: 'Rename playlist',
      confirmLabel: 'Save',
      initialValue: currentName,
    ),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String? initialValue;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

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
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

Future<void> showSongInfoDialog(BuildContext context, Song song) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        return AlertDialog(
          title: Text(song.title),
          content: FutureBuilder<int>(
            future: ref.read(playlistRepositoryProvider).playCount(song.id),
            builder: (context, snapshot) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow('Artist', song.displayArtist),
                    _InfoRow('Album', song.displayAlbum),
                    _InfoRow('Genre', song.displayGenre),
                    _InfoRow('Duration', Formatters.duration(song.duration)),
                    _InfoRow('Format', song.extension.toUpperCase()),
                    _InfoRow('Size', Formatters.fileSize(song.sizeBytes)),
                    _InfoRow('Added', Formatters.date(song.dateAddedTime)),
                    _InfoRow('Plays', '${snapshot.data ?? 0}'),
                    const SizedBox(height: 8),
                    SelectableText(
                      song.path.isNotEmpty ? song.path : song.uri,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
