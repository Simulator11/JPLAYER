import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/song_actions.dart';
import '../../../shared/widgets/song_collection_screen.dart';
import '../../../shared/widgets/song_tile.dart';
import '../../music/providers/library_providers.dart';
import '../../player/providers/player_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _searching = false;
  List<Song> _results = const [];
  List<String> _history = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await ref.read(musicRepositoryProvider).searchHistory();
    if (mounted) setState(() => _history = history);
  }

  void _onChanged(String value) {
    setState(() => _query = value);
    _debounce?.cancel();
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _runSearch(query);
    });
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final results = await ref
          .read(musicRepositoryProvider)
          .searchSongs(query.trim());
      if (!mounted || _query.trim() != query.trim()) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _searching = false;
      });
    }
  }

  Future<void> _submit(String value) async {
    final query = value.trim();
    if (query.isEmpty) return;
    _debounce?.cancel();
    await _runSearch(query);
    await ref.read(musicRepositoryProvider).addSearch(query);
    await _loadHistory();
  }

  void _applyQuery(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.collapsed(offset: query.length);
    _onChanged(query);
    _submit(query);
  }

  Future<void> _clearHistory() async {
    await ref.read(musicRepositoryProvider).clearSearchHistory();
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final snapshot = ref.watch(libraryProvider).value;
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};
    final query = _query.trim().toLowerCase();
    final albums = query.isEmpty
        ? const <Album>[]
        : (snapshot?.albums ?? const <Album>[])
              .where((album) => album.title.toLowerCase().contains(query))
              .take(6)
              .toList();
    final artists = query.isEmpty
        ? const <Artist>[]
        : (snapshot?.artists ?? const <Artist>[])
              .where(
                (artist) => artist.displayName.toLowerCase().contains(query),
              )
              .take(6)
              .toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: _submit,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: 'Songs, artists, albums…',
            filled: false,
            border: InputBorder.none,
            isDense: true,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: palette.textSecondary,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _controller.clear();
                      _onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
      ),
      body: Column(
        children: [
          if (_searching)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
            ),
          Expanded(
            child: _query.trim().isEmpty
                ? _historyView(context)
                : _resultsView(context, snapshot, albums, artists, favorites),
          ),
        ],
      ),
    );
  }

  Widget _historyView(BuildContext context) {
    final palette = context.palette;
    if (_history.isEmpty) {
      return const EmptyState(
        icon: Icons.search_rounded,
        title: 'Find your music',
        message:
            'Search by song, artist, album, genre or file name. Everything '
            'happens locally on your device.',
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        SectionHeader(
          title: 'Recent searches',
          actionLabel: 'Clear',
          onAction: _clearHistory,
        ),
        for (final query in _history)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 18),
            leading: Icon(Icons.history_rounded, color: palette.textSecondary),
            title: Text(query),
            trailing: Icon(
              Icons.north_west_rounded,
              size: 18,
              color: palette.textSecondary,
            ),
            onTap: () => _applyQuery(query),
          ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Text(
            'Search by song, artist, album, genre or file name.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _resultsView(
    BuildContext context,
    LibrarySnapshot? snapshot,
    List<Album> albums,
    List<Artist> artists,
    Set<int> favorites,
  ) {
    final handler = ref.read(audioHandlerProvider);
    final palette = context.palette;
    final hasResults =
        albums.isNotEmpty || artists.isNotEmpty || _results.isNotEmpty;

    if (!hasResults) {
      if (_searching) {
        return const Center(child: CircularProgressIndicator());
      }
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        message:
            'Nothing matched "${_query.trim()}". Try a different song, '
            'artist or album.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (albums.isNotEmpty) ...[
          const SectionHeader(
            title: 'Albums',
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          ),
          for (final album in albums)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Artwork(album: album, size: 48, radius: 10),
              title: Text(
                album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                album.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
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
              },
            ),
        ],
        if (artists.isNotEmpty) ...[
          const SectionHeader(
            title: 'Artists',
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          ),
          for (final artist in artists)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: palette.accentMuted,
                child: Text(
                  Formatters.initials(artist.displayName),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: palette.accent),
                ),
              ),
              title: Text(
                artist.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(Formatters.songCount(artist.songCount)),
              onTap: () {
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
              },
            ),
        ],
        if (_results.isNotEmpty) ...[
          SectionHeader(
            title: 'Songs',
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            actionLabel: Formatters.songCount(_results.length),
          ),
          for (var index = 0; index < _results.length; index++)
            SongTile(
              song: _results[index],
              isFavorite: favorites.contains(_results[index].id),
              onTap: () {
                handler.playSongs(_results, index: index);
                ref.read(musicRepositoryProvider).addSearch(_query.trim());
              },
              onMore: () => showSongActionsSheet(context, _results[index]),
            ),
        ],
      ],
    );
  }
}
