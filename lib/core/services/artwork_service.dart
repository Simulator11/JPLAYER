import 'media_channel.dart';

/// Extracts album artwork to the native cache and memoises lookups so scrolling
/// a 5,000 song library does not repeatedly hit MediaMetadataRetriever.
class ArtworkService {
  ArtworkService(this._channel);

  final MediaChannel _channel;
  final Map<String, Future<String?>> _cache = {};

  String _songKey(int? albumId, int songId) =>
      albumId != null && albumId > 0 ? 'album_$albumId' : 'song_$songId';

  Future<String?> forSong({required int songId, int? albumId, String? path}) {
    final key = _songKey(albumId, songId);
    return _cache.putIfAbsent(
      key,
      () => _resolve(
        () => _channel.getArtwork(albumId: albumId, songId: songId, path: path),
      ),
    );
  }

  Future<String?> forVideo({required int videoId, String? path}) {
    final key = 'video_$videoId';
    return _cache.putIfAbsent(
      key,
      () => _resolve(
        () => _channel.getVideoThumbnail(videoId: videoId, path: path),
      ),
    );
  }

  Future<String?> _resolve(Future<String?> Function() loader) async {
    try {
      return await loader();
    } catch (_) {
      // Artwork is optional: fall back to the branded placeholder.
      return null;
    }
  }

  /// Forgets cached failures, e.g. after a rescan discovers new files.
  void clear() {
    _cache.clear();
  }
}
