import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/providers/core_providers.dart';
import '../../../core/services/media_channel.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/playlist.dart';
import '../../../data/repositories/music_repository.dart';
import '../services/subtitles.dart';

/// Full-screen local video player with gesture controls, subtitles, aspect
/// modes and remembered playback positions.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({
    super.key,
    required this.videos,
    required this.initialIndex,
  });

  final List<VideoItem> videos;
  final int initialIndex;

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  late final MediaChannel _mediaChannel;
  late final MusicRepository _musicRepository;
  late List<VideoItem> _videos;
  late int _index;

  bool _initialized = false;
  String? _error;
  bool _completed = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  double _speed = 1.0;
  int _aspect = 0;
  bool _fullscreen = false;

  double _volume = 1.0;
  double _brightness = 0.5;
  double? _overlayVolume;
  double? _overlayBrightness;
  double? _verticalStartY;
  double _verticalStartValue = 0;
  bool _adjustingVolume = false;

  Duration? _seekPreview;
  double? _dragStartX;
  Duration? _dragStartPosition;

  Timer? _saveTimer;
  Timer? _subtitleTimer;
  SubtitleTrack? _subtitles;
  String _subtitleText = '';
  bool _subtitlesVisible = true;

  @override
  void initState() {
    super.initState();
    _mediaChannel = ref.read(mediaChannelProvider);
    _musicRepository = ref.read(musicRepositoryProvider);
    _videos = List<VideoItem>.of(widget.videos);
    _index = widget.initialIndex.clamp(0, _videos.length - 1).toInt();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initController();
    _saveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _savePosition(),
    );
    _subtitleTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) => _updateSubtitle(),
    );
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _saveTimer?.cancel();
    _subtitleTimer?.cancel();
    _savePosition();
    _controller?.removeListener(_onValueChanged);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const []);
    _mediaChannel.setScreenBrightness(null);
    super.dispose();
  }

  VideoItem get _video => _videos[_index];

  Future<void> _initController() async {
    setState(() {
      _initialized = false;
      _error = null;
      _completed = false;
      _subtitleText = '';
      _seekPreview = null;
    });
    final video = _video;
    final controller =
        video.path.isNotEmpty && !video.path.startsWith('content://')
        ? VideoPlayerController.file(File(video.path))
        : VideoPlayerController.contentUri(Uri.parse(video.uri));
    _controller = controller;
    controller.addListener(_onValueChanged);
    try {
      await controller.initialize();
      await controller.setVolume(_volume);
      await controller.setPlaybackSpeed(_speed);
      final resume = video.lastPositionMs;
      if (resume > 0 &&
          resume < controller.value.duration.inMilliseconds - 1500) {
        await controller.seekTo(Duration(milliseconds: resume));
      }
      await controller.play();
      if (!mounted) return;
      setState(() => _initialized = true);
      _scheduleHide();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'This video could not be played. The format may not be '
            'supported by this device.';
      });
    }
  }

  void _onValueChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    final value = controller.value;
    if (value.hasError && _error == null) {
      setState(() => _error = value.errorDescription ?? 'Playback error.');
      return;
    }
    if (value.isCompleted && !_completed) {
      _savePosition(forceZero: true);
      setState(() {
        _completed = true;
        _controlsVisible = true;
      });
    }
  }

  Future<void> _savePosition({bool forceZero = false}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await _musicRepository.updateVideoPosition(
        _video.id,
        forceZero ? 0 : controller.value.position.inMilliseconds,
      );
    } catch (_) {
      // Remembering the position is best-effort.
    }
  }

  Future<void> _togglePlayPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isCompleted) {
      await controller.seekTo(Duration.zero);
      await controller.play();
      if (!mounted) return;
      setState(() => _completed = false);
      _scheduleHide();
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      await _savePosition();
      if (!mounted) return;
      _hideTimer?.cancel();
      setState(() => _controlsVisible = true);
    } else {
      await controller.play();
      if (!mounted) return;
      _scheduleHide();
    }
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    _hideTimer?.cancel();
    setState(() => _controlsVisible = true);
    _scheduleHide();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _switchVideo(int direction) async {
    if (_videos.length < 2) return;
    final next = (_index + direction).clamp(0, _videos.length - 1).toInt();
    if (next == _index) return;
    await _savePosition();
    final old = _controller;
    _controller = null;
    old?.removeListener(_onValueChanged);
    await old?.dispose();
    if (!mounted) return;
    setState(() {
      _index = next;
      _subtitles = null;
      _subtitleText = '';
    });
    await _initController();
  }

  Future<void> _toggleFullscreen() async {
    final next = !_fullscreen;
    setState(() => _fullscreen = next);
    if (next) {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]);
    }
    _showControls();
  }

  void _cycleAspect() {
    setState(() => _aspect = (_aspect + 1) % 3);
    _showControls();
  }

  Future<void> _finishSeek(Duration position) async {
    final controller = _controller;
    if (controller == null) return;
    await controller.seekTo(position);
    if (!mounted) return;
    setState(() => _seekPreview = null);
    _showControls();
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    final controller = _controller;
    if (controller == null) return;
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = controller.value.position;
    _hideTimer?.cancel();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final controller = _controller;
    final start = _dragStartPosition;
    if (controller == null || start == null) return;
    final width = MediaQuery.sizeOf(context).width;
    final dx =
        details.localPosition.dx - (_dragStartX ?? details.localPosition.dx);
    final total = controller.value.duration.inMilliseconds;
    if (total <= 0 || width <= 0) return;
    final target = (start.inMilliseconds + (dx / width * total).round()).clamp(
      0,
      total,
    );
    setState(() => _seekPreview = Duration(milliseconds: target));
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final preview = _seekPreview;
    if (preview != null) {
      _finishSeek(preview);
    } else {
      setState(() => _seekPreview = null);
    }
    _dragStartX = null;
    _dragStartPosition = null;
  }

  void _onVerticalDragStart(DragStartDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    _verticalStartY = details.localPosition.dy;
    if (details.localPosition.dx < width / 2) {
      _adjustingVolume = false;
      _verticalStartValue = _brightness;
    } else {
      _adjustingVolume = true;
      _verticalStartValue = _volume;
    }
    _hideTimer?.cancel();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    final delta =
        ((_verticalStartY ?? details.localPosition.dy) -
            details.localPosition.dy) /
        height;
    final value = (_verticalStartValue + delta).clamp(0.05, 1.0).toDouble();
    if (_adjustingVolume) {
      _volume = value;
      _controller?.setVolume(value);
      setState(() => _overlayVolume = value);
    } else {
      _brightness = value;
      _mediaChannel.setScreenBrightness(value);
      setState(() => _overlayBrightness = value);
    }
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    setState(() {
      _overlayVolume = null;
      _overlayBrightness = null;
    });
    _verticalStartY = null;
    _showControls();
  }

  void _updateSubtitle() {
    final track = _subtitles;
    final controller = _controller;
    if (track == null || controller == null || !mounted) return;
    final text = track.textAt(controller.value.position);
    if (text != _subtitleText) {
      setState(() => _subtitleText = text);
    }
  }

  Future<void> _loadSubtitleFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose subtitles (.srt or .vtt)',
      type: FileType.custom,
      allowedExtensions: const ['srt', 'vtt', 'txt'],
    );
    if (file == null) return;
    String content;
    try {
      content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That subtitle file could not be read.')),
      );
      return;
    }
    final track = SubtitleParser.parse(content, sourcePath: file.path);
    if (track == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subtitle cues were found.')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _subtitles = track;
      _subtitlesVisible = true;
      _subtitleText = track.textAt(
        _controller?.value.position ?? Duration.zero,
      );
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Subtitles loaded')));
  }

  Future<void> _showSubtitleMenu() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.subtitles_off_outlined),
              title: const Text('Turn subtitles off'),
              onTap: () => Navigator.of(context).pop('off'),
            ),
            ListTile(
              leading: const Icon(Icons.file_open_outlined),
              title: const Text('Load subtitle file'),
              subtitle: const Text('SRT or WebVTT stored on this device'),
              onTap: () => Navigator.of(context).pop('load'),
            ),
            if (_subtitles != null)
              ListTile(
                leading: Icon(
                  _subtitlesVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                title: Text(
                  _subtitlesVisible ? 'Hide subtitles' : 'Show subtitles',
                ),
                onTap: () => Navigator.of(context).pop('toggle'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'off':
        setState(() {
          _subtitles = null;
          _subtitleText = '';
        });
        break;
      case 'load':
        await _loadSubtitleFile();
        break;
      case 'toggle':
        setState(() => _subtitlesVisible = !_subtitlesVisible);
        break;
    }
  }

  Future<void> _showSpeedMenu() async {
    final selected = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final speed in const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              ListTile(
                leading: Icon(
                  speed == _speed
                      ? Icons.check_circle_rounded
                      : Icons.speed_rounded,
                  color: speed == _speed
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                title: Text('${speed}x'),
                onTap: () => Navigator.of(context).pop(speed),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _controller?.setPlaybackSpeed(selected);
    if (!mounted) return;
    setState(() => _speed = selected);
    _showControls();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error != null)
            _buildError(context)
          else if (controller == null || !_initialized)
            _buildLoading(context)
          else ...[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggleControls,
              onHorizontalDragStart: _onHorizontalDragStart,
              onHorizontalDragUpdate: _onHorizontalDragUpdate,
              onHorizontalDragEnd: _onHorizontalDragEnd,
              onVerticalDragStart: _onVerticalDragStart,
              onVerticalDragUpdate: _onVerticalDragUpdate,
              onVerticalDragEnd: _onVerticalDragEnd,
              child: _videoView(controller),
            ),
            if (_controlsVisible) _buildControls(context, controller),
            if (_seekPreview != null) _seekIndicator(context),
            if (_overlayBrightness != null)
              _gestureIndicator(
                context,
                Icons.brightness_6_rounded,
                _overlayBrightness!,
              ),
            if (_overlayVolume != null)
              _gestureIndicator(
                context,
                _overlayVolume == 0
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                _overlayVolume!,
              ),
            if (_subtitleText.isNotEmpty && _subtitlesVisible)
              _subtitleOverlay(context),
          ],
        ],
      ),
    );
  }

  Widget _videoView(VideoPlayerController controller) {
    final value = controller.value;
    if (value.size.width <= 0 || value.size.height <= 0) {
      return Center(
        child: AspectRatio(
          aspectRatio: value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }
    switch (_aspect) {
      case 1:
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: value.size.width,
              height: value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      case 2:
        return ClipRect(
          child: FittedBox(
            fit: BoxFit.fill,
            child: SizedBox(
              width: value.size.width,
              height: value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        );
      default:
        return Center(
          child: AspectRatio(
            aspectRatio: value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        );
    }
  }

  Widget _buildControls(
    BuildContext context,
    VideoPlayerController controller,
  ) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xCC000000), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Container(
              height: 230,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xE6000000), Colors.transparent],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(
            children: [
              _topControls(context),
              const Spacer(),
              _centerControls(context, controller),
              const Spacer(),
              _bottomControls(context, controller),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topControls(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Back',
          color: Colors.white,
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _video.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _video.displayBucket,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Subtitles',
          color: _subtitles != null
              ? Theme.of(context).colorScheme.primary
              : Colors.white,
          onPressed: _showSubtitleMenu,
          icon: const Icon(Icons.subtitles_outlined),
        ),
        IconButton(
          tooltip: _aspectLabel,
          color: Colors.white,
          onPressed: _cycleAspect,
          icon: const Icon(Icons.fit_screen_rounded),
        ),
        IconButton(
          tooltip: _fullscreen ? 'Exit full screen' : 'Full screen',
          color: Colors.white,
          onPressed: _toggleFullscreen,
          icon: Icon(
            _fullscreen
                ? Icons.fullscreen_exit_rounded
                : Icons.fullscreen_rounded,
          ),
        ),
      ],
    );
  }

  Widget _centerControls(
    BuildContext context,
    VideoPlayerController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_videos.length > 1)
          IconButton(
            tooltip: 'Previous video',
            color: Colors.white,
            iconSize: 38,
            onPressed: _index > 0 ? () => _switchVideo(-1) : null,
            icon: const Icon(Icons.skip_previous_rounded),
          ),
        const SizedBox(width: 18),
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final showReplay = value.isCompleted || _completed;
              return IconButton(
                tooltip: value.isPlaying ? 'Pause' : 'Play',
                color: Colors.white,
                iconSize: 44,
                onPressed: _togglePlayPause,
                icon: Icon(
                  showReplay
                      ? Icons.replay_rounded
                      : value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 18),
        if (_videos.length > 1)
          IconButton(
            tooltip: 'Next video',
            color: Colors.white,
            iconSize: 38,
            onPressed: _index < _videos.length - 1
                ? () => _switchVideo(1)
                : null,
            icon: const Icon(Icons.skip_next_rounded),
          ),
      ],
    );
  }

  String get _aspectLabel => switch (_aspect) {
    1 => 'Crop to fill',
    2 => 'Stretch to fill',
    _ => 'Fit screen',
  };

  Widget _bottomControls(
    BuildContext context,
    VideoPlayerController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final duration = value.duration;
              final max = duration.inMilliseconds.toDouble();
              final preview = _seekPreview;
              final current = (preview ?? value.position).inMilliseconds
                  .toDouble()
                  .clamp(0.0, max > 0 ? max : 1.0)
                  .toDouble();
              return Column(
                children: [
                  Slider(
                    value: current,
                    max: max > 0 ? max : 1,
                    onChanged: (next) => setState(
                      () => _seekPreview = Duration(milliseconds: next.round()),
                    ),
                    onChangeEnd: (next) =>
                        _finishSeek(Duration(milliseconds: next.round())),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Text(
                          Formatters.duration(preview ?? value.position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          Formatters.duration(duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: _showSpeedMenu,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.speed_rounded, size: 18),
                label: Text(
                  '${_speed == _speed.roundToDouble() ? _speed.toInt() : _speed}x',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Subtitles',
                color: Colors.white,
                onPressed: _showSubtitleMenu,
                icon: const Icon(Icons.subtitles_outlined),
              ),
              IconButton(
                tooltip: _volume > 0 ? 'Mute' : 'Unmute',
                color: Colors.white,
                onPressed: () {
                  final next = _volume > 0 ? 0.0 : 1.0;
                  setState(() => _volume = next);
                  controller.setVolume(next);
                },
                icon: Icon(
                  _volume > 0
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                ),
              ),
              IconButton(
                tooltip: 'Aspect ratio: $_aspectLabel',
                color: Colors.white,
                onPressed: _cycleAspect,
                icon: const Icon(Icons.crop_rounded),
              ),
              IconButton(
                tooltip: _fullscreen ? 'Exit full screen' : 'Full screen',
                color: Colors.white,
                onPressed: _toggleFullscreen,
                icon: Icon(
                  _fullscreen
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _seekIndicator(BuildContext context) {
    final preview = _seekPreview;
    if (preview == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fast_forward_rounded,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              Formatters.duration(preview),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              'Release to seek',
              style: TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gestureIndicator(BuildContext context, IconData icon, double value) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 86),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${(value * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subtitleOverlay(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, _controlsVisible ? 132 : 30),
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _subtitleText,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              tooltip: 'Back',
              color: Colors.white,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back',
              color: Colors.white,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image_outlined,
                      size: 56,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cannot play this video',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error ?? 'The file may be missing or unsupported.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
