import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/library_models.dart';
import '../models/playlist.dart';
import '../models/song.dart';

/// Result of reconciling MediaStore with the local cache.
class SyncResult {
  const SyncResult({
    required this.total,
    required this.added,
    required this.updated,
    required this.removed,
  });

  final int total;
  final int added;
  final int updated;
  final int removed;

  static const SyncResult empty = SyncResult(
    total: 0,
    added: 0,
    updated: 0,
    removed: 0,
  );
}

/// Reads and writes the cached music library, videos and folder exclusions.
class MusicRepository {
  MusicRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  Future<List<Song>> getSongs({SongSort sort = SongSort.title}) async {
    final db = await _db;
    final rows = await db.query('songs', orderBy: sort.sqlOrder);
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<Song?> getSong(int id) async {
    final db = await _db;
    final rows = await db.query(
      'songs',
      where: 'media_id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Song.fromMap(rows.first);
  }

  /// Returns songs in the same order as [ids].
  Future<List<Song>> getSongsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final db = await _db;
    final songsById = <int, Song>{};
    for (var start = 0; start < ids.length; start += 400) {
      final chunk = ids.sublist(start, (start + 400).clamp(0, ids.length));
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await db.query(
        'songs',
        where: 'media_id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final song = Song.fromMap(row);
        songsById[song.id] = song;
      }
    }
    return [
      for (final id in ids)
        if (songsById[id] != null) songsById[id]!,
    ];
  }

  Future<int> countSongs() async {
    final db = await _db;
    return Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM songs'),
        ) ??
        0;
  }

