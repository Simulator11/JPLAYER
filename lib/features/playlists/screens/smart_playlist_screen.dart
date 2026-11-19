import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/library_models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/song_collection_screen.dart';
import '../../music/providers/library_providers.dart';

/// Read-only view over one of JPlayer's automatic playlists.
class SmartPlaylistScreen extends ConsumerWidget {
  const SmartPlaylistScreen({super.key, required this.type});

  final SmartPlaylist type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final songsAsync = ref.watch(smartSongsProvider(type));
    return songsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(type.label)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(type.label)),
        body: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Could not load this playlist',
          message: '$error',
        ),
      ),
      data: (songs) => SongCollectionScreen(
        title: type.label,
        subtitle: type.description,
        songs: songs,
        artworkSong: songs.isEmpty ? null : songs.first,
        emptyMessage: _emptyMessage,
      ),
    );
  }

  String get _emptyMessage {
    switch (type) {
      case SmartPlaylist.favorites:
        return 'Tap the heart on any song to keep it here.';
      case SmartPlaylist.recentlyPlayed:
        return 'Songs you play will appear here.';
      case SmartPlaylist.mostPlayed:
        return 'Listen to songs and your favorites will rise to the top.';
      case SmartPlaylist.recentlyAdded:
        return 'Scan your device to discover recently added music.';
    }
  }
}
