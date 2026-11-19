import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/app_database.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../services/artwork_service.dart';
import '../services/backup_service.dart';
import '../services/media_channel.dart';
import '../services/media_scanner.dart';
import '../services/permission_service.dart';

/// Overridden in main() with the opened database instance.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw StateError('databaseProvider must be overridden in main()'),
);

final musicRepositoryProvider = Provider<MusicRepository>(
  (ref) => MusicRepository(ref.watch(databaseProvider)),
);

final playlistRepositoryProvider = Provider<PlaylistRepository>(
  (ref) => PlaylistRepository(ref.watch(databaseProvider)),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);

final mediaChannelProvider = Provider<MediaChannel>((ref) => MediaChannel());

final artworkServiceProvider = Provider<ArtworkService>(
  (ref) => ArtworkService(ref.watch(mediaChannelProvider)),
);

final permissionServiceProvider = Provider<PermissionService>(
  (ref) => PermissionService(ref.watch(mediaChannelProvider)),
);

final mediaScannerProvider = Provider<MediaScannerService>(
  (ref) => MediaScannerService(
    ref.watch(mediaChannelProvider),
    ref.watch(musicRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  ),
);

final backupServiceProvider = Provider<BackupService>(
  (ref) => BackupService(
    music: ref.watch(musicRepositoryProvider),
    playlists: ref.watch(playlistRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
  ),
);
