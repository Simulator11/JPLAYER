import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/constants/app_constants.dart';

/// SQLite database that persists the library cache, playlists, history and
/// user preferences. Audio files themselves are never copied into the database.
class AppDatabase {
  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<void> open() async {
    await database;
  }

  Future<Database> _open() async {
    final directory = await getDatabasesPath();
    final path = p.join(directory, AppConstants.databaseName);
    return openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE songs (
        media_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL DEFAULT '',
        artist_id INTEGER,
        album TEXT NOT NULL DEFAULT '',
        album_id INTEGER,
        genre TEXT,
        duration INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL DEFAULT 0,
        date_added INTEGER NOT NULL DEFAULT 0,
        date_modified INTEGER NOT NULL DEFAULT 0,
        path TEXT NOT NULL DEFAULT '',
        uri TEXT NOT NULL DEFAULT '',
        relative_path TEXT NOT NULL DEFAULT '',
        file_name TEXT NOT NULL DEFAULT '',
        track INTEGER NOT NULL DEFAULT 0,
        year INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute('CREATE INDEX idx_songs_path ON songs(path)');
    batch.execute(
      'CREATE INDEX idx_songs_title ON songs(title COLLATE NOCASE)',
    );
    batch.execute(
      'CREATE INDEX idx_songs_artist ON songs(artist COLLATE NOCASE)',
    );
    batch.execute('CREATE INDEX idx_songs_album ON songs(album_id)');
    batch.execute('CREATE INDEX idx_songs_added ON songs(date_added)');
    batch.execute('CREATE INDEX idx_songs_folder ON songs(relative_path)');

    batch.execute('''
      CREATE TABLE favorites (
        song_id INTEGER PRIMARY KEY,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs(media_id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE playlists (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE playlist_songs (
        playlist_id INTEGER NOT NULL,
        song_id INTEGER NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, song_id),
        FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (song_id) REFERENCES songs(media_id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_playlist_songs ON playlist_songs(playlist_id, position)',
    );

    batch.execute('''
      CREATE TABLE play_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        song_id INTEGER NOT NULL,
        played_at INTEGER NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs(media_id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_history_time ON play_history(played_at DESC)',
    );
    batch.execute('CREATE INDEX idx_history_song ON play_history(song_id)');

    batch.execute('''
      CREATE TABLE play_counts (
        song_id INTEGER PRIMARY KEY,
        play_count INTEGER NOT NULL DEFAULT 0,
        last_played INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (song_id) REFERENCES songs(media_id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');
    batch.execute('CREATE INDEX idx_counts ON play_counts(play_count DESC)');

    batch.execute('''
      CREATE TABLE queue (
        position INTEGER PRIMARY KEY,
        song_id INTEGER NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs(media_id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE videos (
        media_id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        path TEXT NOT NULL DEFAULT '',
        uri TEXT NOT NULL DEFAULT '',
        duration INTEGER NOT NULL DEFAULT 0,
        size INTEGER NOT NULL DEFAULT 0,
        date_added INTEGER NOT NULL DEFAULT 0,
        bucket TEXT NOT NULL DEFAULT '',
        width INTEGER NOT NULL DEFAULT 0,
        height INTEGER NOT NULL DEFAULT 0,
        last_position INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE excluded_folders (
        path TEXT PRIMARY KEY COLLATE NOCASE
      )
    ''');

    batch.execute('''
      CREATE TABLE lyrics_paths (
        song_id INTEGER PRIMARY KEY,
        path TEXT NOT NULL,
        FOREIGN KEY (song_id) REFERENCES songs(media_id)
          ON DELETE CASCADE ON UPDATE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE searches (
        query TEXT PRIMARY KEY COLLATE NOCASE,
        searched_at INTEGER NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE eq_presets (
        name TEXT PRIMARY KEY COLLATE NOCASE,
        gains TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
