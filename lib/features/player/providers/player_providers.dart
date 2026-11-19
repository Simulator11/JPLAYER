import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/song.dart';
import '../services/audio_handler.dart';

/// Overridden in main() with the initialised background handler.
final audioHandlerProvider = Provider<JPlayerAudioHandler>(
  (ref) =>
      throw StateError('audioHandlerProvider must be overridden in main()'),
);

final currentSongProvider = StreamProvider<Song?>(
  (ref) => ref.watch(audioHandlerProvider).currentSongStream,
);

final songStartedProvider = StreamProvider<SongStart>(
  (ref) => ref.watch(audioHandlerProvider).songStartedStream,
);

final playbackStateProvider = StreamProvider<PlaybackState>(
  (ref) => ref.watch(audioHandlerProvider).playbackState.stream,
);

final queueSongsProvider = StreamProvider<List<Song>>(
  (ref) => ref.watch(audioHandlerProvider).queueSongsStream,
);

final positionProvider = StreamProvider<Duration>(
  (ref) => ref.watch(audioHandlerProvider).positionStream,
);

final durationProvider = StreamProvider<Duration?>(
  (ref) => ref.watch(audioHandlerProvider).durationStream,
);

final playerErrorProvider = StreamProvider<String>(
  (ref) => ref.watch(audioHandlerProvider).errorStream,
);

final isPlayingProvider = Provider<bool>((ref) {
  return ref.watch(playbackStateProvider).value?.playing ?? false;
});

final repeatModeProvider = Provider<AudioServiceRepeatMode?>((ref) {
  return ref.watch(playbackStateProvider).value?.repeatMode;
});

final shuffleEnabledProvider = Provider<bool>((ref) {
  final mode = ref.watch(playbackStateProvider).value?.shuffleMode;
  return mode != null && mode != AudioServiceShuffleMode.none;
});

class SleepTimerState {
  const SleepTimerState({
    this.endsAt,
    this.endOfTrack = false,
    this.remaining,
    this.justFinished = false,
  });

  final DateTime? endsAt;
  final bool endOfTrack;
  final Duration? remaining;
  final bool justFinished;

  bool get active => endsAt != null || endOfTrack;

  SleepTimerState copyWith({
    DateTime? endsAt,
    bool? endOfTrack,
    Duration? remaining,
    bool? justFinished,
    bool clearEndsAt = false,
  }) {
    return SleepTimerState(
      endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
      endOfTrack: endOfTrack ?? this.endOfTrack,
      remaining: remaining ?? this.remaining,
      justFinished: justFinished ?? this.justFinished,
    );
  }
}

final sleepTimerProvider =
    NotifierProvider<SleepTimerController, SleepTimerState>(
      SleepTimerController.new,
      isAutoDispose: false,
    );

class SleepTimerController extends Notifier<SleepTimerState> {
  Timer? _ticker;
  StreamSubscription<PlaybackState>? _playbackSubscription;
  Timer? _finishNoticeTimer;

  @override
  SleepTimerState build() {
    ref.onDispose(() {
      _ticker?.cancel();
      _playbackSubscription?.cancel();
      _finishNoticeTimer?.cancel();
    });
    return const SleepTimerState();
  }

  void start(Duration duration) {
    _cancelTimers();
    final endsAt = DateTime.now().add(duration);
    state = SleepTimerState(endsAt: endsAt, remaining: duration);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = endsAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        _finish();
      } else {
        state = state.copyWith(remaining: remaining);
      }
    });
  }

  void stopAtEndOfTrack() {
    _cancelTimers();
    state = const SleepTimerState(endOfTrack: true);
    _playbackSubscription = ref
        .read(audioHandlerProvider)
        .playbackState
        .stream
        .listen((state) {
          if (state.processingState == AudioProcessingState.completed) {
            _finish();
          }
        });
  }

  void cancel() {
    _cancelTimers();
    state = const SleepTimerState();
  }

  void acknowledgeFinished() {
    if (state.justFinished) {
      state = const SleepTimerState();
    }
  }

  Future<void> _finish() async {
    _cancelTimers();
    try {
      await ref.read(audioHandlerProvider).pause();
    } catch (_) {
      // Nothing else to do if the engine is already stopped.
    }
    state = const SleepTimerState(justFinished: true);
    _finishNoticeTimer = Timer(const Duration(seconds: 5), () {
      if (state.justFinished) state = const SleepTimerState();
    });
  }

  void _cancelTimers() {
    _ticker?.cancel();
    _ticker = null;
    _playbackSubscription?.cancel();
    _playbackSubscription = null;
    _finishNoticeTimer?.cancel();
    _finishNoticeTimer = null;
  }
}
