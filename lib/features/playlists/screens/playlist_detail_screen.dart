import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/song_actions.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../music/providers/library_providers.dart';
import '../../player/providers/player_providers.dart';

class PlaylistDetailScreen extends ConsumerStatefulWidget {
  const PlaylistDetailScreen({super.key, required this.playlist});

  final Playlist playlist;

  @override
  ConsumerState<PlaylistDetailScreen> createState() =>
      _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends ConsumerState<PlaylistDetailScreen> {
  int get _playlistId => widget.playlist.id;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _play(List<Song> songs, {bool shuffle = false}) async {
    if (songs.isEmpty) {
      _snack('This playlist is empty');
      return;
    }
    await ref.read(audioHandlerProvider).playSongs(songs, shuffle: shuffle);
  }

  Future<void> _rename() async {
    final current =
        ref.read(playlistProvider(_playlistId)).value?.name ??
        widget.playlist.name;
    final name = await showRenamePlaylistDialog(context, current);
    if (name == null) return;
    try {
      await ref.read(playlistsProvider.notifier).rename(_playlistId, name);
      ref.invalidate(playlistProvider(_playlistId));
    } catch (error) {
      _snack('$error');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: const Text(
          'The playlist will be removed. Your music files are not affected.',
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
    if (confirmed != true) return;
    await ref.read(playlistsProvider.notifier).delete(_playlistId);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _addSongs() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddSongsSheet(playlistId: _playlistId),
    );
  }

  void _reorder(List<Song> songs, int oldIndex, int newIndex) {
    if (newIndex == oldIndex) return;
    final reordered = [...songs];
    final song = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, song);
    ref
        .read(playlistsProvider.notifier)
        .reorder(_playlistId, reordered.map((song) => song.id).toList());
  }

  Future<void> _removeSong(Song song) async {
    await ref.read(playlistsProvider.notifier).removeSong(_playlistId, song.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final playlistName =
        ref.watch(playlistProvider(_playlistId)).value?.name ??
        widget.playlist.name;
    final songsAsync = ref.watch(playlistSongsProvider(_playlistId));
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};
    final handler = ref.read(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlistName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Add songs',
            onPressed: _addSongs,
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Playlist options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) {
              if (value == 'rename') _rename();
              if (value == 'delete') _delete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename playlist')),
              PopupMenuItem(value: 'delete', child: Text('Delete playlist')),
            ],
          ),
        ],
      ),
      body: songsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not open this playlist',
          message: '$error',
        ),
        data: (songs) {
          if (songs.isEmpty) {
            return EmptyState(
              icon: Icons.queue_music_rounded,
              title: 'This playlist is empty',
              message: 'Add songs from your library to get started.',
              actionLabel: 'Add songs',
              onAction: _addSongs,
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        gradient: palette.accentGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.queue_music_rounded,
                        color: palette.onAccent,
                        size: 34,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            playlistName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
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
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _play(songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('Play'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _play(songs, shuffle: true),
                        icon: const Icon(Icons.shuffle_rounded, size: 20),
                        label: const Text('Shuffle'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Divider(color: palette.divider, height: 1),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: songs.length,
                  onReorderItem: (oldIndex, newIndex) =>
                      _reorder(songs, oldIndex, newIndex),
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    return SongTile(
                      key: ValueKey('playlist_song_${song.id}'),
                      song: song,
                      isFavorite: favorites.contains(song.id),
                      onTap: () => handler.playSongs(songs, index: index),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Remove from playlist',
                            visualDensity: VisualDensity.compact,
                            iconSize: 20,
                            onPressed: () => _removeSong(song),
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                            ),
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
          );
        },
      ),
    );
  }
}

class _AddSongsSheet extends ConsumerStatefulWidget {
  const _AddSongsSheet({required this.playlistId});

  final int playlistId;

  @override
  ConsumerState<_AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends ConsumerState<_AddSongsSheet> {
  final TextEditingController _controller = TextEditingController();
  final Set<int> _selected = {};
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _matches(Song song) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    return song.title.toLowerCase().contains(query) ||
        song.displayArtist.toLowerCase().contains(query) ||
        song.displayAlbum.toLowerCase().contains(query);
  }

  Future<void> _add() async {
    if (_selected.isEmpty) return;
    await ref
        .read(playlistsProvider.notifier)
        .addSongs(widget.playlistId, _selected.toList());
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(libraryProvider).value;
    final existing =
        (ref.watch(playlistSongsProvider(widget.playlistId)).value ??
                const <Song>[])
            .map((song) => song.id)
            .toSet();
    final songs = [
      for (final song in snapshot?.songs ?? const <Song>[])
        if (!existing.contains(song.id) && _matches(song)) song,
    ];

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add songs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${_selected.length} selected',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: 'Search your library',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _controller.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: songs.isEmpty
                  ? EmptyState(
                      icon: Icons.playlist_add_check_rounded,
                      title: _query.isEmpty
                          ? 'Every song is here'
                          : 'No matches',
                      message: _query.isEmpty
                          ? 'All the songs in your library are already in '
                                'this playlist.'
                          : 'Try a different title, artist or album.',
                      compact: true,
                    )
                  : ListView.builder(
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        return CheckboxListTile(
                          value: _selected.contains(song.id),
                          onChanged: (value) {
                            setState(() {
                              if (value == true) {
                                _selected.add(song.id);
                              } else {
                                _selected.remove(song.id);
                              }
                            });
                          },
                          secondary: Artwork(song: song, size: 44, radius: 9),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            song.displayArtist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty ? null : _add,
                  child: Text(
                    _selected.isEmpty
                        ? 'Select songs'
                        : 'Add ${_selected.length} '
                              '${_selected.length == 1 ? 'song' : 'songs'}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
