import '../../data/repositories/music_repository.dart';
import '../../data/repositories/settings_repository.dart';
import 'media_channel.dart';

enum ScanPhase { idle, reading, saving, videos, complete, error }

class ScanProgress {
  const ScanProgress({
    required this.phase,
    this.processed = 0,
    this.total = 0,
    this.message,
  });

  final ScanPhase phase;
  final int processed;
  final int total;
  final String? message;

  bool get isBusy =>
      phase == ScanPhase.reading ||
      phase == ScanPhase.saving ||
      phase == ScanPhase.videos;

  double? get fraction =>
      total > 0 ? (processed / total).clamp(0.0, 1.0) : null;

  static const ScanProgress idle = ScanProgress(phase: ScanPhase.idle);
}

class ScanOutcome {
  const ScanOutcome({
    required this.songs,
    required this.videos,
    required this.excludedCount,
    required this.completedAt,
  });

  final SyncResult songs;
  final SyncResult? videos;
  final int excludedCount;
  final DateTime completedAt;
}

/// Coordinates a MediaStore scan and persists the result.
class MediaScannerService {
  MediaScannerService(this._channel, this._music, this._settings);

  final MediaChannel _channel;
  final MusicRepository _music;
  final SettingsRepository _settings;

  Future<ScanOutcome> scan({
    void Function(ScanProgress progress)? onProgress,
  }) async {
    onProgress?.call(
      const ScanProgress(
        phase: ScanPhase.reading,
        message: 'Reading device media…',
      ),
    );

    final rawSongs = await _channel.querySongs();
    final excludedFolders = await _music.excludedFolders();
    final audible = [
      for (final media in rawSongs)
        if (!isSystemSound((media['relativePath'] as String?) ?? '')) media,
    ];
    final filtered = [
      for (final media in audible)
        if (!isExcluded(
          (media['relativePath'] as String?) ?? '',
          excludedFolders,
        ))
          media,
    ];

    onProgress?.call(
      ScanProgress(
        phase: ScanPhase.saving,
        processed: 0,
        total: filtered.length,
        message: 'Saving library…',
      ),
    );

    final songsResult = await _music.syncSongs(
      filtered,
      onProgress: (processed, total) {
        onProgress?.call(
          ScanProgress(
            phase: ScanPhase.saving,
            processed: processed,
            total: total,
            message: 'Saving library…',
          ),
        );
      },
    );

    SyncResult? videosResult;
    try {
      onProgress?.call(
        const ScanProgress(
          phase: ScanPhase.videos,
          message: 'Looking for videos…',
        ),
      );
      final rawVideos = await _channel.queryVideos();
      videosResult = await _music.syncVideos(rawVideos);
    } catch (_) {
      // The video section is optional; a failure must not fail the music scan.
      videosResult = null;
    }

    final completedAt = DateTime.now();
    await _settings.setLastScanAt(completedAt);

    final excludedCount = audible.length - filtered.length;
    onProgress?.call(
      ScanProgress(
        phase: ScanPhase.complete,
        processed: filtered.length,
        total: filtered.length,
        message: excludedCount > 0
            ? 'Library updated · $excludedCount songs in excluded folders'
            : 'Library updated',
      ),
    );

    return ScanOutcome(
      songs: songsResult,
      videos: videosResult,
      excludedCount: excludedCount,
      completedAt: completedAt,
    );
  }

  static bool isExcluded(String relativePath, List<String> excludedFolders) {
    if (relativePath.isEmpty) return false;
    final path = relativePath.toLowerCase();
    for (final folder in excludedFolders) {
      final normalized = folder.trim().toLowerCase();
      if (normalized.isEmpty) continue;
      if (path == normalized || path.startsWith('$normalized/')) return true;
    }
    return false;
  }

  /// Ringtones, notification sounds and alarms are audio rows but not music.
  static bool isSystemSound(String relativePath) {
    if (relativePath.isEmpty) return false;
    final segments = relativePath.toLowerCase().split('/');
    return segments.any(
      (segment) =>
          segment == 'ringtones' ||
          segment == 'notifications' ||
          segment == 'alarms',
    );
  }
}
