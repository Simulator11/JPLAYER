import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/providers/core_providers.dart';
import 'data/database/app_database.dart';
import 'data/repositories/music_repository.dart';
import 'data/repositories/playlist_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'features/player/providers/player_providers.dart';
import 'features/player/services/audio_handler.dart';
import 'features/settings/providers/settings_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    final database = AppDatabase();
    await database.open();

    final musicRepository = MusicRepository(database);
    final playlistRepository = PlaylistRepository(database);
    final settingsRepository = SettingsRepository(database);
    final initialSettings = await settingsRepository.loadSettings();

    final audioHandler = await JPlayerAudioHandler.init(
      music: musicRepository,
      playlists: playlistRepository,
      settings: settingsRepository,
    );

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(initialSettings),
          audioHandlerProvider.overrideWithValue(audioHandler),
        ],
        child: const JPlayerApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('JPlayer failed to start: $error\n$stackTrace');
    runApp(_StartupFailureApp(details: error.toString()));
  }
}

class _StartupFailureApp extends StatelessWidget {
  const _StartupFailureApp({required this.details});

  final String details;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.music_off_rounded, size: 64),
                  const SizedBox(height: 20),
                  const Text(
                    'JPlayer could not start',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your music was not changed. Close the app and open it again. '
                    'If the problem continues, clear JPlayer\'s app data.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    details,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
