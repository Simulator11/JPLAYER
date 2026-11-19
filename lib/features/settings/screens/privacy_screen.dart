import 'package:material_ui/material_ui.dart';

import '../../../app/theme/colors.dart';

/// Plain-language explanation of JPlayer's local-only data handling.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Your music stays yours.',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'JPlayer is a local music player. It does not need an account, does '
            'not show ads, and does not send your library anywhere.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 22),
          const _PrivacyCard(
            icon: Icons.folder_shared_outlined,
            title: 'Local media access',
            body:
                'JPlayer reads the audio and video that Android has indexed on '
                'this device. On Android 13 and newer it uses READ_MEDIA_AUDIO '
                'and READ_MEDIA_VIDEO; older versions use READ_EXTERNAL_STORAGE. '
                'It never asks for all-files access (MANAGE_EXTERNAL_STORAGE).',
          ),
          const _PrivacyCard(
            icon: Icons.cloud_off_rounded,
            title: 'No internet permission',
            body:
                'The release build does not request the INTERNET permission. '
                'Music, artwork, lyrics and video playback all happen on-device. '
                'There are no advertising SDKs, analytics SDKs or trackers.',
          ),
          const _PrivacyCard(
            icon: Icons.storage_rounded,
            title: 'What is stored',
            body:
                'JPlayer keeps a small SQLite database with metadata, '
                'favorites, playlists, listening history, queue state and your '
                'preferences. Artwork is cached as JPEG files in the app cache. '
                'Your original music files are never copied or modified.',
          ),
          const _PrivacyCard(
            icon: Icons.folder_off_outlined,
            title: 'Backups are yours',
            body:
                'A backup is a JSON file containing playlists, favorites, '
                'settings and file paths. It is written only where you choose in '
                'the system file picker. JPlayer never uploads it.',
          ),
          const _PrivacyCard(
            icon: Icons.delete_sweep_outlined,
            title: 'Removing your data',
            body:
                'Uninstalling JPlayer or clearing its storage removes the '
                'database, cache and preferences. Your audio and video files are '
                'not affected. Media permissions can be revoked at any time in '
                'Android Settings > Apps > JPlayer > Permissions.',
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'JPlayer – Your Music, Your Way.',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.accentMuted,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: palette.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
