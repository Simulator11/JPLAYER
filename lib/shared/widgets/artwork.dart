import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/colors.dart';
import '../../core/providers/core_providers.dart';
import '../../data/models/library_models.dart';
import '../../data/models/playlist.dart';
import '../../data/models/song.dart';

/// Album artwork with a branded gradient placeholder.
///
/// Pass [size] for fixed thumbnails, or leave it null to fill the parent.
class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    this.song,
    this.album,
    this.video,
    this.size,
    this.radius = 12,
  });

  final Song? song;
  final Album? album;
  final VideoItem? video;
  final double? size;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.watch(artworkServiceProvider);
    final resolvedSong = song ?? album?.sample;
    final future = video != null
        ? service.forVideo(videoId: video!.id, path: video!.path)
        : resolvedSong != null
        ? service.forSong(
            songId: resolvedSong.id,
            albumId: resolvedSong.albumId,
            path: resolvedSong.path,
          )
        : null;

    final placeholder = _ArtworkPlaceholder(
      label:
          video?.title ??
          album?.title ??
          resolvedSong?.displayAlbum ??
          'JPlayer',
      isVideo: video != null,
      size: size,
    );

    Widget content;
    if (future == null) {
      content = placeholder;
    } else {
      content = FutureBuilder<String?>(
        future: future,
        builder: (context, snapshot) {
          final path = snapshot.data;
          if (path == null || path.isEmpty) return placeholder;
          final dpr = MediaQuery.devicePixelRatioOf(context);
          return Image.file(
            File(path),
            fit: BoxFit.cover,
            width: size,
            height: size,
            cacheWidth: size == null ? 900 : (size! * dpr).round(),
            errorBuilder: (_, _, _) => placeholder,
            gaplessPlayback: true,
          );
        },
      );
    }

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: size == null ? SizedBox.expand(child: content) : content,
    );
    return size == null
        ? clipped
        : SizedBox(width: size, height: size, child: clipped);
  }
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({
    required this.label,
    required this.isVideo,
    this.size,
  });

  final String label;
  final bool isVideo;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final seed = label.codeUnits.fold<int>(0, (sum, value) => sum + value);
    final hue = (seed * 37) % 360;
    final base = HSLColor.fromAHSL(
      1,
      hue.toDouble(),
      palette.isDark ? 0.42 : 0.55,
      palette.isDark ? 0.30 : 0.78,
    ).toColor();
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            base,
            Color.lerp(base, palette.background, 0.55) ?? palette.card,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_outlined : Icons.music_note_rounded,
          size: (size ?? 140) * 0.32,
          color: Colors.white.withValues(alpha: 0.72),
        ),
      ),
    );
  }
}