  /// Reconciles a fresh MediaStore scan with the local cache.
  ///
  /// - Existing rows are updated in place so favorites and playlists survive.
  /// - New files are inserted.
  /// - Rows whose files disappeared from MediaStore are removed; foreign keys
  ///   cascade the cleanup to favorites, playlists, history and the queue.
  Future<SyncResult> syncSongs(
    List<Map<String, dynamic>> mediaSongs, {
    void Function(int processed, int total)? onProgress,
  }) async {
    final db = await _db;
    final total = mediaSongs.length;

    return db.transaction<SyncResult>((txn) async {
      final existing = await txn.query(
        'songs',
        columns: ['media_id', 'path', 'uri'],
      );
      final byPath = <String, int>{
        for (final row in existing)
          _songKey(row['path'] as String?, row['uri'] as String?):
              row['media_id'] as int,
      };
      final byMediaId = <int, String>{
        for (final row in existing)
          row['media_id'] as int: _songKey(
            row['path'] as String?,
            row['uri'] as String?,
          ),
      };
      final scannedPaths = <String>{};

      var added = 0;
      var updated = 0;
      var processed = 0;
      var batch = txn.batch();
      var pending = 0;

      Future<void> flush() async {
        if (pending == 0) return;
        await batch.commit(noResult: true);
        batch = txn.batch();
        pending = 0;
      }

      for (final media in mediaSongs) {
        final row = _rowFromMedia(media);
        final path = row['path'] as String;
        final uri = row['uri'] as String? ?? '';
        final key = _songKey(path, uri);
        final mediaId = row['media_id'] as int;
        scannedPaths.add(key);

        final existingId = byPath[key];
        final mediaIdOwnerPath = byMediaId[mediaId];

        if (existingId != null) {
          // Same file: keep its identity so related rows stay attached.
          row['media_id'] = existingId;
          batch.update(
            'songs',
            row,
            where: 'media_id = ?',
            whereArgs: [existingId],
          );
          updated++;
        } else if (mediaIdOwnerPath != null && mediaIdOwnerPath != key) {
          // MediaStore reused an id for a different path; treat it as an update.
          row['media_id'] = mediaId;
          batch.update(
            'songs',
            row,
            where: 'media_id = ?',
            whereArgs: [mediaId],
          );
          updated++;
        } else {
          batch.insert(
            'songs',
            row,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          added++;
        }

        pending++;
        processed++;
        if (pending >= 300) {
          await flush();
          onProgress?.call(processed, total);
        }
      }
      await flush();
      onProgress?.call(processed, total);

      // Remove songs that are no longer present in MediaStore.
      final staleIds = <int>[];
      for (final row in existing) {
        final key = _songKey(row['path'] as String?, row['uri'] as String?);
        if (!scannedPaths.contains(key)) {
          staleIds.add(row['media_id'] as int);
        }
      }
      var removed = 0;
      for (var start = 0; start < staleIds.length; start += 400) {
        final chunk = staleIds.sublist(
          start,
          (start + 400).clamp(0, staleIds.length),
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        removed += await txn.delete(
          'songs',
          where: 'media_id IN ($placeholders)',
          whereArgs: chunk,
        );
      }

      return SyncResult(
        total: total,
        added: added,
        updated: updated,
        removed: removed,
      );
    });
  }

  // ---------------------------------------------------------------------
  // Videos (secondary feature)
  // ---------------------------------------------------------------------

  Future<List<VideoItem>> getVideos() async {
    final db = await _db;
    final rows = await db.query('videos', orderBy: 'date_added DESC');
    return rows.map(VideoItem.fromMap).toList(growable: false);
  }

  Future<SyncResult> syncVideos(List<Map<String, dynamic>> mediaVideos) async {
    final db = await _db;
    return db.transaction<SyncResult>((txn) async {
      final existingRows = await txn.query('videos', columns: ['media_id']);
      final existingIds = existingRows
          .map((row) => row['media_id'] as int)
          .toSet();
      final scannedIds = <int>{};
      var added = 0;
      var updated = 0;

      final batch = txn.batch();
      for (final media in mediaVideos) {
        final id = _toInt(media['id']);
        if (id <= 0) continue;
        scannedIds.add(id);
        final row = <String, Object?>{
          'media_id': id,
          'title': (media['title'] as String?) ?? 'Video',
          'path': (media['path'] as String?) ?? '',
          'uri': (media['uri'] as String?) ?? '',
          'duration': _toInt(media['duration']),
          'size': _toInt(media['size']),
          'date_added': _toInt(media['dateAdded']),
          'bucket': (media['bucket'] as String?) ?? '',
          'width': _toInt(media['width']),
          'height': _toInt(media['height']),
        };
        if (existingIds.contains(id)) {
          batch.update('videos', row, where: 'media_id = ?', whereArgs: [id]);
          updated++;
        } else {
          batch.insert('videos', row);
          added++;
        }
      }
      await batch.commit(noResult: true);

      var removed = 0;
      final stale = existingIds.difference(scannedIds).toList();
      for (var start = 0; start < stale.length; start += 400) {
        final chunk = stale.sublist(
          start,
          (start + 400).clamp(0, stale.length),
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        removed += await txn.delete(
          'videos',
          where: 'media_id IN ($placeholders)',
          whereArgs: chunk,
        );
      }

      return SyncResult(
        total: mediaVideos.length,
        added: added,
        updated: updated,
        removed: removed,
      );
    });
  }

  Future<void> updateVideoPosition(int videoId, int positionMs) async {
    final db = await _db;
    await db.update(
      'videos',
      {'last_position': positionMs},
      where: 'media_id = ?',
      whereArgs: [videoId],
    );
  }

  // ---------------------------------------------------------------------
  // Folder exclusions
  // ---------------------------------------------------------------------

  Future<List<String>> excludedFolders() async {
    final db = await _db;
    final rows = await db.query('excluded_folders', orderBy: 'path ASC');
    return rows.map((row) => row['path'] as String).toList(growable: false);
  }

  Future<void> excludeFolder(String path) async {
    final normalized = _normalizeFolder(path);
    if (normalized.isEmpty) return;
    final db = await _db;
    await db.insert('excluded_folders', {
      'path': normalized,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    // Remove anything already cached from the excluded folder.
    await db.delete(
      'songs',
      where: 'relative_path = ? OR relative_path LIKE ?',
      whereArgs: [normalized, '$normalized/%'],
    );
  }

  Future<void> includeFolder(String path) async {
    final db = await _db;
    await db.delete('excluded_folders', where: 'path = ?', whereArgs: [path]);
  }

  // ---------------------------------------------------------------------
  // Search
  // ---------------------------------------------------------------------

  Future<List<Song>> searchSongs(String query, {int limit = 200}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    final pattern = '%${_escapeLike(trimmed)}%';
    final db = await _db;
    final rows = await db.query(
      'songs',
      where:
          "title LIKE ? ESCAPE '\\' "
          "OR artist LIKE ? ESCAPE '\\' "
          "OR album LIKE ? ESCAPE '\\' "
          "OR genre LIKE ? ESCAPE '\\' "
          "OR file_name LIKE ? ESCAPE '\\'",
      whereArgs: [pattern, pattern, pattern, pattern, pattern],
      orderBy: 'title COLLATE NOCASE ASC',
      limit: limit,
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<List<String>> searchHistory({int limit = 8}) async {
    final db = await _db;
    final rows = await db.query(
      'searches',
      orderBy: 'searched_at DESC',
      limit: limit,
    );
    return rows.map((row) => row['query'] as String).toList(growable: false);
  }

  Future<void> addSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final db = await _db;
    await db.insert('searches', {
      'query': trimmed,
      'searched_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.rawDelete(
      'DELETE FROM searches WHERE query NOT IN '
      '(SELECT query FROM searches ORDER BY searched_at DESC LIMIT 20)',
    );
  }

  Future<void> clearSearchHistory() async {
    final db = await _db;
    await db.delete('searches');
  }
}

Map<String, Object?> _rowFromMedia(Map<String, dynamic> media) {
  final fileName = (media['fileName'] as String?) ?? '';
  var title = (media['title'] as String?)?.trim() ?? '';
  if (title.isEmpty) {
    if (fileName.isNotEmpty) {
      final dot = fileName.lastIndexOf('.');
      title = dot > 0 ? fileName.substring(0, dot) : fileName;
    } else {
      title = 'Unknown track';
    }
  }
  final genre = (media['genre'] as String?)?.trim();
  final relativePath = ((media['relativePath'] as String?) ?? '')
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'^/+|/+$'), '');

  return {
    'media_id': _toInt(media['id']),
    'title': title,
    'artist': ((media['artist'] as String?) ?? '').trim(),
    'artist_id': _toNullableInt(media['artistId']),
    'album': ((media['album'] as String?) ?? '').trim(),
    'album_id': _toNullableInt(media['albumId']),
    'genre': genre == null || genre.isEmpty ? null : genre,
    'duration': _toInt(media['duration']),
    'size': _toInt(media['size']),
    'date_added': _toInt(media['dateAdded']),
    'date_modified': _toInt(media['dateModified']),
    'path': (media['path'] as String?) ?? '',
    'uri': (media['uri'] as String?) ?? '',
    'relative_path': relativePath,
    'file_name': fileName,
    'track': _toInt(media['track']),
    'year': _toInt(media['year']),
  };
}

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _toNullableInt(Object? value) {
  final parsed = _toInt(value);
  return parsed == 0 ? null : parsed;
}

String _escapeLike(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll('%', '\\%')
    .replaceAll('_', '\\_');

String _normalizeFolder(String path) =>
    path.trim().replaceAll('\\', '/').replaceAll(RegExp(r'^/+|/+$'), '');

/// Songs normally reconcile by file path. Content-URI-only MediaStore rows
/// (DATA unavailable) fall back to their content URI so they still update and
/// prune correctly.
String _songKey(String? path, String? uri) {
  if (path != null && path.isNotEmpty) return path;
  return uri ?? '';
}
