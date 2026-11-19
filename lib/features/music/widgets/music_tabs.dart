import 'package:material_ui/material_ui.dart';

import '../../../app/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/song_tile.dart';

class AlbumsTab extends StatelessWidget {
  const AlbumsTab({super.key, required this.albums, required this.onTap});

  final List<Album> albums;
  final ValueChanged<Album> onTap;

  @override
  Widget build(BuildContext context) {
    if (albums.isEmpty) {
      return const EmptyState(
        icon: Icons.album_outlined,
        title: 'No albums yet',
        message: 'Albums are grouped from the music on your device.',
        compact: true,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1000
            ? 5
            : width >= 700
            ? 4
            : width >= 480
            ? 3
            : 2;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.72,
          ),
          itemCount: albums.length,
          itemBuilder: (context, index) {
            final album = albums[index];
            return AlbumCard(album: album, onTap: () => onTap(album));
          },
        );
      },
    );
  }
}

class ArtistsTab extends StatelessWidget {
  const ArtistsTab({super.key, required this.artists, required this.onTap});

  final List<Artist> artists;
  final ValueChanged<Artist> onTap;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const EmptyState(
        icon: Icons.person_outline_rounded,
        title: 'No artists yet',
        message: 'Artist names are read from your music files.',
        compact: true,
      );
    }
    final palette = context.palette;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: CircleAvatar(
            radius: 25,
            backgroundColor: palette.accentMuted,
            child: Text(
              Formatters.initials(artist.displayName),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: palette.accent),
            ),
          ),
          title: Text(
            artist.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${Formatters.count(artist.albumCount, 'album')} · '
            '${Formatters.songCount(artist.songCount)}',
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: palette.textSecondary,
          ),
          onTap: () => onTap(artist),
        );
      },
    );
  }
}

class GenresTab extends StatelessWidget {
  const GenresTab({super.key, required this.genres, required this.onTap});

  final List<Genre> genres;
  final ValueChanged<Genre> onTap;

  @override
  Widget build(BuildContext context) {
    if (genres.isEmpty) {
      return const EmptyState(
        icon: Icons.category_outlined,
        title: 'No genres found',
        message: 'Genres depend on the tags stored in your music files.',
        compact: true,
      );
    }
    final palette = context.palette;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 24),
      itemCount: genres.length,
      itemBuilder: (context, index) {
        final genre = genres[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: palette.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.category_outlined,
              color: palette.accent,
              size: 24,
            ),
          ),
          title: Text(genre.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(Formatters.songCount(genre.songCount)),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: palette.textSecondary,
          ),
          onTap: () => onTap(genre),
        );
      },
    );
  }
}

class FoldersTab extends StatelessWidget {
  const FoldersTab({
    super.key,
    required this.folders,
    required this.excludedFolders,
    required this.onTap,
    required this.onExclude,
    this.onManageExclusions,
  });

  final List<MusicFolder> folders;
  final List<String> excludedFolders;
  final ValueChanged<MusicFolder> onTap;
  final ValueChanged<MusicFolder> onExclude;
  final VoidCallback? onManageExclusions;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (folders.isEmpty && excludedFolders.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_outlined,
        title: 'No folders found',
        message: 'JPlayer browses the media folders Android indexes.',
        compact: true,
      );
    }

    Future<void> confirmExclude(MusicFolder folder) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exclude this folder?'),
          content: Text(
            'Songs in "${folder.displayName}" will be removed from JPlayer. '
            'You can include the folder again later and rescan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Exclude'),
            ),
          ],
        ),
      );
      if (confirmed == true) onExclude(folder);
    }

    return ListView(
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      children: [
        if (excludedFolders.isNotEmpty)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: palette.accentMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.folder_off_outlined, color: palette.accent),
            ),
            title: const Text('Excluded folders'),
            subtitle: Text(Formatters.count(excludedFolders.length, 'folder')),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: palette.textSecondary,
            ),
            onTap: onManageExclusions,
          ),
        for (final folder in folders)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.folder_outlined, color: palette.accent),
            ),
            title: Text(
              folder.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              folder.path.isEmpty ? 'Device storage' : folder.path,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Folder options',
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20,
                color: palette.textSecondary,
              ),
              onSelected: (value) {
                if (value == 'open') {
                  onTap(folder);
                } else if (value == 'exclude') {
                  confirmExclude(folder);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'open', child: Text('Open folder')),
                PopupMenuItem(value: 'exclude', child: Text('Exclude folder')),
              ],
            ),
            onTap: () => onTap(folder),
          ),
      ],
    );
  }
}
