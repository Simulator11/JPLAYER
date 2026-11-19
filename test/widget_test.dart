import 'package:flutter_test/flutter_test.dart';

import 'package:jplayer/core/audio/equalizer_presets.dart';
import 'package:jplayer/core/services/lyrics_service.dart';
import 'package:jplayer/features/videos/services/subtitles.dart';
import 'package:jplayer/core/utils/formatters.dart';

void main() {
  test('formats song durations', () {
    expect(Formatters.duration(const Duration(seconds: 207)), '3:27');
    expect(
      Formatters.duration(const Duration(hours: 1, minutes: 2, seconds: 9)),
      '1:02:09',
    );
    expect(Formatters.duration(null), '--:--');
  });

  test('parses synced LRC lyrics', () {
    const content =
        '[ar:Artist]\n'
        '[00:01.50]First line\n'
        '[00:05.00][00:08.20]Repeated\n';
    final lyrics = const LyricsService().parse(content);
    expect(lyrics, isNotNull);
    expect(lyrics!.isSynced, isTrue);
    expect(lyrics.lines.length, 3);
    expect(lyrics.lines.first.time, const Duration(milliseconds: 1500));
    expect(lyrics.indexAt(const Duration(seconds: 6)), 1);
  });

  test('parses plain text lyrics', () {
    final lyrics = const LyricsService().parse('Line one\nLine two');
    expect(lyrics, isNotNull);
    expect(lyrics!.isSynced, isFalse);
    expect(lyrics.plainText, contains('Line two'));
  });

  test('parses SRT subtitles', () {
    const srt =
        '1\n'
        '00:00:01,000 --> 00:00:03,000\n'
        'Hello\n\n'
        '2\n'
        '00:00:04,000 --> 00:00:06,000\n'
        'World\n';
    final track = SubtitleParser.parse(srt);
    expect(track, isNotNull);
    expect(track!.cues.length, 2);
    expect(track.textAt(const Duration(seconds: 2)), 'Hello');
    expect(track.textAt(const Duration(seconds: 5)), 'World');
    expect(track.textAt(const Duration(seconds: 3, milliseconds: 500)), '');
  });

  test('maps equalizer presets to device band frequencies', () {
    final gains = EqualizerPresets.effectiveGains(
      frequencies: const [60, 230, 910, 3600, 14000],
      preset: 'Bass Boost',
      customGains: const [],
      bass: 2,
      treble: 1,
      minDb: -12,
      maxDb: 12,
    );
    expect(gains.length, 5);
    expect(gains.first, greaterThan(0));
    expect(gains.every((gain) => gain >= -12 && gain <= 12), isTrue);
  });
}
