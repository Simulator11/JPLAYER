/// A song stored in the local MediaStore and cached in JPlayer's database.
///
/// The database stores references and metadata only; audio is always streamed
/// from the user's own file.
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.artistId,
    required this.album,
    required this.albumId,
    required this.genre,
    required this.durationMs,
    required this.sizeBytes,
    required this.dateAdded,
    required this.dateModified,
    required this.path,
    required this.uri,
    required this.relativePath,
    required this.fileName,
    required this.track,
    required this.year,
  });

  /// MediaStore `_ID`.
  final int id;
  final String title;
  final String artist;
  final int? artistId;
  final String album;
  final int? albumId;
  final String? genre;
  final int durationMs;
  final int sizeBytes;

  /// Seconds since epoch, as reported by MediaStore.
  final int dateAdded;
  final int dateModified;

  /// Absolute file path, or an empty string when only [uri] is available.
  final String path;

  /// MediaStore `content://` URI for the audio row.
  final String uri;
  final String relativePath;
  final String fileName;
  final int track;
  final int year;

  factory Song.fromMap(Map<String, Object?> map) {
    return Song(
      id: _asInt(map['media_id'] ?? map['id']),
      title: (map['title'] as String?)?.trim().isNotEmpty == true
          ? (map['title'] as String).trim()
          : 'Unknown track',
      artist: (map['artist'] as String?) ?? '',
      artistId: _asNullableInt(map['artist_id'] ?? map['artistId']),
      album: (map['album'] as String?) ?? '',
      albumId: _asNullableInt(map['album_id'] ?? map['albumId']),
      genre: (map['genre'] as String?)?.trim().isNotEmpty == true
          ? (map['genre'] as String).trim()
          : null,
      durationMs: _asInt(map['duration'] ?? map['durationMs']),
      sizeBytes: _asInt(map['size'] ?? map['sizeBytes']),
      dateAdded: _asInt(map['date_added'] ?? map['dateAdded']),
      dateModified: _asInt(map['date_modified'] ?? map['dateModified']),
      path: (map['path'] as String?) ?? '',
      uri: (map['uri'] as String?) ?? '',
      relativePath:
          ((map['relative_path'] ?? map['relativePath']) as String?) ?? '',
      fileName: ((map['file_name'] ?? map['fileName']) as String?) ?? '',
      track: _asInt(map['track']),
      year: _asInt(map['year']),
    );
  }

  Map<String, Object?> toMap() => {
    'media_id': id,
    'title': title,
    'artist': artist,
    'artist_id': artistId,
    'album': album,
    'album_id': albumId,
    'genre': genre,
    'duration': durationMs,
    'size': sizeBytes,
    'date_added': dateAdded,
    'date_modified': dateModified,
    'path': path,
    'uri': uri,
    'relative_path': relativePath,
    'file_name': fileName,
    'track': track,
    'year': year,
  };

  String get displayArtist =>
      artist.trim().isEmpty || artist.trim() == '<unknown>'
      ? 'Unknown artist'
      : artist.trim();

  String get displayAlbum => album.trim().isEmpty || album.trim() == '<unknown>'
      ? 'Unknown album'
      : album.trim();

  String get displayGenre => genre ?? 'Unknown genre';

  bool get hasArtist =>
      artist.trim().isNotEmpty && artist.trim() != '<unknown>';

  bool get hasAlbum => album.trim().isNotEmpty && album.trim() != '<unknown>';

  String get albumKey => albumId != null && albumId! > 0
      ? 'id:$albumId'
      : 'name:${album.toLowerCase()}';

  String get playbackSource => path.isNotEmpty ? path : uri;

  String get folderPath => relativePath;

  String get folderName {
    if (relativePath.isEmpty) return 'Device storage';
    final segments = relativePath.split('/');
    return segments.isEmpty ? 'Device storage' : segments.last;
  }

  String get extension {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  DateTime get dateAddedTime =>
      DateTime.fromMillisecondsSinceEpoch(dateAdded * 1000);

  Duration get duration => Duration(milliseconds: durationMs);

  bool get isFavoriteCandidate => durationMs > 0;

  Song copyWith({
    int? id,
    String? title,
    String? artist,
    int? artistId,
    String? album,
    int? albumId,
    String? genre,
    int? durationMs,
    int? sizeBytes,
    int? dateAdded,
    int? dateModified,
    String? path,
    String? uri,
    String? relativePath,
    String? fileName,
    int? track,
    int? year,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      artistId: artistId ?? this.artistId,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      genre: genre ?? this.genre,
      durationMs: durationMs ?? this.durationMs,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      dateAdded: dateAdded ?? this.dateAdded,
      dateModified: dateModified ?? this.dateModified,
      path: path ?? this.path,
      uri: uri ?? this.uri,
      relativePath: relativePath ?? this.relativePath,
      fileName: fileName ?? this.fileName,
      track: track ?? this.track,
      year: year ?? this.year,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Song && other.id == id && other.title == title;

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() => 'Song($id, $title)';
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

int? _asNullableInt(Object? value) {
  if (value == null) return null;
  final parsed = _asInt(value);
  return parsed == 0 ? null : parsed;
}
