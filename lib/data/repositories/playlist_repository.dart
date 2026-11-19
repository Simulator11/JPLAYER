import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/library_models.dart';
import '../models/playlist.dart';
import '../models/song.dart';

/// Thrown when a playlist name collides with an existing one.
class PlaylistNameConflict implements Exception {
  const PlaylistNameConflict(this.name);

  final String name;

  @override
  String toString() => 'A playlist named "$name" already exists.';
}

/// Favorites, user playlists and listening-history based smart lists.
class PlaylistRepository {
  PlaylistRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<Database> get _db => _appDatabase.database;

  // ---------------------------------------------------------------------
  // Favorites
  // ---------------------------------------------------------------------

  Future<Set<int>> favoriteIds() async {
    final db = await _db;
    final rows = await db.query('favorites', columns: ['song_id']);
    return rows.map((row) => row['song_id'] as int).toSet();
  }

  Future<bool> isFavorite(int songId) async {
    final db = await _db;
    final rows = await db.query(
      'favorites',
      columns: ['song_id'],
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Returns `true` if the song is now a favorite.
  Future<bool> toggleFavorite(int songId) async {
    final db = await _db;
    return db.transaction<bool>((txn) async {
      final existing = await txn.query(
        'favorites',
        columns: ['song_id'],
        where: 'song_id = ?',
        whereArgs: [songId],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await txn.delete(
          'favorites',
          where: 'song_id = ?',
          whereArgs: [songId],
        );
        return false;
      }
      await txn.insert('favorites', {
        'song_id': songId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      return true;
    });
  }

  Future<void> setFavorite(int songId, bool favorite) async {
    final db = await _db;
    if (favorite) {
      await db.insert('favorites', {
        'song_id': songId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await db.delete('favorites', where: 'song_id = ?', whereArgs: [songId]);
    }
  }

  Future<void> setFavoriteForSongs(List<int> songIds, bool favorite) async {
    if (songIds.isEmpty) return;
    final db = await _db;
    final batch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final id in songIds) {
      if (favorite) {
        batch.insert('favorites', {
          'song_id': id,
          'added_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      } else {
        batch.delete('favorites', where: 'song_id = ?', whereArgs: [id]);
      }
    }
    await batch.commit(noResult: true);
  }

  Future<List<Song>> favoriteSongs({int? limit}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT s.* FROM songs s '
      'INNER JOIN favorites f ON f.song_id = s.media_id '
      'ORDER BY f.added_at DESC'
      '${limit != null ? ' LIMIT $limit' : ''}',
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<int> favoriteCount() async {
    final db = await _db;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM favorites f '
            'INNER JOIN songs s ON s.media_id = f.song_id',
          ),
        ) ??
        0;
  }

  // ---------------------------------------------------------------------
  // Playlists
  // ---------------------------------------------------------------------

  Future<List<Playlist>> playlists() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT p.*, '
      '(SELECT COUNT(*) FROM playlist_songs ps WHERE ps.playlist_id = p.id) '
      'AS song_count '
      'FROM playlists p ORDER BY p.updated_at DESC',
    );
    return rows.map(Playlist.fromMap).toList(growable: false);
  }

  Future<Playlist?> playlist(int id) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT p.*, '
      '(SELECT COUNT(*) FROM playlist_songs ps WHERE ps.playlist_id = p.id) '
      'AS song_count '
      'FROM playlists p WHERE p.id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : Playlist.fromMap(rows.first);
  }

  Future<Playlist> createPlaylist(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const PlaylistNameConflict('Untitled playlist');
    }
    final db = await _db;
    final clash = await db.query(
      'playlists',
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (clash.isNotEmpty) throw PlaylistNameConflict(trimmed);
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await db.insert('playlists', {
      'name': trimmed,
      'created_at': now,
      'updated_at': now,
    });
    return Playlist(
      id: id,
      name: trimmed,
      songCount: 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(now),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(now),
    );
  }

  Future<void> renamePlaylist(int id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final db = await _db;
    final clash = await db.query(
      'playlists',
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE AND id != ?',
      whereArgs: [trimmed, id],
      limit: 1,
    );
    if (clash.isNotEmpty) throw PlaylistNameConflict(trimmed);
    await db.update(
      'playlists',
      {'name': trimmed, 'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePlaylist(int id) async {
    final db = await _db;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Song>> playlistSongs(int playlistId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT s.* FROM songs s '
      'INNER JOIN playlist_songs ps ON ps.song_id = s.media_id '
      'WHERE ps.playlist_id = ? ORDER BY ps.position ASC',
      [playlistId],
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  /// Adds songs that are not already in the playlist. Returns how many were
  /// actually added.
  Future<int> addSongsToPlaylist(int playlistId, List<int> songIds) async {
    if (songIds.isEmpty) return 0;
    final db = await _db;
    return db.transaction<int>((txn) async {
      final existingRows = await txn.query(
        'playlist_songs',
        columns: ['song_id'],
        where: 'playlist_id = ?',
        whereArgs: [playlistId],
      );
      final existing = existingRows.map((row) => row['song_id'] as int).toSet();
      final maxPosition =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT MAX(position) FROM playlist_songs WHERE playlist_id = ?',
              [playlistId],
            ),
          ) ??
          -1;
      var position = maxPosition + 1;
      var inserted = 0;
      final batch = txn.batch();
      for (final songId in songIds) {
        if (!existing.add(songId)) continue;
        batch.insert('playlist_songs', {
          'playlist_id': playlistId,
          'song_id': songId,
          'position': position++,
        });
        inserted++;
      }
      if (inserted > 0) {
        await batch.commit(noResult: true);
        await txn.update(
          'playlists',
          {'updated_at': DateTime.now().millisecondsSinceEpoch},
          where: 'id = ?',
          whereArgs: [playlistId],
        );
      }
      return inserted;
    });
  }

  Future<void> removeSongFromPlaylist(int playlistId, int songId) async {
    final db = await _db;
    await db.delete(
      'playlist_songs',
      where: 'playlist_id = ? AND song_id = ?',
      whereArgs: [playlistId, songId],
    );
    await db.update(
      'playlists',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> reorderPlaylistSongs(
    int playlistId,
    List<int> orderedSongIds,
  ) async {
    final db = await _db;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < orderedSongIds.length; i++) {
        batch.update(
          'playlist_songs',
          {'position': i},
          where: 'playlist_id = ? AND song_id = ?',
          whereArgs: [playlistId, orderedSongIds[i]],
        );
      }
      batch.update(
        'playlists',
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [playlistId],
      );
      await batch.commit(noResult: true);
    });
  }

  // ---------------------------------------------------------------------
  // Listening history & smart lists
  // ---------------------------------------------------------------------

  Future<void> recordPlay(int songId) async {
    final db = await _db;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      await txn.insert('play_history', {'song_id': songId, 'played_at': now});
      await txn.insert('play_counts', {
        'song_id': songId,
        'play_count': 0,
        'last_played': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      await txn.rawUpdate(
        'UPDATE play_counts SET play_count = play_count + 1, last_played = ? '
        'WHERE song_id = ?',
        [now, songId],
      );
      // Keep the history table bounded; the app never needs more than this.
      await txn.rawDelete(
        'DELETE FROM play_history WHERE id NOT IN '
        '(SELECT id FROM play_history ORDER BY played_at DESC LIMIT 5000)',
      );
    });
  }

  Future<List<Song>> recentlyPlayed({int limit = 50}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT s.* FROM songs s '
      'INNER JOIN ('
      '  SELECT song_id, MAX(played_at) AS last_played '
      '  FROM play_history GROUP BY song_id'
      ') h ON h.song_id = s.media_id '
      'ORDER BY h.last_played DESC LIMIT ?',
      [limit],
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<List<Song>> mostPlayed({int limit = 50}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT s.* FROM songs s '
      'INNER JOIN play_counts c ON c.song_id = s.media_id '
      'WHERE c.play_count > 0 '
      'ORDER BY c.play_count DESC, c.last_played DESC LIMIT ?',
      [limit],
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<List<Song>> recentlyAdded({int limit = 50}) async {
    final db = await _db;
    final rows = await db.query(
      'songs',
      orderBy: 'date_added DESC, title COLLATE NOCASE ASC',
      limit: limit,
    );
    return rows.map(Song.fromMap).toList(growable: false);
  }

  Future<int> playCount(int songId) async {
    final db = await _db;
    final rows = await db.query(
      'play_counts',
      columns: ['play_count'],
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['play_count'] as int?) ?? 0;
  }

  Future<List<Song>> smartSongs(SmartPlaylist type, {int limit = 500}) async {
    switch (type) {
      case SmartPlaylist.favorites:
        return favoriteSongs(limit: limit);
      case SmartPlaylist.recentlyPlayed:
        return recentlyPlayed(limit: limit);
      case SmartPlaylist.mostPlayed:
        return mostPlayed(limit: limit);
      case SmartPlaylist.recentlyAdded:
        return recentlyAdded(limit: limit);
    }
  }

  Future<int> smartCount(SmartPlaylist type) async {
    final db = await _db;
    switch (type) {
      case SmartPlaylist.favorites:
        return favoriteCount();
      case SmartPlaylist.recentlyPlayed:
        return Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(DISTINCT song_id) FROM play_history',
              ),
            ) ??
            0;
      case SmartPlaylist.mostPlayed:
        return Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) FROM play_counts WHERE play_count > 0',
              ),
            ) ??
            0;
      case SmartPlaylist.recentlyAdded:
        return Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM songs'),
            ) ??
            0;
    }
  }
}
