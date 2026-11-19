import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'navigation.dart';
import 'theme/colors.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/music/screens/music_library_screen.dart';
import '../../features/playlists/screens/playlists_screen.dart';
import '../../features/player/providers/player_providers.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../shared/widgets/mini_player.dart';

/// Root navigation: four tabs with a persistent mini player above the bar.
class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(rootTabProvider);
    final palette = context.palette;

    ref.listen<AsyncValue<String>>(playerErrorProvider, (previous, next) {
      final error = next.value;
      if (error != null && error != previous?.value) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
      }
    });

    ref.listen<bool>(sleepTimerProvider.select((value) => value.justFinished), (
      previous,
      next,
    ) {
      if (next && previous != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sleep timer finished — playback paused.'),
          ),
        );
        ref.read(sleepTimerProvider.notifier).acknowledgeFinished();
      }
    });

    return PopScope(
      canPop: index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && index != 0) {
          ref.read(rootTabProvider.notifier).select(0);
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        body: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            MusicLibraryScreen(),
            PlaylistsScreen(),
            SettingsScreen(),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) =>
                  ref.read(rootTabProvider.notifier).select(value),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.library_music_outlined),
                  selectedIcon: Icon(Icons.library_music_rounded),
                  label: 'Music',
                ),
                NavigationDestination(
                  icon: Icon(Icons.queue_music_outlined),
                  selectedIcon: Icon(Icons.queue_music_rounded),
                  label: 'Playlists',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded),
                  label: 'Settings',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
