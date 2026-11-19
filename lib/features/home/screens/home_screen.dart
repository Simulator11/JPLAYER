import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/navigation.dart';
import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/services/media_scanner.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/logo.dart';
import '../../../shared/widgets/rails.dart';
import '../../../shared/widgets/song_collection_screen.dart';
import '../../music/providers/library_providers.dart';
import '../../player/providers/player_providers.dart';
import '../../playlists/screens/smart_playlist_screen.dart';
import '../../search/screens/search_screen.dart';
import '../../videos/screens/videos_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final snapshotAsync = ref.watch(libraryProvider);
    final snapshot = snapshotAsync.value;
    final scan = ref.watch(scanStatusProvider);
    final recentlyPlayed =
        ref.watch(recentlyPlayedProvider).value ?? const <Song>[];
    final recentlyAdded = ref.watch(recentlyAddedProvider);
    final mostPlayed = ref.watch(mostPlayedProvider).value ?? const <Song>[];
    final recentAlbums = ref.watch(recentlyPlayedAlbumsProvider);
    final favorites = ref.watch(favoritesProvider).value ?? const <int>{};
    final handler = ref.read(audioHandlerProvider);

    final songs = snapshot?.songs ?? const <Song>[];

    Future<void> refresh() async {
      await ref.read(libraryProvider.notifier).scan();
      ref.invalidate(recentlyPlayedProvider);
      ref.invalidate(mostPlayedProvider);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: const BrandTitle(),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => AppRoutes.push(context, const SearchScreen()),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () => ref.read(rootTabProvider.notifier).select(3),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Your music, your way.',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: palette.textSecondary),
                      ),
                    ),
                    if (snapshot?.lastScanAt != null)
                      Text(
                        'Updated ${Formatters.timeAgo(snapshot!.lastScanAt)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ),
            if (scan.isBusy)
              SliverToBoxAdapter(child: _ScanCard(progress: scan)),
            if (scan.phase == ScanPhase.error)
              SliverToBoxAdapter(
                child: _ScanErrorCard(
                  message: scan.message ?? 'Scan failed.',
                  onRetry: () => ref.read(libraryProvider.notifier).scan(),
                ),
              ),
            if (snapshot == null && snapshotAsync.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshotAsync.hasError && snapshot == null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not read your library',
                  message:
                      'Media permission may have been revoked, or the library '
                      'needs another scan.',
                  actionLabel: 'Retry',
                  onAction: () => ref.read(libraryProvider.notifier).refresh(),
                ),
              )
            else if (snapshot != null && snapshot.isEmpty && !scan.isBusy)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.library_music_outlined,
                  title: 'Your library is waiting',
                  message:
                      'JPlayer reads the audio already on this device. No '
                      'account, no ads, no internet required.',
                  actionLabel: 'Scan my music',
                  onAction: () => ref.read(libraryProvider.notifier).scan(),
                ),
              )
            else if (songs.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.shuffle_rounded,
                          label: 'Shuffle all',
                          detail: Formatters.songCount(songs.length),
                          onTap: () => handler.playSongs(songs, shuffle: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.favorite_rounded,
                          label: 'Favorites',
                          detail: Formatters.songCount(favorites.length),
                          onTap: () => AppRoutes.push(
                            context,
                            const SmartPlaylistScreen(
                              type: SmartPlaylist.favorites,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.video_library_outlined,
                          label: 'Videos',
                          detail: 'Local media',
                          onTap: () =>
                              AppRoutes.push(context, const VideosScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SongRail(
                  title: 'Recently played',
                  songs: recentlyPlayed,
                  emptyMessage: 'Songs you play will show up here.',
                  onSeeAll: () => AppRoutes.push(
                    context,
                    const SmartPlaylistScreen(
                      type: SmartPlaylist.recentlyPlayed,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SongRail(
                  title: 'Recently added',
                  songs: recentlyAdded,
                  emptyMessage: 'New music appears here after a scan.',
                  onSeeAll: () => AppRoutes.push(
                    context,
                    const SmartPlaylistScreen(
                      type: SmartPlaylist.recentlyAdded,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SongRail(
                  title: 'Most played',
                  songs: mostPlayed,
                  emptyMessage: 'Your most played songs will appear here.',
                  onSeeAll: () => AppRoutes.push(
                    context,
                    const SmartPlaylistScreen(type: SmartPlaylist.mostPlayed),
                  ),
                ),
              ),
              if (recentAlbums.isNotEmpty)
                SliverToBoxAdapter(
                  child: AlbumRail(
                    title: 'Recently played albums',
                    albums: recentAlbums,
                    onAlbumTap: (album) => _openAlbum(context, snapshot, album),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ],
        ),
      ),
    );
  }

  void _openAlbum(
    BuildContext context,
    LibrarySnapshot? snapshot,
    Album album,
  ) {
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
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: palette.accentMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: palette.accent),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 1),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.progress});

  final ScanProgress progress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  progress.message ?? 'Scanning your music…',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (progress.total > 0)
                Text(
                  '${progress.processed}/${progress.total}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress.fraction,
            minHeight: 3,
            borderRadius: BorderRadius.circular(3),
          ),
        ],
      ),
    );
  }
}

class _ScanErrorCard extends StatelessWidget {
  const _ScanErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
