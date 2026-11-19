import 'package:material_ui/material_ui.dart';

import '../../app/theme/colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/library_models.dart';
import '../../data/models/song.dart';
import 'artwork.dart';

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.onLongPress,
    this.onMore,
    this.selected = false,
    this.selectable = false,
    this.isFavorite = false,
    this.subtitle,
    this.trailing,
  });

  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onMore;
  final bool selected;
  final bool selectable;
  final bool isFavorite;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: selected ? palette.accentMuted : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: EdgeInsets.fromLTRB(selectable ? 2 : 16, 7, 4, 7),
          child: Row(
            children: [
              if (selectable)
                SizedBox(
                  width: 42,
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onTap?.call(),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              Artwork(song: song, size: 52, radius: 10),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        color: selected ? palette.accent : palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.favorite_rounded,
                              size: 12,
                              color: palette.accent,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            subtitle ??
                                '${song.displayArtist} · ${song.displayAlbum}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else ...[
                Text(
                  Formatters.duration(song.duration),
                  style: textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                if (onMore != null)
                  IconButton(
                    onPressed: onMore,
                    tooltip: 'Song options',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                  )
                else
                  const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SongCard extends StatelessWidget {
  const SongCard({
    super.key,
    required this.song,
    this.onTap,
    this.onMore,
    this.width = 150,
  });

  final Song song;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final double width;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(child: Artwork(song: song, radius: 14)),
                    if (onMore != null)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.32),
                          shape: const CircleBorder(),
                          child: IconButton(
                            onPressed: onMore,
                            tooltip: 'Song options',
                            visualDensity: VisualDensity.compact,
                            iconSize: 18,
                            color: Colors.white,
                            icon: const Icon(Icons.more_vert_rounded),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleSmall?.copyWith(
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                song.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.onTap});

  final Album album;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Artwork(album: album, radius: 16),
            ),
            const SizedBox(height: 8),
            Text(
              album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              album.displayArtist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
