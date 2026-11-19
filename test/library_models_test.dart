import 'package:flutter_test/flutter_test.dart';

import 'package:jplayer/core/services/media_scanner.dart';
import 'package:jplayer/data/models/app_settings.dart';
import 'package:jplayer/data/models/library_models.dart';
import 'package:jplayer/data/models/song.dart';

Song _song({
  required int id,
  required String title,
  required String artist,
  required String album,
  int? albumId,
  String? genre,
  String folder = 'Music',
  int duration = 200000,
}) {
  return Song(
    id: id,
    title: title,
    artist: artist,
    artistId: 1,
    album: album,
    albumId: albumId ?? 10,
    genre: genre,
    durationMs: duration,
    sizeBytes: 5000000,
    dateAdded: 1000 + id,
    dateModified: 1000 + id,
    path: '/storage/emulated/0/$folder/$title.mp3',
    uri: 'content://media/external/audio/media/$id',
    relativePath: folder,
    fileName: '$title.mp3',
    track: id,
    year: 2024,
  );
}

void main() {
  test('derives albums, artists, genres and folders', () {
    final songs = [
      _song(id: 1, title: 'One', artist: 'A', album: 'Alpha', genre: 'Rock'),
      _song(id: 2, title: 'Two', artist: 'A', album: 'Alpha', genre: 'Rock'),
      _song(
        id: 3,
        title: 'Three',
        artist: 'B',
        album: 'Beta',
        albumId: 11,
        genre: 'Jazz',
        folder: 'Music/Live',
      ),
    ];
    final snapshot = LibrarySnapshot.fromSongs(songs);

    expect(snapshot.albums.length, 2);
    expect(snapshot.albums.first.title, 'Alpha');
    expect(snapshot.songsOfAlbum(snapshot.albums.first).length, 2);
    expect(snapshot.artists.length, 2);
    expect(snapshot.genres.length, 2);
    expect(snapshot.folders.length, 2);
    expect(snapshot.songsOfFolder(snapshot.folders.last).length, 1);
    expect(snapshot.songsOfArtist(snapshot.artists.first).length, 2);
  });

  test('excluded folder matching uses path prefixes', () {
    expect(
      MediaScannerService.isExcluded('Music/Ringtones', ['Music/Ringtones']),
      isTrue,
    );
    expect(
      MediaScannerService.isExcluded('Music/Ringtones/Sub', [
        'music/ringtones',
      ]),
      isTrue,
    );
    expect(
      MediaScannerService.isExcluded('Music/Albums', ['Music/Ringtones']),
      isFalse,
    );
    expect(MediaScannerService.isExcluded('', ['Music/Ringtones']), isFalse);
  });

  test('system sound folders are not treated as music', () {
    expect(MediaScannerService.isSystemSound('Ringtones/ping.mp3'), isTrue);
    expect(MediaScannerService.isSystemSound('Music/Alarms'), isTrue);
    expect(MediaScannerService.isSystemSound('Notifications'), isTrue);
    expect(MediaScannerService.isSystemSound('Music/Albums'), isFalse);
    expect(MediaScannerService.isSystemSound(''), isFalse);
  });

  test('app settings survive a JSON round trip', () {
    const settings = AppSettings(
      theme: ThemeSetting.dark,
      amoled: true,
      scanOnLaunch: false,
      resumeLastSession: false,
      equalizerEnabled: true,
      equalizerPreset: 'Custom',
      equalizerGains: [1, -2, 3],
      bassBoost: 2.5,
      trebleBoost: -1,
      loudnessGain: 4,
      repeatMode: RepeatSetting.all,
    );
    final restored = AppSettings.fromJson(settings.toJson());
    expect(restored.theme, ThemeSetting.dark);
    expect(restored.amoled, isTrue);
    expect(restored.scanOnLaunch, isFalse);
    expect(restored.equalizerPreset, 'Custom');
    expect(restored.equalizerGains, [1.0, -2.0, 3.0]);
    expect(restored.repeatMode, RepeatSetting.all);
  });
}
