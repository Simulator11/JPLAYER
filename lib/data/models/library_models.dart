import 'song.dart';

/// Sort options exposed by the Music library.
enum SongSort { title, dateAdded, duration, artist, album }

extension SongSortInfo on SongSort {
  String get label {
    switch (this) {
      case SongSort.title:
        return 'Title (A–Z)';
      case SongSort.dateAdded:
        return 'Recently added';
      case SongSort.duration:
        return 'Duration';
      case SongSort.artist:
        return 'Artist';
      case SongSort.album:
        return 'Album';
    }
  }

  /// SQL ORDER BY fragment used by MusicRepository.getSongs.
  String get sqlOrder {
    switch (this) {
      case SongSort.title:
        return 'title COLLATE NOCASE ASC';
      case SongSort.dateAdded:
        return 'date_added DESC, title COLLATE NOCASE ASC';
      case SongSort.duration:
        return 'duration DESC, title COLLATE NOCASE ASC';
      case SongSort.artist:
        return 'artist COLLATE NOCASE ASC, album COLLATE NOCASE ASC, '
            'track ASC, title COLLATE NOCASE ASC';
      case SongSort.album:
        return 'album COLLATE NOCASE ASC, track ASC, title COLLATE NOCASE ASC';
    }
  }
}

class Album {
  const Album({
    required this.key,
    required this.id,
    required this.title,
    required this.artist,
    required this.songCount,
    required this.year,
    required this.sample,
  });

  final String key;
  final int? id;
  final String title;
  final String artist;
  final int songCount;
  final int year;

  /// A representative song, used for artwork and navigation.
  final Song sample;

  String get displayArtist =>
      artist.trim().isEmpty || artist.trim() == '<unknown>'
      ? 'Unknown artist'
      : artist.trim();
}

class Artist {
  const Artist({
    required this.name,
    required this.id,
    required this.songCount,
    required this.albumCount,
    required this.sample,
  });

  final String name;
  final int? id;
  final int songCount;
  final int albumCount;
  final Song sample;

  String get displayName => name.trim().isEmpty || name.trim() == '<unknown>'
      ? 'Unknown artist'
      : name;
}

class Genre {
  const Genre({required this.name, required this.songCount});

  final String name;
  final int songCount;
}

class MusicFolder {
  const MusicFolder({
    required this.path,
    required this.name,
    required this.songCount,
  });

  /// Relative directory path (e.g. `Music/Albums`). Empty for the root.
  final String path;
  final String name;
  final int songCount;

  String get displayName => path.isEmpty ? 'Device storage' : name;

  factory MusicFolder.fromPath(String path, int songCount) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    return MusicFolder(
      path: path,
      name: segments.isEmpty ? 'Device storage' : segments.last,
      songCount: songCount,
    );
  }
}

/// Smart playlists are computed from local listening history.
enum SmartPlaylist { favorites, recentlyPlayed, mostPlayed, recentlyAdded }

extension SmartPlaylistInfo on SmartPlaylist {
  String get label {
    switch (this) {
      case SmartPlaylist.favorites:
        return 'Favorites';
      case SmartPlaylist.recentlyPlayed:
        return 'Recently played';
      case SmartPlaylist.mostPlayed:
        return 'Most played';
      case SmartPlaylist.recentlyAdded:
        return 'Recently added';
    }
  }

  String get description {
    switch (this) {
      case SmartPlaylist.favorites:
        return 'The songs you loved';
      case SmartPlaylist.recentlyPlayed:
        return 'Your latest listening';
      case SmartPlaylist.mostPlayed:
        return 'On repeat lately';
      case SmartPlaylist.recentlyAdded:
        return 'Newest in your library';
    }
  }
}

/// An immutable snapshot of everything the UI needs for browsing.
///
/// Albums, artists, genres and folders are derived from one song list, which
/// keeps the database light and guarantees the views stay consistent.
class LibrarySnapshot {
  const LibrarySnapshot({
    required this.songs,
    required this.albums,
    required this.artists,
    required this.genres,
    required this.folders,
    required this.hasPermission,
    required this.lastScanAt,
  });

  final List<Song> songs;
  final List<Album> albums;
  final List<Artist> artists;
  final List<Genre> genres;
  final List<MusicFolder> folders;
  final bool hasPermission;
  final DateTime? lastScanAt;

