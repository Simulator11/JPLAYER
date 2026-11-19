import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../data/models/app_settings.dart';
import '../data/models/library_models.dart';
import '../features/music/providers/library_providers.dart';
import '../features/onboarding/screens/welcome_screen.dart';
import '../features/settings/providers/settings_providers.dart';
import '../shared/widgets/common.dart';
import '../shared/widgets/logo.dart';
import 'root_shell.dart';
import 'theme/colors.dart';

/// Decides between onboarding, a first-run scan and the main shell.
class StartupGate extends ConsumerStatefulWidget {
  const StartupGate({super.key});

  @override
  ConsumerState<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends ConsumerState<StartupGate> {
  bool _scanScheduled = false;

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(libraryProvider);
    final settings = ref.watch(settingsProvider);

    return libraryAsync.when(
      loading: () => const _LoadingSplash(),
      error: (error, _) =>
          _ErrorSplash(onRetry: () => ref.invalidate(libraryProvider)),
      data: (snapshot) {
        if (!snapshot.hasPermission) {
          return const WelcomeScreen();
        }
        _maybeScheduleScan(snapshot, settings);
        return const RootShell();
      },
    );
  }

  void _maybeScheduleScan(LibrarySnapshot snapshot, AppSettings settings) {
    if (_scanScheduled) return;
    if (ref.read(scanStatusProvider).isBusy) return;
    final lastScan = snapshot.lastScanAt;
    final needsScan =
        snapshot.isEmpty ||
        lastScan == null ||
        DateTime.now().difference(lastScan) > AppConstants.autoScanInterval;
    if (!settings.scanOnLaunch || !needsScan) return;

    _scanScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await ref.read(libraryProvider.notifier).scan(requestPermission: false);
    });
  }
}

class _LoadingSplash extends StatelessWidget {
  const _LoadingSplash();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const JPLogo(size: 74),
            const SizedBox(height: 18),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              AppConstants.slogan,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorSplash extends StatelessWidget {
  const _ErrorSplash({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('JPlayer')),
      body: EmptyState(
        icon: Icons.error_outline_rounded,
        title: 'JPlayer could not start',
        message:
            'The local library database could not be opened. Please retry, or '
            'restart the application.',
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
    );
  }
}
