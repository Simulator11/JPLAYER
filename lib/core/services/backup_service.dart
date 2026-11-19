import 'dart:convert';

import '../../data/models/app_settings.dart';
import '../../data/models/playlist.dart';
import '../../data/repositories/music_repository.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../data/repositories/settings_repository.dart';

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.favoritesRestored,
    required this.playlistsRestored,
    required this.songsMatched,
    required this.songsMissing,
    required this.settingsRestored,
  });

  final int favoritesRestored;
  final int playlistsRestored;
  final int songsMatched;
  final int songsMissing;
  final bool settingsRestored;
}

/// Exports and imports JPlayer's user data as a single JSON document.
///
/// Only metadata and file references are written; audio never leaves the
/// device. Restoring matches songs by file path so backups survive rescans.
class BackupService {
  BackupService({
    required this.music,
    required this.playlists,
    required this.settings,
  });

  final MusicRepository music;
  final PlaylistRepository playlists;
  final SettingsRepository settings;

  Future<String> exportJson() async {
    final songs = await music.getSongs();
    final pathById = <int, String>{};
    for (final song in songs) {
      final key = song.path.isNotEmpty ? song.path : song.uri;
      if (key.isNotEmpty) pathById[song.id] = key;
    }

    final favorites = await playlists.favoriteSongs();
    final userPlaylists = await playlists.playlists();
    final playlistData = <Map<String, Object?>>[];
    for (final playlist in userPlaylists) {
      final playlistSongs = await playlists.playlistSongs(playlist.id);
      playlistData.add({
        'name': playlist.name,
        'songs': [
          for (final song in playlistSongs)
            if (pathById[song.id] != null) pathById[song.id]!,
        ],
      });
    }

    final appSettings = await settings.loadSettings();
    final presets = await settings.equalizerPresets();
    final excluded = await music.excludedFolders();

    final document = <String, Object?>{
      'app': 'JPlayer',
      'format': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': appSettings.toJson(),
      'favorites': [
        for (final song in favorites)
          if (pathById[song.id] != null) pathById[song.id]!,
      ],
      'playlists': playlistData,
      'excludedFolders': excluded,
      'equalizerPresets': [
        for (final preset in presets)
          {'name': preset.name, 'gains': preset.gains},
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(document);
  }

  Future<BackupRestoreResult> restoreJson(String json) async {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('This file is not a JPlayer backup.');
    }
    if (decoded['app'] != 'JPlayer') {
      throw const FormatException('This file is not a JPlayer backup.');
    }

    final songs = await music.getSongs();
    final idByPath = <String, int>{};
    for (final song in songs) {
      if (song.path.isNotEmpty) idByPath[song.path] = song.id;
      if (song.uri.isNotEmpty) idByPath[song.uri] = song.id;
    }

    var matched = 0;
    var missing = 0;
    int? resolve(Object? path) {
      if (path is! String || path.isEmpty) return null;
      final id = idByPath[path];
      if (id == null) {
        missing++;
      } else {
        matched++;
      }
      return id;
    }

    var favoritesRestored = 0;
    final favoritePaths = decoded['favorites'];
    if (favoritePaths is List) {
      final ids = <int>[];
      for (final path in favoritePaths) {
        final id = resolve(path);
        if (id != null) ids.add(id);
      }
      if (ids.isNotEmpty) {
        await playlists.setFavoriteForSongs(ids, true);
      }
      favoritesRestored = ids.length;
    }

    var playlistsRestored = 0;
    final rawPlaylists = decoded['playlists'];
    if (rawPlaylists is List) {
      for (final entry in rawPlaylists) {
        if (entry is! Map) continue;
        final name = (entry['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;

        Playlist? target;
        try {
          target = await playlists.createPlaylist(name);
        } on PlaylistNameConflict {
          final existing = await playlists.playlists();
          for (final playlist in existing) {
            if (playlist.name.toLowerCase() == name.toLowerCase()) {
              target = playlist;
              break;
            }
          }
        }
        if (target == null) continue;

        final rawSongs = entry['songs'];
        if (rawSongs is List) {
          final ids = <int>[];
          for (final path in rawSongs) {
            final id = resolve(path);
            if (id != null) ids.add(id);
          }
          await playlists.addSongsToPlaylist(target.id, ids);
        }
        playlistsRestored++;
      }
    }

    final rawExcluded = decoded['excludedFolders'];
    if (rawExcluded is List) {
      for (final path in rawExcluded) {
        if (path is String && path.trim().isNotEmpty) {
          await music.excludeFolder(path);
        }
      }
    }

    final rawPresets = decoded['equalizerPresets'];
    if (rawPresets is List) {
      for (final entry in rawPresets) {
        if (entry is! Map) continue;
        final name = (entry['name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        final rawGains = entry['gains'];
        final gains = <double>[];
        if (rawGains is List) {
          for (final gain in rawGains) {
            if (gain is num) gains.add(gain.toDouble());
          }
        }
        await settings.saveEqualizerPreset(name, gains);
      }
    }

    var settingsRestored = false;
    final rawSettings = decoded['settings'];
    if (rawSettings is Map) {
      final restored = AppSettings.fromJson(
        Map<String, Object?>.from(rawSettings),
      );
      await settings.saveSettings(restored);
      settingsRestored = true;
    }

    return BackupRestoreResult(
      favoritesRestored: favoritesRestored,
      playlistsRestored: playlistsRestored,
      songsMatched: matched,
      songsMissing: missing,
      settingsRestored: settingsRestored,
    );
  }
}
