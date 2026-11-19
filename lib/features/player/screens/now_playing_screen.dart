import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/color_extractor.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/queue_sheet.dart';
import '../../../shared/widgets/song_actions.dart';
import '../../../shared/widgets/song_collection_screen.dart';
import '../../equalizer/screens/equalizer_screen.dart';
import '../../lyrics/screens/lyrics_screen.dart';
import '../../music/providers/library_providers.dart';
import '../../settings/widgets/sleep_timer_sheet.dart';
import '../providers/player_providers.dart';
import '../widgets/playback_controls.dart';

class NowPlayingScreen extends ConsumerStatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  ConsumerState<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends ConsumerState<NowPlayingScreen> {
  @override
  Widget build(BuildContext context) {
    final song = ref.watch(currentSongProvider).value;
    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Now playing')),
        body: const EmptyState(
          icon: Icons.music_note_rounded,
          title: 'Nothing playing',
          message: 'Choose a song from your library to start listening.',
        ),
      );
    }

    final palette = context.palette;
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};
    final isFavorite = favorites.contains(song.id);
    final sleepActive = ref.watch(
      sleepTimerProvider.select((state) => state.active),
    );

    return Scaffold(
      backgroundColor: palette.background,
      body: _PlayerBackdrop(
        song: song,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              children: [
                _topBar(context, song),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide =
                          constraints.maxWidth > 700 ||
                          constraints.maxWidth > constraints.maxHeight * 1.25;
                      if (wide) {
                        return Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: _artwork(song),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: SingleChildScrollView(
                                child: _controlsColumn(
                                  context,
                                  song,
                                  isFavorite,
                                  sleepActive,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Expanded(child: Center(child: _artwork(song))),
                          const SizedBox(height: 16),
                          _titleBlock(context, song, isFavorite),
                          const SizedBox(height: 2),
                          const PlaybackProgress(),
                          const PlaybackControls(),
                          const SizedBox(height: 4),
                          _bottomActions(context, sleepActive),
                          const SizedBox(height: 4),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context, Song song) {
    final palette = context.palette;
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close player',
            onPressed: () => Navigator.of(context).maybePop(),
            iconSize: 28,
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                'NOW PLAYING',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: Icon(Icons.more_horiz_rounded, color: palette.textPrimary),
            onSelected: (value) => _handleMenu(value, song),
            itemBuilder: (context) => [
              _menuItem('album', Icons.album_outlined, 'Go to album'),
              _menuItem('artist', Icons.person_outline_rounded, 'Go to artist'),
              _menuItem(
                'playlist',
                Icons.playlist_add_rounded,
                'Add to playlist',
              ),
              _menuItem('sleep', Icons.bedtime_outlined, 'Sleep timer'),
              _menuItem('equalizer', Icons.equalizer_rounded, 'Equalizer'),
              _menuItem('info', Icons.info_outline_rounded, 'Song info'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Widget _artwork(Song song) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420, maxHeight: 420),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: Container(
          key: ValueKey(song.id),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 38,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Artwork(song: song, radius: 28),
          ),
        ),
      ),
    );
  }

  Widget _titleBlock(BuildContext context, Song song, bool isFavorite) {
    final palette = context.palette;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  song.title,
                  key: ValueKey('title_${song.id}'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 23,
                    height: 1.2,
                    color: palette.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${song.displayArtist} · ${song.displayAlbum}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
          onPressed: () => ref.read(favoritesProvider.notifier).toggle(song.id),
          iconSize: 26,
          color: isFavorite ? palette.accent : palette.textSecondary,
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          ),
        ),
      ],
    );
  }

  Widget _bottomActions(BuildContext context, bool sleepActive) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        PlayerActionButton(
          icon: Icons.queue_music_rounded,
          label: 'Queue',
          onTap: () => showQueueSheet(context),
        ),
        PlayerActionButton(
          icon: Icons.lyrics_outlined,
          label: 'Lyrics',
          onTap: () => AppRoutes.push(context, const LyricsScreen()),
        ),
        PlayerActionButton(
          icon: Icons.equalizer_rounded,
          label: 'Equalizer',
          onTap: () => AppRoutes.push(context, const EqualizerScreen()),
        ),
        PlayerActionButton(
          icon: Icons.bedtime_outlined,
          label: 'Sleep',
          active: sleepActive,
          onTap: () => showSleepTimerSheet(context),
        ),
      ],
    );
  }

  Widget _controlsColumn(
    BuildContext context,
    Song song,
    bool isFavorite,
    bool sleepActive,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleBlock(context, song, isFavorite),
        const SizedBox(height: 12),
        const PlaybackProgress(),
        const PlaybackControls(),
        const SizedBox(height: 10),
        _bottomActions(context, sleepActive),
      ],
    );
  }

  void _handleMenu(String value, Song song) {
    switch (value) {
      case 'album':
        _openAlbum(song);
        break;
      case 'artist':
        _openArtist(song);
        break;
      case 'playlist':
        showAddToPlaylistSheet(context, [song]);
        break;
      case 'sleep':
        showSleepTimerSheet(context);
        break;
      case 'equalizer':
        AppRoutes.push(context, const EqualizerScreen());
        break;
      case 'info':
        showSongInfoDialog(context, song);
        break;
    }
  }

  void _openAlbum(Song song) {
    final snapshot = ref.read(libraryProvider).value;
    if (snapshot == null) return;
    Album? match;
    for (final album in snapshot.albums) {
      if (album.key == song.albumKey) {
        match = album;
        break;
      }
    }
    if (match == null) return;
    AppRoutes.push(
      context,
      SongCollectionScreen(
        title: match.title,
        subtitle: match.displayArtist,
        artworkSong: match.sample,
        songs: snapshot.songsOfAlbum(match),
      ),
    );
  }

  void _openArtist(Song song) {
    final snapshot = ref.read(libraryProvider).value;
    if (snapshot == null) return;
    Artist? match;
    for (final artist in snapshot.artists) {
      if (artist.displayName.toLowerCase() ==
          song.displayArtist.toLowerCase()) {
        match = artist;
        break;
      }
    }
    if (match == null) return;
    AppRoutes.push(
      context,
      SongCollectionScreen(
        title: match.displayName,
        subtitle: Formatters.count(match.albumCount, 'album'),
        artworkSong: match.sample,
        songs: snapshot.songsOfArtist(match),
      ),
    );
  }
}

class _PlayerBackdrop extends ConsumerWidget {
  const _PlayerBackdrop({required this.song, required this.child});

  final Song song;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final artworkFuture = ref
        .watch(artworkServiceProvider)
        .forSong(songId: song.id, albumId: song.albumId, path: song.path);
    return FutureBuilder<String?>(
      future: artworkFuture,
      builder: (context, artworkSnapshot) {
        return FutureBuilder<ArtworkPalette>(
          future: ArtworkColorExtractor.fromFile(artworkSnapshot.data),
          builder: (context, colorSnapshot) {
            final colors = colorSnapshot.data ?? ArtworkPalette.fallback;
            final top = Color.alphaBlend(
              colors.primary.withValues(alpha: palette.isDark ? 0.38 : 0.20),
              palette.background,
            );
            return AnimatedContainer(
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [top, palette.background, palette.background],
                  stops: const [0, 0.55, 1],
                ),
              ),
              child: child,
            );
          },
        );
      },
    );
  }
}
