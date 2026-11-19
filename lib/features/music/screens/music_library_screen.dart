import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/song_actions.dart';
import '../../../shared/widgets/song_collection_screen.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../player/providers/player_providers.dart';
import '../../search/screens/search_screen.dart';
import '../../settings/screens/folder_exclusions_screen.dart';
import '../../videos/screens/videos_screen.dart';
import '../providers/library_providers.dart';
import '../widgets/music_tabs.dart';

class MusicLibraryScreen extends ConsumerStatefulWidget {
  const MusicLibraryScreen({super.key});

  @override
  ConsumerState<MusicLibraryScreen> createState() => _MusicLibraryScreenState();
}

class _MusicLibraryScreenState extends ConsumerState<MusicLibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 5,
    vsync: this,
  )..addListener(_handleTabChange);
  final Set<int> _selected = {};
  SongSort _sort = SongSort.title;
  int _lastTabIndex = 0;
  List<Song>? _cachedSongs;
  List<Song>? _cachedSource;
  SongSort? _cachedSort;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!mounted) return;
    if (_tabController.index != _lastTabIndex) {
      _lastTabIndex = _tabController.index;
      setState(_selected.clear);
    }
  }

  void _clearSelection() => setState(_selected.clear);

  void _toggleSelection(int songId) {
    setState(() {
      if (_selected.contains(songId)) {
        _selected.remove(songId);
      } else {
        _selected.add(songId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshotAsync = ref.watch(libraryProvider);
    final snapshot = snapshotAsync.value;
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};
    final excluded =
        ref.watch(excludedFoldersProvider).value ?? const <String>[];
    final scan = ref.watch(scanStatusProvider);
    final songs = _sortedSongs(snapshot?.songs ?? const <Song>[]);
    final selecting = _selected.isNotEmpty;

    Future<void> rescan() async {
      final outcome = await ref.read(libraryProvider.notifier).scan();
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (outcome != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${Formatters.songCount(outcome.songs.total)} · '
              '${outcome.songs.added} new · ${outcome.songs.removed} removed',
            ),
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ref.read(scanStatusProvider).message ?? 'Scan failed.',
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: selecting
            ? Text('${_selected.length} selected')
            : const Text('Music'),
        leading: selecting
            ? IconButton(
                tooltip: 'Cancel selection',
                onPressed: _clearSelection,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        actions: selecting
            ? [
                IconButton(
                  tooltip: _selected.length == songs.length
                      ? 'Clear selection'
                      : 'Select all',
                  onPressed: () {
                    setState(() {
                      if (_selected.length == songs.length) {
                        _selected.clear();
                      } else {
                        _selected
                          ..clear()
                          ..addAll(songs.map((song) => song.id));
                      }
                    });
                  },
                  icon: Icon(
                    _selected.length == songs.length
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                  ),
                ),
              ]
            : [
                IconButton(
                  tooltip: 'Search',
                  onPressed: () =>
                      AppRoutes.push(context, const SearchScreen()),
                  icon: const Icon(Icons.search_rounded),
                ),
                if (_tabController.index == 0)
                  IconButton(
                    tooltip: 'Sort songs',
                    onPressed: _showSortSheet,
                    icon: const Icon(Icons.sort_rounded),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'More options',
                  icon: const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    switch (value) {
                      case 'rescan':
                        rescan();
                        break;
                      case 'videos':
                        AppRoutes.push(context, const VideosScreen());
                        break;
                      case 'exclusions':
                        _openExclusions();
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'rescan', child: Text('Rescan music')),
                    PopupMenuItem(value: 'videos', child: Text('Videos')),
                    PopupMenuItem(
                      value: 'exclusions',
                      child: Text('Folder exclusions'),
                    ),
                  ],
                ),
              ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Songs'),
            Tab(text: 'Albums'),
            Tab(text: 'Artists'),
            Tab(text: 'Genres'),
            Tab(text: 'Folders'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (scan.isBusy)
            LinearProgressIndicator(
              value: scan.fraction,
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: snapshot == null && snapshotAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : snapshot == null || !snapshot.hasPermission
                ? EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Music access needed',
                    message:
                        'Allow JPlayer to read the audio Android indexes '
                        'on this device.',
                    actionLabel: 'Allow access',
                    onAction: () async {
                      final library = ref.read(libraryProvider.notifier);
                      await library.ensurePermission();
                      await library.scan();
                    },
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _songsTab(context, songs, favorites, selecting),
                      AlbumsTab(albums: snapshot.albums, onTap: _openAlbum),
                      ArtistsTab(artists: snapshot.artists, onTap: _openArtist),
                      GenresTab(genres: snapshot.genres, onTap: _openGenre),
                      FoldersTab(
                        folders: snapshot.folders,
                        excludedFolders: excluded,
                        onTap: _openFolder,
                        onExclude: _excludeFolder,
                        onManageExclusions: _openExclusions,
                      ),
                    ],
                  ),
          ),
        ],
      ),
      bottomNavigationBar: selecting
          ? _SelectionBar(
              selectedCount: _selected.length,
              allFavorite:
                  _selectedSongs(songs).isNotEmpty &&
                  _selectedSongs(songs)
                      .every((song) => favorites.contains(song.id)),
              onPlay: () {
                final selectedSongs = _selectedSongs(songs);
                if (selectedSongs.isEmpty) return;
                ref.read(audioHandlerProvider).playSongs(selectedSongs);
                _clearSelection();
              },
              onQueue: () {
                final selectedSongs = _selectedSongs(songs);
                if (selectedSongs.isEmpty) return;
                ref
                    .read(audioHandlerProvider)
                    .addToQueue(selectedSongs, playNext: true);
                _clearSelection();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Queued ${Formatters.songCount(selectedSongs.length)}',
                    ),
                  ),
                );
              },
              onPlaylist: () async {
                final selectedSongs = _selectedSongs(songs);
                if (selectedSongs.isEmpty) return;
                await showAddToPlaylistSheet(context, selectedSongs);
                if (mounted) _clearSelection();
              },
              onFavorite: () async {
                final selectedSongs = _selectedSongs(songs);
                if (selectedSongs.isEmpty) return;
                final allFavorites = selectedSongs.every(
                  (song) => favorites.contains(song.id),
                );
                await ref
                    .read(favoritesProvider.notifier)
                    .setFavoriteForSongs(
                      selectedSongs.map((song) => song.id).toList(),
                      !allFavorites,
                    );
                if (mounted) _clearSelection();
              },
              onClose: _clearSelection,
            )
          : null,
    );
  }

  Widget _songsTab(
    BuildContext context,
    List<Song> songs,
    Set<int> favorites,
    bool selecting,
  ) {
    final handler = ref.read(audioHandlerProvider);
    if (songs.isEmpty) {
      return EmptyState(
        icon: Icons.music_note_rounded,
        title: 'No songs yet',
        message: 'Scan your device to discover the music already stored here.',
        actionLabel: 'Scan my music',
        onAction: () => ref.read(libraryProvider.notifier).scan(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: songs.length,
      itemBuilder: (context, index) {
        final song = songs[index];
        return SongTile(
          song: song,
          selectable: selecting,
          selected: _selected.contains(song.id),
          isFavorite: favorites.contains(song.id),
          onTap: () {
            if (selecting) {
              _toggleSelection(song.id);
            } else {
              handler.playSongs(songs, index: index);
            }
          },
          onLongPress: () => _toggleSelection(song.id),
          onMore: selecting ? null : () => showSongActionsSheet(context, song),
        );
      },
    );
  }

  List<Song> _sortedSongs(List<Song> input) {
    if (identical(input, _cachedSource) &&
        _sort == _cachedSort &&
        _cachedSongs != null) {
      return _cachedSongs!;
    }
    final songs = [...input];
    switch (_sort) {
      case SongSort.title:
        songs.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        break;
      case SongSort.dateAdded:
        songs.sort((a, b) => b.dateAdded.compareTo(a.dateAdded));
        break;
      case SongSort.duration:
        songs.sort((a, b) => b.durationMs.compareTo(a.durationMs));
        break;
      case SongSort.artist:
        songs.sort((a, b) {
          final artist = a.displayArtist.toLowerCase().compareTo(
            b.displayArtist.toLowerCase(),
          );
          if (artist != 0) return artist;
          final album = a.displayAlbum.toLowerCase().compareTo(
            b.displayAlbum.toLowerCase(),
          );
          if (album != 0) return album;
          final track = a.track.compareTo(b.track);
          if (track != 0) return track;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
      case SongSort.album:
        songs.sort((a, b) {
          final album = a.displayAlbum.toLowerCase().compareTo(
            b.displayAlbum.toLowerCase(),
          );
          if (album != 0) return album;
          final track = a.track.compareTo(b.track);
          if (track != 0) return track;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }
    _cachedSource = input;
    _cachedSort = _sort;
    _cachedSongs = songs;
    return songs;
  }

  List<Song> _selectedSongs(List<Song> songs) => [
    for (final song in songs)
      if (_selected.contains(song.id)) song,
  ];

  Future<void> _showSortSheet() async {
    final palette = context.palette;
    final selected = await showModalBottomSheet<SongSort>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Sort songs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            for (final sort in SongSort.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(_sortIcon(sort)),
                title: Text(sort.label),
                trailing: sort == _sort
                    ? Icon(Icons.check_rounded, color: palette.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(sort),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _sort = selected);
  }

  IconData _sortIcon(SongSort sort) => switch (sort) {
    SongSort.title => Icons.sort_by_alpha_rounded,
    SongSort.dateAdded => Icons.schedule_rounded,
    SongSort.duration => Icons.timelapse_rounded,
    SongSort.artist => Icons.person_outline_rounded,
    SongSort.album => Icons.album_outlined,
  };

  void _openAlbum(Album album) {
    final snapshot = ref.read(libraryProvider).value;
    if (snapshot == null) return;
    AppRoutes.push(
      context,
      SongCollectionScreen(
        title: album.title,
        subtitle: album.displayArtist,
        artworkSong: album.sample,
        songs: snapshot.songsOfAlbum(album),
      ),
    );
  }

  void _openArtist(Artist artist) {
    final snapshot = ref.read(libraryProvider).value;
    if (snapshot == null) return;
    AppRoutes.push(
      context,
      SongCollectionScreen(
        title: artist.displayName,
        subtitle: Formatters.count(artist.albumCount, 'album'),
        artworkSong: artist.sample,
        songs: snapshot.songsOfArtist(artist),
      ),
    );
  }

  void _openGenre(Genre genre) {
    final snapshot = ref.read(libraryProvider).value;
    if (snapshot == null) return;
    AppRoutes.push(
      context,
      SongCollectionScreen(
        title: genre.name,
        subtitle: Formatters.songCount(genre.songCount),
        songs: snapshot.songsOfGenre(genre),
      ),
    );
  }

  void _openFolder(MusicFolder folder) {
    final snapshot = ref.read(libraryProvider).value;
    if (snapshot == null) return;
    final folderSongs = snapshot.songsOfFolder(folder);
    AppRoutes.push(
      context,
      SongCollectionScreen(
        title: folder.displayName,
        subtitle: folder.path.isEmpty ? 'Device storage' : folder.path,
        artworkSong: folderSongs.isEmpty ? null : folderSongs.first,
        songs: folderSongs,
      ),
    );
  }

  Future<void> _excludeFolder(MusicFolder folder) async {
    await ref.read(musicRepositoryProvider).excludeFolder(folder.path);
    await ref.read(libraryProvider.notifier).refresh();
    ref.invalidate(excludedFoldersProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${folder.displayName}" excluded from JPlayer')),
    );
  }

  Future<void> _openExclusions() async {
    await AppRoutes.push(context, const FolderExclusionsScreen());
    if (!mounted) return;
    await ref.read(libraryProvider.notifier).refresh();
    ref.invalidate(excludedFoldersProvider);
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.allFavorite,
    required this.onPlay,
    required this.onQueue,
    required this.onPlaylist,
    required this.onFavorite,
    required this.onClose,
  });

  final int selectedCount;
  final bool allFavorite;
  final VoidCallback onPlay;
  final VoidCallback onQueue;
  final VoidCallback onPlaylist;
  final VoidCallback onFavorite;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.divider, width: 0.7)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SelectionAction(
                  icon: Icons.play_arrow_rounded,
                  label: 'Play',
                  onTap: onPlay,
                ),
                _SelectionAction(
                  icon: Icons.queue_play_next_rounded,
                  label: 'Queue',
                  onTap: onQueue,
                ),
                _SelectionAction(
                  icon: Icons.playlist_add_rounded,
                  label: 'Playlist',
                  onTap: onPlaylist,
                ),
                _SelectionAction(
                  icon: allFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  label: allFavorite ? 'Unfavorite' : 'Favorite',
                  onTap: onFavorite,
                ),
                _SelectionAction(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onTap: onClose,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  const _SelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: palette.textPrimary),
            const SizedBox(height: 3),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
