import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../../app/theme/colors.dart';
import '../../../core/audio/equalizer_presets.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/song.dart';
import '../../../data/repositories/music_repository.dart';
import '../../../data/repositories/playlist_repository.dart';
import '../../../data/repositories/settings_repository.dart';

class SongStart {
  const SongStart({required this.song, required this.startedAt});

  final Song song;
  final DateTime startedAt;
}

/// Background audio engine.
///
/// just_audio renders the queue (gapless where the device supports it) and
/// audio_service exposes it to Android's media session, notification,
/// lock screen, Bluetooth controls and headset buttons.
class JPlayerAudioHandler extends BaseAudioHandler {
  JPlayerAudioHandler._(this._music, this._playlists, this._settings) {
    _effectsSupported = !kIsWeb && Platform.isAndroid;
    final equalizer = _effectsSupported ? AndroidEqualizer() : null;
    final loudness = _effectsSupported ? AndroidLoudnessEnhancer() : null;
    _equalizer = equalizer;
    _loudness = loudness;
    _player = AudioPlayer(
      maxSkipsOnError: 5,
      audioPipeline: equalizer != null && loudness != null
          ? AudioPipeline(androidAudioEffects: [equalizer, loudness])
          : null,
    );
  }

  final MusicRepository _music;
  final PlaylistRepository _playlists;
  final SettingsRepository _settings;

  late final AudioPlayer _player;
  late final AndroidEqualizer? _equalizer;
  late final AndroidLoudnessEnhancer? _loudness;
  late final bool _effectsSupported;

  final _currentSongController = StreamController<Song?>.broadcast();
  final _queueController = StreamController<List<Song>>.broadcast();
  final _songStartController = StreamController<SongStart>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  List<Song> _songs = [];
  int _index = 0;
  Song? _currentSong;
  int? _lastRecordedSongId;
  Duration _resumePosition = Duration.zero;
  Timer? _positionTimer;
  bool _shuffleEnabled = false;
  AudioServiceRepeatMode _repeatMode = AudioServiceRepeatMode.none;

  Stream<Song?> get currentSongStream async* {
    yield _currentSong;
    yield* _currentSongController.stream;
  }

  Stream<List<Song>> get queueSongsStream async* {
    yield List<Song>.unmodifiable(_songs);
    yield* _queueController.stream;
  }

  Stream<SongStart> get songStartedStream => _songStartController.stream;

  Stream<String> get errorStream => _errorController.stream;

  Stream<Duration> get positionStream => _player.positionStream;

  Stream<Duration?> get durationStream => _player.durationStream;

  List<Song> get queueSongs => List.unmodifiable(_songs);

  Song? get currentSong => _currentSong;

  bool get effectsSupported => _effectsSupported;

  static Future<JPlayerAudioHandler> init({
    required MusicRepository music,
    required PlaylistRepository playlists,
    required SettingsRepository settings,
  }) async {
    final handler = JPlayerAudioHandler._(music, playlists, settings);
    await AudioService.init(
      builder: () => handler,
      config: AudioServiceConfig(
        androidNotificationChannelId: AppConstants.notificationChannel,
        androidNotificationChannelName: AppConstants.notificationChannelName,
        androidNotificationChannelDescription:
            AppConstants.notificationChannelDescription,
        androidNotificationIcon: 'drawable/ic_stat_music',
        androidShowNotificationBadge: false,
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: true,
        notificationColor: AppColors.primaryAccent,
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
      ),
    );
    await handler._initialize();
    return handler;
  }

  Future<void> _initialize() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.becomingNoisyEventStream.listen((_) {
      unawaited(pause());
    });

    _player.playbackEventStream.listen(
      (_) => _broadcastState(),
      onError: (Object _) {},
    );
    _player.playerStateStream.listen((_) => _broadcastState());
    _player.currentIndexStream.listen(_handleIndexChange);
    _player.errorStream.listen((error) {
      _errorController.add(error.message ?? 'This track could not be played.');
    });

