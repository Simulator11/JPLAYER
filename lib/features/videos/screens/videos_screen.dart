import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/playlist.dart';
import '../../../shared/widgets/artwork.dart';
import '../../../shared/widgets/common.dart';
import '../../music/providers/library_providers.dart';
import 'video_player_screen.dart';

class VideosScreen extends ConsumerWidget {
  const VideosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(videoPermissionProvider);
    final videos = ref.watch(videosProvider);

    Future<void> requestAccess() async {
      final granted = await ref
          .read(permissionServiceProvider)
          .requestVideoPermission();
      if (!context.mounted) return;
      if (granted) {
        ref.invalidate(videoPermissionProvider);
        ref.invalidate(videosProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Video access was not granted.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () =>
                  ref.read(permissionServiceProvider).openSettings(),
            ),
          ),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Videos'),
        actions: [
          IconButton(
            tooltip: 'Refresh videos',
            onPressed: () => ref.invalidate(videosProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: permission.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not check permissions',
          message: '$error',
        ),
        data: (granted) {
          if (!granted) {
            return EmptyState(
              icon: Icons.video_library_outlined,
              title: 'Video access needed',
              message:
                  'Allow access to local videos to browse the clips stored on '
                  'this device. Music playback never depends on this.',
              actionLabel: 'Allow video access',
              onAction: requestAccess,
            );
          }
          return videos.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => EmptyState(
              icon: Icons.error_outline_rounded,
              title: 'Could not read videos',
              message: '$error',
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(videosProvider),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const EmptyState(
                  icon: Icons.video_library_outlined,
                  title: 'No videos found',
                  message:
                      'Local videos that Android has indexed will appear here.',
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                      ? 3
                      : 2;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.18,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final video = items[index];
                      return _VideoCard(
                        video: video,
                        onTap: () => AppRoutes.push(
                          context,
                          VideoPlayerScreen(videos: items, initialIndex: index),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video, required this.onTap});

  final VideoItem video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Artwork(video: video, radius: 0),
                    Positioned(
                      right: 6,
                      bottom: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          Formatters.duration(video.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: palette.textPrimary),
            ),
            const SizedBox(height: 2),
            Text(
              video.displayBucket,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}