  static const LibrarySnapshot empty = LibrarySnapshot(
    songs: [],
    albums: [],
    artists: [],
    genres: [],
    folders: [],
    hasPermission: true,
    lastScanAt: null,
  );

  bool get isEmpty => songs.isEmpty;

  factory LibrarySnapshot.fromSongs(
    List<Song> songs, {
    bool hasPermission = true,
    DateTime? lastScanAt,
  }) {
    final albumBuilders = <String, _AlbumBuilder>{};
    final artistBuilders = <String, _ArtistBuilder>{};
    final genreCounts = <String, int>{};
    final genreLabels = <String, String>{};
    final folderCounts = <String, int>{};

    for (final song in songs) {
      albumBuilders
          .putIfAbsent(song.albumKey, () => _AlbumBuilder(song))
          .add(song);

      final artistKey = song.displayArtist.toLowerCase();
      artistBuilders
          .putIfAbsent(
            artistKey,
            () => _ArtistBuilder(song.displayArtist, song),
          )
          .add(song);

      final genre = song.genre;
      if (genre != null) {
        final key = genre.toLowerCase();
        genreCounts[key] = (genreCounts[key] ?? 0) + 1;
        genreLabels.putIfAbsent(key, () => genre);
      }

      folderCounts[song.relativePath] =
          (folderCounts[song.relativePath] ?? 0) + 1;
    }

    final albums = albumBuilders.values.map((b) => b.build()).toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    final artists = artistBuilders.values.map((b) => b.build()).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final genres =
        genreCounts.entries
            .map(
              (entry) => Genre(
                name: genreLabels[entry.key] ?? entry.key,
                songCount: entry.value,
              ),
            )
            .toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
    final folders =
        folderCounts.entries
            .map((entry) => MusicFolder.fromPath(entry.key, entry.value))
            .toList()
          ..sort(
            (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
          );

    return LibrarySnapshot(
      songs: List.unmodifiable(songs),
      albums: List.unmodifiable(albums),
      artists: List.unmodifiable(artists),
      genres: List.unmodifiable(genres),
      folders: List.unmodifiable(folders),
      hasPermission: hasPermission,
      lastScanAt: lastScanAt,
    );
  }

  /// Builds album summaries from an arbitrary song list, e.g. recent plays.
  static List<Album> albumsFrom(List<Song> songs, {int maxItems = 12}) {
    final builders = <String, _AlbumBuilder>{};
    for (final song in songs) {
      builders.putIfAbsent(song.albumKey, () => _AlbumBuilder(song)).add(song);
    }
    final albums = builders.values.map((b) => b.build()).toList();
    return albums.take(maxItems).toList();
  }

  List<Song> songsOfAlbum(Album album) =>
      songs.where((song) => song.albumKey == album.key).toList();

  List<Song> songsOfArtist(Artist artist) => songs
      .where(
        (song) =>
            song.displayArtist.toLowerCase() ==
            artist.displayName.toLowerCase(),
      )
      .toList();

  List<Song> songsOfGenre(Genre genre) => songs
      .where(
        (song) => (song.genre ?? '').toLowerCase() == genre.name.toLowerCase(),
      )
      .toList();

  List<Song> songsOfFolder(MusicFolder folder) =>
      songs.where((song) => song.relativePath == folder.path).toList();
}

class _AlbumBuilder {
  _AlbumBuilder(Song song)
    : sample = song,
      id = song.albumId,
      title = song.displayAlbum,
      artist = song.displayArtist,
      year = song.year;

  final Song sample;
  final int? id;
  final String title;
  final String artist;
  int year;
  int count = 0;

  void add(Song song) {
    count++;
    if (song.year > year) year = song.year;
  }

  Album build() => Album(
    key: sample.albumKey,
    id: id,
    title: title,
    artist: artist,
    songCount: count,
    year: year,
    sample: sample,
  );
}

class _ArtistBuilder {
  _ArtistBuilder(this.name, this.sample) : id = sample.artistId;

  final String name;
  final Song sample;
  final int? id;
  int count = 0;
  final Set<String> albumKeys = {};

  void add(Song song) {
    count++;
    albumKeys.add(song.albumKey);
  }

  Artist build() => Artist(
    name: name,
    id: id,
    songCount: count,
    albumCount: albumKeys.length,
    sample: sample,
  );
}