    await _restoreQueue();
    final settings = await _settings.loadSettings();
    await _applyRepeatSetting(settings.repeatMode);
    _ensurePositionTimer();
    _broadcastState();
  }

  void _ensurePositionTimer() {
    _positionTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => _persistPosition(),
    );
  }

  // ---------------------------------------------------------------------
  // Playback API
  // ---------------------------------------------------------------------

  @override
  Future<void> play() async {
    if (_songs.isEmpty) return;
    _ensurePositionTimer();
    if (_player.audioSources.isEmpty) {
      final settings = await _settings.loadSettings();
      final position = settings.resumeLastSession
          ? _resumePosition
          : Duration.zero;
      await _loadQueue(
        index: _index,
        initialPosition: position,
        autoplay: true,
      );
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero, index: _player.currentIndex);
    }
    _ensurePositionTimer();
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    await _persistPosition();
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  @override
  Future<void> stop() async {
    await _persistPosition();
    _positionTimer?.cancel();
    _positionTimer = null;
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _broadcastState();
  }

  @override
  Future<void> skipToNext() async {
    if (_songs.isEmpty) return;
    await _player.seekToNext();
    _broadcastState();
  }

  @override
  Future<void> skipToPrevious() async {
    if (_songs.isEmpty) return;
    if (_player.position > const Duration(seconds: 3) || !_player.hasPrevious) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
    _broadcastState();
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _songs.length) return;
    if (_player.audioSources.isEmpty) {
      _index = index;
      _currentSong = _songs[index];
      _currentSongController.add(_currentSong);
      mediaItem.add(_mediaItemFor(_songs[index]));
      await _loadQueue(
        index: index,
        initialPosition: _resumePosition,
        autoplay: true,
      );
      return;
    }
    await _player.seek(Duration.zero, index: index);
    await _player.play();
    _broadcastState();
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  /// Replaces the queue and starts playing the song at [index].
  Future<void> playSongs(
    List<Song> songs, {
    int index = 0,
    bool shuffle = false,
    bool autoplay = true,
  }) async {
    if (songs.isEmpty) return;
    _songs = List<Song>.of(songs);
    _index = index.clamp(0, songs.length - 1);
    _lastRecordedSongId = null;
    _resumePosition = Duration.zero;
    _shuffleEnabled = shuffle;
    _currentSong = _songs[_index];
    _currentSongController.add(_currentSong);
    _queueController.add(List<Song>.unmodifiable(_songs));
    queue.add([for (final song in _songs) _mediaItemFor(song)]);
    mediaItem.add(_mediaItemFor(_currentSong!));
    await _persistQueue();
    await _loadQueue(index: _index, autoplay: autoplay);
  }

  Future<void> _loadQueue({
    required int index,
    Duration initialPosition = Duration.zero,
    bool autoplay = false,
  }) async {
    try {
      final sources = [for (final song in _songs) _sourceFor(song)];
      await _player.setAudioSources(
        sources,
        initialIndex: index.clamp(0, _songs.length - 1),
        initialPosition: initialPosition,
      );
      _ensurePositionTimer();
      final activeIndex = _player.currentIndex ?? index;
      if (activeIndex >= 0 && activeIndex < _songs.length) {
        final newlyRecorded = await _recordSongIfNeeded(_songs[activeIndex]);
        if (newlyRecorded) {
          _songStartController.add(
            SongStart(song: _songs[activeIndex], startedAt: DateTime.now()),
          );
        }
      }
      _resumePosition = Duration.zero;
      await _player.setShuffleModeEnabled(_shuffleEnabled);
      if (_shuffleEnabled) {
        await _player.shuffle();
        await _player.seek(initialPosition, index: index);
      }
      if (autoplay) await _player.play();
      _broadcastState();
      unawaited(_applyEqualizerFromSettings());
    } on PlayerException catch (error) {
      _errorController.add(error.message ?? 'This track could not be played.');
      _broadcastState();
    } catch (_) {
      _errorController.add('Playback could not start.');
    }
  }

  Future<void> _applyEqualizerFromSettings() async {
    try {
      await applyEqualizer(await _settings.loadSettings());
    } catch (_) {
      // Audio effects are optional and device-dependent.
    }
  }

  AudioSource _sourceFor(Song song) {
    final source = song.playbackSource;
    if (source.startsWith('content://')) {
      return AudioSource.uri(Uri.parse(source), tag: song);
    }
    return AudioSource.file(source, tag: song);
  }

  // ---------------------------------------------------------------------
  // Queue management
  // ---------------------------------------------------------------------

  Future<void> addToQueue(List<Song> songs, {bool playNext = false}) async {
    if (songs.isEmpty) return;
    if (_songs.isEmpty) {
      await playSongs(songs);
      return;
    }

    final currentIndex = _player.currentIndex ?? _index;
    final insertIndex = playNext
        ? (currentIndex + 1).clamp(0, _songs.length)
        : _songs.length;
    _songs.insertAll(insertIndex, songs);
    if (_player.audioSources.isNotEmpty) {
      await _player.insertAudioSources(insertIndex, [
        for (final song in songs) _sourceFor(song),
      ]);
    }
    queue.add([for (final song in _songs) _mediaItemFor(song)]);
    _queueController.add(List<Song>.unmodifiable(_songs));
    await _persistQueue();
    _broadcastState();
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= _songs.length) return;
    final currentIndex = _player.currentIndex ?? _index;
    final removingCurrent = index == currentIndex;

    _songs.removeAt(index);
    if (_player.audioSources.isNotEmpty) {
      await _player.removeAudioSourceAt(index);
    }

    if (_songs.isEmpty) {
      _currentSong = null;
      _index = 0;
      _lastRecordedSongId = null;
      _currentSongController.add(null);
      mediaItem.add(null);
      queue.add([]);
      _queueController.add(const []);
      _positionTimer?.cancel();
      _positionTimer = null;
      if (_player.audioSources.isNotEmpty) {
        await _player.clearAudioSources();
        await _player.stop();
      }
      await _persistQueue();
      _broadcastState();
      return;
    }

    if (removingCurrent) {
      _index = (_player.currentIndex ?? index).clamp(0, _songs.length - 1);
      _currentSong = _songs[_index];
      _currentSongController.add(_currentSong);
      mediaItem.add(_mediaItemFor(_currentSong!));
    }
    queue.add([for (final song in _songs) _mediaItemFor(song)]);
    _queueController.add(List<Song>.unmodifiable(_songs));
    await _persistQueue();
    _broadcastState();
  }

  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= _songs.length) return;
    final targetIndex = newIndex.clamp(0, _songs.length - 1).toInt();
    if (targetIndex == oldIndex) return;

    final song = _songs.removeAt(oldIndex);
    _songs.insert(targetIndex, song);
    if (_player.audioSources.isNotEmpty) {
      await _player.moveAudioSource(oldIndex, targetIndex);
    }
    _index = (_player.currentIndex ?? _index).clamp(0, _songs.length - 1);
    _currentSong = _songs[_index];
    queue.add([for (final s in _songs) _mediaItemFor(s)]);
    _queueController.add(List<Song>.unmodifiable(_songs));
    await _persistQueue();
    _broadcastState();
  }

  // ---------------------------------------------------------------------
  // Shuffle & repeat
  // ---------------------------------------------------------------------

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    _shuffleEnabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffleModeEnabled(_shuffleEnabled);
    if (_shuffleEnabled) await _player.shuffle();
    _broadcastState();
  }

  Future<bool> toggleShuffle() async {
    await setShuffleMode(
      _shuffleEnabled
          ? AudioServiceShuffleMode.none
          : AudioServiceShuffleMode.all,
    );
    return _shuffleEnabled;
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _repeatMode = repeatMode;
    await _player.setLoopMode(_loopModeFor(repeatMode));
    final settings = await _settings.loadSettings();
    await _settings.saveSettings(
      settings.copyWith(repeatMode: _repeatSettingFor(repeatMode)),
    );
    _broadcastState();
  }

  Future<AudioServiceRepeatMode> cycleRepeat() async {
    final next = switch (_repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      _ => AudioServiceRepeatMode.none,
    };
    await setRepeatMode(next);
    return next;
  }

  LoopMode _loopModeFor(AudioServiceRepeatMode mode) => switch (mode) {
    AudioServiceRepeatMode.none => LoopMode.off,
    AudioServiceRepeatMode.one => LoopMode.one,
    _ => LoopMode.all,
  };

  RepeatSetting _repeatSettingFor(AudioServiceRepeatMode mode) =>
      switch (mode) {
        AudioServiceRepeatMode.none => RepeatSetting.off,
        AudioServiceRepeatMode.one => RepeatSetting.one,
        _ => RepeatSetting.all,
      };

  Future<void> _applyRepeatSetting(RepeatSetting setting) async {
    _repeatMode = switch (setting) {
      RepeatSetting.off => AudioServiceRepeatMode.none,
      RepeatSetting.all => AudioServiceRepeatMode.all,
      RepeatSetting.one => AudioServiceRepeatMode.one,
    };
    await _player.setLoopMode(_loopModeFor(_repeatMode));
  }

  // ---------------------------------------------------------------------
  // Equalizer (real Android audio effects through just_audio)
  // ---------------------------------------------------------------------

  Future<AndroidEqualizerParameters?> equalizerParameters({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final equalizer = _equalizer;
    if (equalizer == null) return null;
    try {
      return await equalizer.parameters.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> applyEqualizer(AppSettings settings) async {
    final equalizer = _equalizer;
    final loudness = _loudness;
    if (equalizer == null || loudness == null) return;
    try {
      final parameters = await equalizer.parameters.timeout(
        const Duration(seconds: 2),
      );
      await equalizer.setEnabled(settings.equalizerEnabled);
      final frequencies = [
        for (final band in parameters.bands) band.centerFrequency,
      ];
      final gains = EqualizerPresets.effectiveGains(
        frequencies: frequencies,
        preset: settings.equalizerPreset,
        customGains: settings.equalizerGains,
        bass: settings.bassBoost,
        treble: settings.trebleBoost,
        minDb: parameters.minDecibels,
        maxDb: parameters.maxDecibels,
      );
      for (var i = 0; i < parameters.bands.length; i++) {
        if (i >= gains.length) break;
        await parameters.bands[i].setGain(gains[i]);
      }
      final loudnessEnabled =
          settings.equalizerEnabled && settings.loudnessGain > 0;
      await loudness.setEnabled(loudnessEnabled);
      if (loudnessEnabled) {
        await loudness.setTargetGain(settings.loudnessGain);
      }
    } catch (_) {
      // Not every Android device exposes an equalizer; the UI explains this.
    }
  }

  // ---------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------

  Future<void> _persistQueue() async {
    if (_songs.isEmpty) {
      try {
        await _settings.saveQueue(const [], 0);
      } catch (_) {
        // Ignore transient database errors.
      }
      return;
    }
    final index = (_player.currentIndex ?? _index).clamp(0, _songs.length - 1);
    try {
      await _settings.saveQueue([for (final song in _songs) song.id], index);
    } catch (_) {
      // Persistence failures must never interrupt playback.
    }
  }

  Future<void> _persistPosition() async {
    if (_currentSong == null || _player.audioSources.isEmpty) return;
    try {
      await _settings.saveLastPosition(
        _currentSong!.id,
        _player.position.inMilliseconds,
      );
    } catch (_) {
      // Ignore transient database errors while the app is backgrounded.
    }
  }

  Future<void> _restoreQueue() async {
    try {
      final saved = await _settings.loadQueue();
      if (saved.songIds.isEmpty) return;
      final songs = await _music.getSongsByIds(saved.songIds);
      if (songs.isEmpty) {
        await _settings.saveQueue(const [], 0);
        return;
      }

      _songs = songs;
      _index = saved.index.clamp(0, songs.length - 1);
      _currentSong = songs[_index];
      _currentSongController.add(_currentSong);
      _queueController.add(List<Song>.unmodifiable(_songs));
      queue.add([for (final song in _songs) _mediaItemFor(song)]);
      mediaItem.add(_mediaItemFor(_currentSong!));

      final last = await _settings.loadLastPosition();
      final appSettings = await _settings.loadSettings();
      if (appSettings.resumeLastSession &&
          last.songId == _currentSong!.id &&
          last.positionMs > 0) {
        _resumePosition = Duration(milliseconds: last.positionMs);
      }
      _broadcastState();
    } catch (_) {
      // A corrupt saved queue should not prevent the player from starting.
    }
  }

  Future<void> _handleIndexChange(int? index) async {
    if (index == null || index < 0 || index >= _songs.length) return;
    _index = index;
    final song = _songs[index];
    _currentSong = song;
    _currentSongController.add(song);
    mediaItem.add(_mediaItemFor(song));
    try {
      await _settings.saveQueueIndex(index);
    } catch (_) {
      // Queue position persistence is best-effort.
    }
    if (await _recordSongIfNeeded(song)) {
      _songStartController.add(
        SongStart(song: song, startedAt: DateTime.now()),
      );
    }
    _broadcastState();
  }

  /// Returns true when this song id was not the last recorded song.
  Future<bool> _recordSongIfNeeded(Song song) async {
    if (_lastRecordedSongId == song.id) return false;
    _lastRecordedSongId = song.id;
    try {
      await _playlists.recordPlay(song.id);
    } catch (_) {
      // Listening history is best-effort.
    }
    return true;
  }

  void _broadcastState() {
    final playing = _player.playing;
    final loaded = _player.audioSources.isNotEmpty;
    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          playing ? MediaControl.pause : MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        processingState: _mapProcessingState(_player.processingState),
        playing: playing,
        updatePosition: loaded ? _player.position : _resumePosition,
        bufferedPosition: loaded ? _player.bufferedPosition : Duration.zero,
        speed: _player.speed,
        queueIndex: loaded ? _player.currentIndex : _index,
        repeatMode: _repeatMode,
        shuffleMode: _shuffleEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  MediaItem _mediaItemFor(Song song) {
    final albumId = song.albumId;
    return MediaItem(
      id: '${song.id}',
      title: song.title,
      artist: song.displayArtist,
      album: song.displayAlbum,
      genre: song.genre,
      duration: song.duration,
      artUri: albumId != null && albumId > 0
          ? Uri.parse('content://media/external/audio/albumart/$albumId')
          : null,
      extras: song.uri.isNotEmpty ? {'loadThumbnailUri': song.uri} : null,
    );
  }
}
