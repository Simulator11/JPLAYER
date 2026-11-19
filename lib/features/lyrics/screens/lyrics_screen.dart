import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/lyrics_service.dart';
import '../../../data/models/song.dart';
import '../../../shared/widgets/common.dart';
import '../../player/providers/player_providers.dart';

class LyricsScreen extends ConsumerStatefulWidget {
  const LyricsScreen({super.key});

  @override
  ConsumerState<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends ConsumerState<LyricsScreen> {
  final ScrollController _scrollController = ScrollController();
  final LyricsService _service = const LyricsService();

  LyricsDocument? _lyrics;
  bool _loading = true;
  String? _manualPath;
  int _songId = -1;
  int _lastHighlight = -1;

  static const double _lineExtent = 64;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final song = ref.read(currentSongProvider).value;
    if (song == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _lyrics = null;
          _songId = -1;
        });
      }
      return;
    }
    setState(() {
      _loading = true;
      _songId = song.id;
      _lastHighlight = -1;
    });
    final settings = ref.read(settingsRepositoryProvider);
    final manualPath = await settings.lyricsPath(song.id);
    final lyrics = await _service.loadForSong(song, manualPath: manualPath);
    if (!mounted) return;
    setState(() {
      _lyrics = lyrics;
      _manualPath = manualPath;
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToCurrent(force: true);
    });
  }

  Future<void> _pickLyricsFile() async {
    final song = ref.read(currentSongProvider).value;
    if (song == null) return;
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose lyrics (.lrc or .txt)',
      type: FileType.custom,
      allowedExtensions: const ['lrc', 'txt'],
    );
    if (file == null) return;

    String content;
    try {
      content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That file could not be read.')),
      );
      return;
    }
    if (content.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That file could not be read.')),
      );
      return;
    }
    final parsed = _service.parse(content, sourcePath: file.path);
    if (parsed == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lyrics were found in that file.')),
      );
      return;
    }

    var path = file.path;
    if (path == null || path.isEmpty) {
      final support = await getApplicationSupportDirectory();
      final target = File(
        '${support.path}${Platform.pathSeparator}'
        'jplayer_lyrics_${song.id}.lrc',
      );
      await target.parent.create(recursive: true);
      await target.writeAsString(content);
      path = target.path;
    }
    await ref.read(settingsRepositoryProvider).setLyricsPath(song.id, path);
    if (!mounted) return;
    setState(() {
      _lyrics = parsed;
      _manualPath = path;
      _lastHighlight = -1;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Lyrics loaded')));
  }

  Future<void> _clearOverride() async {
    final song = ref.read(currentSongProvider).value;
    if (song == null) return;
    await ref.read(settingsRepositoryProvider).clearLyricsPath(song.id);
    await _load();
  }

  void _scrollToCurrent({bool force = false}) {
    final lyrics = _lyrics;
    if (lyrics == null || !lyrics.isSynced) return;
    final position = ref.read(positionProvider).value ?? Duration.zero;
    final index = lyrics.indexAt(position);
    if (!force && index == _lastHighlight) return;
    _lastHighlight = index;
    if (index < 0 || !_scrollController.hasClients) return;
    final target = (index * _lineExtent - 160).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final song = ref.watch(currentSongProvider).value;
    ref.listen<AsyncValue<Song?>>(currentSongProvider, (previous, next) {
      final nextSong = next.value;
      if (nextSong?.id != _songId) _load();
    });
    final highlightIndex = ref.watch(
      positionProvider.select(
        (value) => _lyrics?.indexAt(value.value ?? Duration.zero) ?? -1,
      ),
    );
    if (_lyrics != null &&
        _lyrics!.isSynced &&
        highlightIndex != _lastHighlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrent();
      });
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        title: const Text('Lyrics'),
        actions: [
          IconButton(
            tooltip: 'Choose lyrics file',
            onPressed: _pickLyricsFile,
            icon: const Icon(Icons.file_open_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'Lyrics options',
            onSelected: (value) {
              switch (value) {
                case 'pick':
                  _pickLyricsFile();
                  break;
                case 'automatic':
                  _clearOverride();
                  break;
                case 'reload':
                  _load();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pick',
                child: Text('Choose lyrics file'),
              ),
              if (_manualPath != null)
                const PopupMenuItem(
                  value: 'automatic',
                  child: Text('Use automatic lyrics'),
                ),
              const PopupMenuItem(value: 'reload', child: Text('Reload')),
            ],
          ),
        ],
      ),
      body: _buildBody(context, song, highlightIndex),
    );
  }

  Widget _buildBody(BuildContext context, Song? song, int highlightIndex) {
    final palette = context.palette;
    if (song == null) {
      return const EmptyState(
        icon: Icons.lyrics_outlined,
        title: 'Nothing playing',
        message: 'Start a song to see its lyrics.',
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final lyrics = _lyrics;
    if (lyrics == null) {
      return EmptyState(
        icon: Icons.lyrics_outlined,
        title: 'No lyrics found',
        message:
            'JPlayer looks for an .lrc or .txt file next to the song. You can '
            'also choose a lyrics file manually — everything stays offline.',
        actionLabel: 'Choose lyrics file',
        onAction: _pickLyricsFile,
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accentMuted,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  lyrics.isSynced ? 'SYNCED' : 'TEXT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.accent,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: lyrics.isSynced
              ? _buildSynced(context, lyrics, highlightIndex)
              : _buildPlain(context, lyrics),
        ),
      ],
    );
  }

  Widget _buildSynced(
    BuildContext context,
    LyricsDocument lyrics,
    int highlightIndex,
  ) {
    final palette = context.palette;
    final handler = ref.read(audioHandlerProvider);
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      itemExtent: _lineExtent,
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final active = index == highlightIndex;
        return InkWell(
          onTap: () => handler.seek(line.time),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style:
                (Theme.of(context).textTheme.titleMedium ?? const TextStyle())
                    .copyWith(
                      fontSize: active ? 19 : 16,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active
                          ? palette.accent
                          : palette.textSecondary.withValues(alpha: 0.78),
                    ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                line.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlain(BuildContext context, LyricsDocument lyrics) {
    final palette = context.palette;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 60),
      child: SelectableText(
        lyrics.plainText,
        style: Theme.of(context).textTheme.bodyLarge
            ?.copyWith(height: 1.9, color: palette.textPrimary),
      ),
    );
  }
}
