import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/app_settings.dart';

/// Persists preferences, playback state, lyrics overrides and EQ presets.
class SettingsRepository {
  SettingsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  static const String _settingsKey = 'app_settings';
  static const String _lastSongKey = 'last_song_id';
  static const String _lastPositionKey = 'last_position_ms';
  static const String _queueIndexKey = 'queue_index';
  static const String _lastScanKey = 'last_scan_at';

  Future<Database> get _db => _appDatabase.database;

  Future<AppSettings> loadSettings() async {
    final raw = await getValue(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AppSettings.fromJson(decoded);
      }
      if (decoded is Map) {
        return AppSettings.fromJson(Map<String, Object?>.from(decoded));
      }
    } catch (_) {
      // Corrupt preferences should never block app startup.
    }
    return const AppSettings();
  }

  Future<void> saveSettings(AppSettings settings) async {
    await setValue(_settingsKey, jsonEncode(settings.toJson()));
  }

  Future<String?> getValue(String key) async {
    final db = await _db;
    final rows = await db.query(
      'settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setValue(String key, String value) async {
    final db = await _db;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeValue(String key) async {
    final db = await _db;
    await db.delete('settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<Map<String, String>> allValues() async {
    final db = await _db;
    final rows = await db.query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  // ---------------------------------------------------------------------
  // Playback persistence
  // ---------------------------------------------------------------------

  Future<void> saveLastPosition(int songId, int positionMs) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert('settings', {
        'key': _lastSongKey,
        'value': '$songId',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('settings', {
        'key': _lastPositionKey,
        'value': '$positionMs',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<({int? songId, int positionMs})> loadLastPosition() async {
    final songId = int.tryParse(await getValue(_lastSongKey) ?? '');
    final position = int.tryParse(await getValue(_lastPositionKey) ?? '') ?? 0;
    return (songId: songId, positionMs: position);
  }

  Future<void> saveQueue(List<int> songIds, int index) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('queue');
      final batch = txn.batch();
      for (var i = 0; i < songIds.length; i++) {
        batch.insert('queue', {'position': i, 'song_id': songIds[i]});
      }
      await batch.commit(noResult: true);
      await txn.insert('settings', {
        'key': _queueIndexKey,
        'value': '$index',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<({List<int> songIds, int index})> loadQueue() async {
    final db = await _db;
    final rows = await db.query('queue', orderBy: 'position ASC');
    final index = int.tryParse(await getValue(_queueIndexKey) ?? '') ?? 0;
    return (
      songIds: rows.map((row) => row['song_id'] as int).toList(),
      index: index,
    );
  }

  Future<void> saveQueueIndex(int index) => setValue(_queueIndexKey, '$index');

  // ---------------------------------------------------------------------
  // Scan metadata
  // ---------------------------------------------------------------------

  Future<DateTime?> lastScanAt() async {
    final millis = int.tryParse(await getValue(_lastScanKey) ?? '');
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastScanAt(DateTime value) =>
      setValue(_lastScanKey, '${value.millisecondsSinceEpoch}');

  // ---------------------------------------------------------------------
  // Lyrics overrides
  // ---------------------------------------------------------------------

  Future<String?> lyricsPath(int songId) async {
    final db = await _db;
    final rows = await db.query(
      'lyrics_paths',
      columns: ['path'],
      where: 'song_id = ?',
      whereArgs: [songId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['path'] as String?;
  }

  Future<void> setLyricsPath(int songId, String path) async {
    final db = await _db;
    await db.insert('lyrics_paths', {
      'song_id': songId,
      'path': path,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearLyricsPath(int songId) async {
    final db = await _db;
    await db.delete('lyrics_paths', where: 'song_id = ?', whereArgs: [songId]);
  }

  // ---------------------------------------------------------------------
  // Custom equalizer presets
  // ---------------------------------------------------------------------

  Future<List<EqualizerPresetRecord>> equalizerPresets() async {
    final db = await _db;
    final rows = await db.query('eq_presets', orderBy: 'created_at ASC');
    return rows.map(EqualizerPresetRecord.fromMap).toList(growable: false);
  }

  Future<void> saveEqualizerPreset(String name, List<double> gains) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final db = await _db;
    await db.insert('eq_presets', {
      'name': trimmed,
      'gains': gains.map((g) => g.toStringAsFixed(1)).join(','),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteEqualizerPreset(String name) async {
    final db = await _db;
    await db.delete(
      'eq_presets',
      where: 'name = ? COLLATE NOCASE',
      whereArgs: [name],
    );
  }
}
