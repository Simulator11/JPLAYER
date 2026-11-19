/// A user-created playlist.
class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String name;
  final int songCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Playlist.fromMap(Map<String, Object?> map) {
    final created = _asInt(map['created_at']);
    final updated = _asInt(map['updated_at']);
    return Playlist(
      id: _asInt(map['id']),
      name: (map['name'] as String?) ?? 'Playlist',
      songCount: _asInt(map['song_count'] ?? map['songCount']),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        created == 0 ? DateTime.now().millisecondsSinceEpoch : created,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        updated == 0 ? DateTime.now().millisecondsSinceEpoch : updated,
      ),
    );
  }

  Playlist copyWith({int? id, String? name, int? songCount}) {
    return Playlist(
      id: id ?? this.id,
      name: name ?? this.name,
      songCount: songCount ?? this.songCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) => other is Playlist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// A locally stored video. Videos are intentionally a secondary feature.
class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.path,
    required this.uri,
    required this.durationMs,
    required this.sizeBytes,
    required this.dateAdded,
    required this.bucket,
    required this.width,
    required this.height,
    required this.lastPositionMs,
  });

  final int id;
  final String title;
  final String path;
  final String uri;
  final int durationMs;
  final int sizeBytes;
  final int dateAdded;
  final String bucket;
  final int width;
  final int height;
  final int lastPositionMs;

  factory VideoItem.fromMap(Map<String, Object?> map) {
    return VideoItem(
      id: _asInt(map['media_id'] ?? map['id']),
      title: (map['title'] as String?) ?? 'Video',
      path: (map['path'] as String?) ?? '',
      uri: (map['uri'] as String?) ?? '',
      durationMs: _asInt(map['duration'] ?? map['durationMs']),
      sizeBytes: _asInt(map['size'] ?? map['sizeBytes']),
      dateAdded: _asInt(map['date_added'] ?? map['dateAdded']),
      bucket: (map['bucket'] as String?) ?? '',
      width: _asInt(map['width']),
      height: _asInt(map['height']),
      lastPositionMs: _asInt(map['last_position'] ?? map['lastPositionMs']),
    );
  }

  Map<String, Object?> toDatabaseMap() => {
    'media_id': id,
    'title': title,
    'path': path,
    'uri': uri,
    'duration': durationMs,
    'size': sizeBytes,
    'date_added': dateAdded,
    'bucket': bucket,
    'width': width,
    'height': height,
  };

  String get playbackSource => path.isNotEmpty ? path : uri;

  String get displayBucket => bucket.trim().isEmpty ? 'Videos' : bucket;

  Duration get duration => Duration(milliseconds: durationMs);

  VideoItem copyWith({int? lastPositionMs}) => VideoItem(
    id: id,
    title: title,
    path: path,
    uri: uri,
    durationMs: durationMs,
    sizeBytes: sizeBytes,
    dateAdded: dateAdded,
    bucket: bucket,
    width: width,
    height: height,
    lastPositionMs: lastPositionMs ?? this.lastPositionMs,
  );
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
