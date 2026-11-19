import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/links.dart';
import '../../../shared/widgets/logo.dart';
import 'privacy_screen.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const Center(child: JPLogo(size: 78)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 2),
          Center(
            child: Text(
              AppConstants.slogan,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: palette.accent),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Version ${AppConstants.version}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'A free, ad-free, offline-first music player for Android. JPlayer '
            'focuses on the essentials: finding the music already on your '
            'device and playing it beautifully, with reliable background audio '
            'and lock-screen controls.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 22),
          const _DeveloperCard(),
          const SizedBox(height: 22),
          _Feature(
            icon: Icons.offline_bolt_outlined,
            text: 'Works entirely offline',
          ),
          _Feature(
            icon: Icons.block_rounded,
            text: 'No ads, subscriptions or accounts',
          ),
          _Feature(
            icon: Icons.headphones_outlined,
            text: 'Background playback, Bluetooth and headset controls',
          ),
          _Feature(
            icon: Icons.equalizer_rounded,
            text: 'Real Android equalizer with custom presets',
          ),
          _Feature(
            icon: Icons.favorite_outline_rounded,
            text: 'Favorites, playlists and listening history that persist',
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built with open source',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Flutter · just_audio · audio_service · audio_session · '
                  'sqflite · video_player · Riverpod',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Text(
                  'Package: ${AppConstants.packageName}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: AppConstants.appName,
              applicationVersion: AppConstants.version,
            ),
            icon: const Icon(Icons.description_outlined),
            label: const Text('Open-source licenses'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => AppRoutes.push(context, const PrivacyScreen()),
            icon: const Icon(Icons.privacy_tip_outlined),
            label: const Text('Privacy information'),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              'JPlayer – Your Music, Your Way.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '© ${DateTime.now().year} ${AppConstants.developerName}',
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeveloperCard extends StatelessWidget {
  const _DeveloperCard();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: palette.accent.withValues(alpha: palette.isDark ? 0.35 : 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEVELOPER',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.accent,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: palette.accentGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'JS',
                    style: TextStyle(
                      color: palette.onAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.developerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Developer of JPlayer',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: palette.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () =>
                  AppLinks.openExternal(context, AppConstants.portfolioUrl),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: palette.accentMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.language_rounded,
                      size: 20,
                      color: palette.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Portfolio',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: palette.textSecondary),
                          ),
                          Text(
                            AppConstants.portfolioLabel,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: palette.accent,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: palette.accent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 19, color: context.palette.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.palette.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
