import 'dart:convert';

/// One timed subtitle cue (SRT or WebVTT).
class SubtitleCue {
  const SubtitleCue({
    required this.start,
    required this.end,
    required this.text,
  });

  final Duration start;
  final Duration end;
  final String text;
}

class SubtitleTrack {
  const SubtitleTrack({required this.cues, this.sourcePath});

  final List<SubtitleCue> cues;
  final String? sourcePath;

  bool get isEmpty => cues.isEmpty;

  /// Text for [position], or an empty string between cues.
  String textAt(Duration position) {
    if (cues.isEmpty) return '';
    var low = 0;
    var high = cues.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (cues[mid].start <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    if (result < 0) return '';
    final cue = cues[result];
    if (position > cue.end) return '';
    return cue.text;
  }
}

/// Parses local `.srt` and `.vtt` subtitle files. JPlayer never fetches
/// subtitles from the internet.
class SubtitleParser {
  const SubtitleParser._();

  static final RegExp _timing = RegExp(
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
  );
  static final RegExp _htmlTags = RegExp(r'<[^>]+>');
  static final RegExp _braceTags = RegExp(r'\{[^}]*\}');

  static SubtitleTrack? parse(String content, {String? sourcePath}) {
    if (content.trim().isEmpty) return null;
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n{2,}'));
    final cues = <SubtitleCue>[];

    for (final block in blocks) {
      final lines = const LineSplitter().convert(block);
      var timingIndex = -1;
      Match? timing;
      for (var i = 0; i < lines.length; i++) {
        final match = _timing.firstMatch(lines[i]);
        if (match != null) {
          timing = match;
          timingIndex = i;
          break;
        }
      }
      if (timing == null || timingIndex < 0) continue;

      final textLines = lines
          .skip(timingIndex + 1)
          .map(
            (line) => line
                .replaceAll(_htmlTags, '')
                .replaceAll(_braceTags, '')
                .trim(),
          )
          .where((line) => line.isNotEmpty)
          .toList();
      if (textLines.isEmpty) continue;

      final start = _duration(
        timing.group(1)!,
        timing.group(2)!,
        timing.group(3)!,
        timing.group(4)!,
      );
      final end = _duration(
        timing.group(5)!,
        timing.group(6)!,
        timing.group(7)!,
        timing.group(8)!,
      );
      if (end <= start) continue;
      cues.add(SubtitleCue(start: start, end: end, text: textLines.join('\n')));
    }

    if (cues.isEmpty) return null;
    cues.sort((a, b) => a.start.compareTo(b.start));
    return SubtitleTrack(cues: List.unmodifiable(cues), sourcePath: sourcePath);
  }

  static Duration _duration(String h, String m, String s, String fraction) {
    final hours = int.tryParse(h) ?? 0;
    final minutes = int.tryParse(m) ?? 0;
    final seconds = int.tryParse(s) ?? 0;
    final milliseconds =
        int.tryParse(fraction.padRight(3, '0').substring(0, 3)) ?? 0;
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: milliseconds,
    );
  }
}
