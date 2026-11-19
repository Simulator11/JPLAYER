import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../data/models/song.dart';

class LyricLine {
  const LyricLine({required this.time, required this.text});

  final Duration time;
  final String text;
}

/// Parsed lyrics. [isSynced] is true when timestamped LRC lines were found.
class LyricsDocument {
  const LyricsDocument({
    required this.lines,
    required this.plainLines,
    required this.sourcePath,
    required this.isSynced,
  });

  final List<LyricLine> lines;
  final List<String> plainLines;
  final String? sourcePath;
  final bool isSynced;

  String get plainText => plainLines.join('\n');

  int get lineCount => isSynced ? lines.length : plainLines.length;

  /// Index of the last synced line at or before [position].
  int indexAt(Duration position) {
    if (lines.isEmpty) return -1;
    if (position < lines.first.time) return -1;
    var low = 0;
    var high = lines.length - 1;
    var result = -1;
    while (low <= high) {
      final mid = (low + high) ~/ 2;
      if (lines[mid].time <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}

/// Finds and parses `.lrc` / `.txt` lyrics stored next to a song, or a file the
/// user explicitly picked.
///
/// JPlayer never downloads lyrics, so the player remains fully offline.
class LyricsService {
  const LyricsService();

  Future<LyricsDocument?> loadForSong(Song song, {String? manualPath}) async {
    final candidates = <String>[];
    void add(String? value) {
      if (value != null &&
          value.isNotEmpty &&
          !value.startsWith('content://') &&
          !candidates.contains(value)) {
        candidates.add(value);
      }
    }

    add(manualPath);
    if (song.path.startsWith('/')) {
      final directory = p.dirname(song.path);
      final base = p.basenameWithoutExtension(song.path);
      for (final extension in const ['lrc', 'LRC', 'Lrc', 'txt', 'TXT']) {
        add(p.join(directory, '$base.$extension'));
      }
      final title = song.title.trim();
      if (title.isNotEmpty && title != base) {
        final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        for (final extension in const ['lrc', 'LRC', 'txt']) {
          add(p.join(directory, '$safeTitle.$extension'));
        }
      }
      add(p.join(directory, 'lyrics', '$base.lrc'));
    }

    for (final candidate in candidates) {
      try {
        final file = File(candidate);
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        final parsed = parse(content, sourcePath: candidate);
        if (parsed != null) return parsed;
      } catch (_) {
        // Try the next candidate; unreadable files must not break playback.
      }
    }
    return null;
  }

  LyricsDocument? parse(String content, {String? sourcePath}) {
    if (content.trim().isEmpty) return null;
    final timePattern = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
    final offsetMatch = RegExp(
      r'\[offset:\s*([+-]?\d+)\s*\]',
      caseSensitive: false,
    ).firstMatch(content);
    final offsetMs = int.tryParse(offsetMatch?.group(1) ?? '') ?? 0;

    final timed = <LyricLine>[];
    final plain = <String>[];

    for (final rawLine in const LineSplitter().convert(content)) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (timed.isEmpty) plain.add('');
        continue;
      }
      final matches = timePattern.allMatches(line).toList();
      if (matches.isEmpty) {
        final looksLikeMetadata =
            line.startsWith('[') && line.endsWith(']') && line.contains(':');
        if (!looksLikeMetadata) plain.add(line);
        continue;
      }
      final text = line.replaceAll(timePattern, '').trim();
      for (final match in matches) {
        final minutes = int.tryParse(match.group(1) ?? '') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '') ?? 0;
        final fractionText = match.group(3) ?? '0';
        final fraction =
            int.tryParse(fractionText.padRight(3, '0').substring(0, 3)) ?? 0;
        final milliseconds =
            minutes * 60000 + seconds * 1000 + fraction + offsetMs;
        if (milliseconds < 0) continue;
        timed.add(
          LyricLine(
            time: Duration(milliseconds: milliseconds),
            text: text.isEmpty ? '♪' : text,
          ),
        );
      }
    }

    if (timed.isNotEmpty) {
      timed.sort((a, b) => a.time.compareTo(b.time));
      return LyricsDocument(
        lines: List.unmodifiable(timed),
        plainLines: List.unmodifiable(timed.map((line) => line.text)),
        sourcePath: sourcePath,
        isSynced: true,
      );
    }

    while (plain.isNotEmpty && plain.first.isEmpty) {
      plain.removeAt(0);
    }
    while (plain.isNotEmpty && plain.last.isEmpty) {
      plain.removeLast();
    }
    if (plain.isEmpty) return null;
    return LyricsDocument(
      lines: const [],
      plainLines: List.unmodifiable(plain),
      sourcePath: sourcePath,
      isSynced: false,
    );
  }
}
