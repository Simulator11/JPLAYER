import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../data/models/library_models.dart';
import '../../data/models/song.dart';
import '../../features/player/providers/player_providers.dart';
import 'common.dart';
import 'song_actions.dart';
import 'song_tile.dart';

/// Horizontal song carousel used on Home.
class SongRail extends ConsumerWidget {
  const SongRail({
    super.key,
    required this.title,
    required this.songs,
    required this.emptyMessage,
    this.onSeeAll,
  });

  final String title;
  final List<Song> songs;
  final String emptyMessage;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final handler = ref.read(audioHandlerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: title,
          actionLabel: songs.isEmpty ? null : 'See all',
          onAction: songs.isEmpty ? null : onSeeAll,
        ),
        if (songs.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Text(
              emptyMessage,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary),
            ),
          )
        else
          SizedBox(
            height: 205,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: songs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final song = songs[index];
                return SongCard(
                  song: song,
                  width: 145,
                  onTap: () => handler.playSongs(songs, index: index),
                  onMore: () => showSongActionsSheet(context, song),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Horizontal album carousel used on Home.
class AlbumRail extends StatelessWidget {
  const AlbumRail({
    super.key,
    required this.title,
    required this.albums,
    this.onAlbumTap,
  });

  final String title;
  final List<Album> albums;
  final ValueChanged<Album>? onAlbumTap;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        SizedBox(
          height: 205,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final album = albums[index];
              return SizedBox(
                width: 145,
                child: AlbumCard(
                  album: album,
                  onTap: onAlbumTap == null ? null : () => onAlbumTap!(album),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
