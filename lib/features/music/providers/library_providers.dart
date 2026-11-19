import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/services/media_scanner.dart';
import '../../../data/models/library_models.dart';
import '../../../data/models/playlist.dart';
import '../../../data/models/song.dart';
import '../../player/providers/player_providers.dart';

/// Status of the current scan, shown on Home and in Settings.
final scanStatusProvider = NotifierProvider<ScanStatusController, ScanProgress>(
  ScanStatusController.new,
  isAutoDispose: false,
);

class ScanStatusController extends Notifier<ScanProgress> {
  @override
  ScanProgress build() => ScanProgress.idle;

  void update(ScanProgress value) => state = value;

  void reset() => state = ScanProgress.idle;
}

final libraryProvider =
    AsyncNotifierProvider<LibraryController, LibrarySnapshot>(
      LibraryController.new,
      isAutoDispose: false,
    );

class LibraryController extends AsyncNotifier<LibrarySnapshot> {
  @override
  Future<LibrarySnapshot> build() async {
    final granted = await ref
        .read(permissionServiceProvider)
        .hasAudioPermission();
    if (!granted) {
      return LibrarySnapshot.fromSongs(const [], hasPermission: false);
    }
    return _load();
  }

  Future<LibrarySnapshot> _load() async {
    final music = ref.read(musicRepositoryProvider);
    final songs = await music.getSongs();
    final lastScan = await ref.read(settingsRepositoryProvider).lastScanAt();
    return LibrarySnapshot.fromSongs(songs, lastScanAt: lastScan);
  }

  /// Reloads the cached library from SQLite without touching MediaStore.
  Future<void> refresh() async {
    final result = await AsyncValue.guard(_load);
    if (result.hasValue || state.value == null) {
      state = result;
    }
  }

  Future<bool> ensurePermission({bool request = true}) async {
    final permissions = ref.read(permissionServiceProvider);
    if (await permissions.hasAudioPermission()) return true;
    if (!request) return false;
    final granted = await permissions.requestAudioPermission();
    if (granted) await refresh();
    return granted;
  }

  /// Performs a full MediaStore scan and refreshes the snapshot.
  Future<ScanOutcome?> scan({bool requestPermission = true}) async {
    if (!await ensurePermission(request: requestPermission)) return null;
    final scanStatus = ref.read(scanStatusProvider.notifier);
    try {
      final outcome = await ref
          .read(mediaScannerProvider)
          .scan(onProgress: scanStatus.update);
      ref.read(artworkServiceProvider).clear();
      state = AsyncData(await _load());
      return outcome;
    } catch (error, stackTrace) {
      scanStatus.update(
        ScanProgress(phase: ScanPhase.error, message: _friendlyError(error)),
      );
      final previous = state.value;
      state = previous != null
          ? AsyncData(previous)
          : AsyncError(error, stackTrace);
      return null;
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('permission') || text.contains('security')) {
      return 'Media permission is required to read your music.';
    }
    return 'Scan failed. Please try again.';
  }
}

/// IDs of favorited songs; kept in memory for instant heart toggles.
final favoritesProvider = AsyncNotifierProvider<FavoritesController, Set<int>>(
  FavoritesController.new,
  isAutoDispose: false,
);

class FavoritesController extends AsyncNotifier<Set<int>> {
  @override
  Future<Set<int>> build() =>
      ref.read(playlistRepositoryProvider).favoriteIds();

  Future<bool> toggle(int songId) async {
    final newValue = await ref
        .read(playlistRepositoryProvider)
        .toggleFavorite(songId);
    final next = {...(state.value ?? const <int>{})};
    if (newValue) {
      next.add(songId);
    } else {
      next.remove(songId);
    }
    state = AsyncData(next);
    ref.invalidate(smartSongsProvider(SmartPlaylist.favorites));
    return newValue;
  }

  Future<void> setFavoriteForSongs(List<int> songIds, bool favorite) async {
    await ref
        .read(playlistRepositoryProvider)
        .setFavoriteForSongs(songIds, favorite);
    final next = {...(state.value ?? const <int>{})};
    if (favorite) {
      next.addAll(songIds);
    } else {
      next.removeAll(songIds);
    }
    state = AsyncData(next);
    ref.invalidate(smartSongsProvider(SmartPlaylist.favorites));
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(playlistRepositoryProvider).favoriteIds());
  }
}

final playlistsProvider =
    AsyncNotifierProvider<PlaylistsController, List<Playlist>>(
      PlaylistsController.new,
      isAutoDispose: false,
    );

class PlaylistsController extends AsyncNotifier<List<Playlist>> {
  @override
  Future<List<Playlist>> build() =>
      ref.read(playlistRepositoryProvider).playlists();

