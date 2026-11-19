import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../shared/widgets/logo.dart';
import '../../music/providers/library_providers.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _requesting = false;
  bool _permanentlyDenied = false;

  Future<void> _requestAccess() async {
    setState(() => _requesting = true);
    final permissions = ref.read(permissionServiceProvider);
    final granted = await permissions.requestAudioPermission();
    if (!mounted) return;
    setState(() => _requesting = false);
    if (granted) {
      await permissions.requestNotificationPermission();
      await ref.read(libraryProvider.notifier).refresh();
      return;
    }
    final blocked = await permissions.audioPermanentlyDenied();
    if (!mounted) return;
    setState(() => _permanentlyDenied = blocked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          blocked
              ? 'Media access is blocked. Enable it in Android Settings.'
              : 'JPlayer needs media access to find music on this device.',
        ),
        action: blocked
            ? SnackBarAction(
                label: 'Settings',
                onPressed: permissions.openSettings,
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                palette.accent.withValues(alpha: palette.isDark ? 0.22 : 0.12),
                palette.background,
              ),
              palette.background,
              palette.background,
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              children: [
                const Spacer(flex: 2),
                const JPLogo(size: 92),
                const SizedBox(height: 20),
                Text(
                  'JPlayer',
                  style: Theme.of(context).textTheme.displaySmall
                      ?.copyWith(fontSize: 38, letterSpacing: -1),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Music, Your Way.',
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(color: palette.accent),
                ),
                const Spacer(flex: 2),
                const _WelcomePoint(
                  icon: Icons.offline_bolt_outlined,
                  title: 'Your music, offline',
                  body:
                      'JPlayer plays the audio already on your phone. No '
                      'streaming, no account, no internet needed.',
                ),
                const _WelcomePoint(
                  icon: Icons.block_rounded,
                  title: 'No ads. No tracking.',
                  body:
                      'Free forever, with no advertising SDKs and no analytics '
                      'collecting what you listen to.',
                ),
                const _WelcomePoint(
                  icon: Icons.lock_outline_rounded,
                  title: 'Private by design',
                  body:
                      'Only the Android media permission is requested. Your '
                      'files never leave the device.',
                ),
                const Spacer(flex: 3),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _requesting ? null : _requestAccess,
                    icon: _requesting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: palette.onAccent,
                            ),
                          )
                        : const Icon(Icons.library_music_rounded),
                    label: Text(
                      _requesting
                          ? 'Requesting access…'
                          : 'Allow access to my music',
                    ),
                  ),
                ),
                if (_permanentlyDenied) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () =>
                        ref.read(permissionServiceProvider).openSettings(),
                    child: const Text('Open Android settings'),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'JPlayer only reads the media Android indexes. You can revoke '
                  'access at any time in system settings.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePoint extends StatelessWidget {
  const _WelcomePoint({
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, size: 20, color: palette.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