  Future<Playlist> create(String name) async {
    final playlist = await ref
        .read(playlistRepositoryProvider)
        .createPlaylist(name);
    state = AsyncData([playlist, ...(state.value ?? const [])]);
    return playlist;
  }

  Future<void> rename(int id, String name) async {
    await ref.read(playlistRepositoryProvider).renamePlaylist(id, name);
    await refresh();
  }

  Future<void> delete(int id) async {
    await ref.read(playlistRepositoryProvider).deletePlaylist(id);
    state = AsyncData([
      for (final playlist in state.value ?? const <Playlist>[])
        if (playlist.id != id) playlist,
    ]);
  }

  Future<int> addSongs(int playlistId, List<int> songIds) async {
    final added = await ref
        .read(playlistRepositoryProvider)
        .addSongsToPlaylist(playlistId, songIds);
    await refresh();
    ref.invalidate(playlistSongsProvider(playlistId));
    return added;
  }

  Future<void> removeSong(int playlistId, int songId) async {
    await ref
        .read(playlistRepositoryProvider)
        .removeSongFromPlaylist(playlistId, songId);
    await refresh();
    ref.invalidate(playlistSongsProvider(playlistId));
  }

  Future<void> reorder(int playlistId, List<int> orderedSongIds) async {
    await ref
        .read(playlistRepositoryProvider)
        .reorderPlaylistSongs(playlistId, orderedSongIds);
    ref.invalidate(playlistSongsProvider(playlistId));
  }

  Future<void> refresh() async {
    state = AsyncData(await ref.read(playlistRepositoryProvider).playlists());
  }
}

final playlistSongsProvider = FutureProvider.family<List<Song>, int>((
  ref,
  playlistId,
) {
  return ref.watch(playlistRepositoryProvider).playlistSongs(playlistId);
});

final playlistProvider = FutureProvider.family<Playlist?, int>((
  ref,
  playlistId,
) {
  return ref.watch(playlistRepositoryProvider).playlist(playlistId);
});

final smartSongsProvider = FutureProvider.family<List<Song>, SmartPlaylist>((
  ref,
  type,
) {
  if (type == SmartPlaylist.favorites) {
    ref.watch(favoritesProvider);
  }
  return ref.watch(playlistRepositoryProvider).smartSongs(type);
});

final smartCountsProvider = FutureProvider<Map<SmartPlaylist, int>>((
  ref,
) async {
  ref.watch(favoritesProvider);
  ref.watch(songStartedProvider);
  final repository = ref.watch(playlistRepositoryProvider);
  final counts = <SmartPlaylist, int>{};
  for (final type in SmartPlaylist.values) {
    counts[type] = await repository.smartCount(type);
  }
  return counts;
});

/// Latest listening history refresh whenever a new track starts.
final recentlyPlayedProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(songStartedProvider);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  return ref.watch(playlistRepositoryProvider).recentlyPlayed(limit: 20);
});

final mostPlayedProvider = FutureProvider<List<Song>>((ref) async {
  ref.watch(songStartedProvider);
  await Future<void>.delayed(const Duration(milliseconds: 600));
  return ref.watch(playlistRepositoryProvider).mostPlayed(limit: 20);
});

final recentlyAddedProvider = Provider<List<Song>>((ref) {
  final snapshot = ref.watch(libraryProvider).value;
  if (snapshot == null) return const [];
  final songs = [...snapshot.songs]
    ..sort((a, b) {
      final byDate = b.dateAdded.compareTo(a.dateAdded);
      return byDate != 0 ? byDate : a.title.compareTo(b.title);
    });
  return songs.take(20).toList(growable: false);
});

final recentlyPlayedAlbumsProvider = Provider<List<Album>>((ref) {
  final recent = ref.watch(recentlyPlayedProvider).value ?? const <Song>[];
  return LibrarySnapshot.albumsFrom(recent, maxItems: 10);
});

final excludedFoldersProvider = FutureProvider<List<String>>(
  (ref) => ref.watch(musicRepositoryProvider).excludedFolders(),
);

final videoPermissionProvider = FutureProvider<bool>(
  (ref) => ref.watch(permissionServiceProvider).hasVideoPermission(),
);

final videosProvider = FutureProvider<List<VideoItem>>((ref) async {
  final granted = await ref.watch(videoPermissionProvider.future);
  if (!granted) return const [];
  final channel = ref.watch(mediaChannelProvider);
  final repository = ref.watch(musicRepositoryProvider);
  try {
    final raw = await channel.queryVideos();
    await repository.syncVideos(raw);
  } catch (_) {
    // Videos are optional; the music library remains fully usable.
  }
  return repository.getVideos();
});
