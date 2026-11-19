import 'dart:math' as math;

/// Formatting helpers used by the library UI.
class Formatters {
  const Formatters._();

  /// `3:27` for short tracks, `1:02:09` for long ones.
  static String duration(Duration? duration) {
    if (duration == null) return '--:--';
    final totalSeconds = duration.inSeconds.clamp(0, 359999);
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  static String milliseconds(int? milliseconds) => duration(
    milliseconds == null ? null : Duration(milliseconds: milliseconds),
  );

  static String fileSize(int bytes) {
    if (bytes <= 0) return '0 MB';
    const units = ['B', 'KB', 'MB', 'GB'];
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final decimals = value >= 100 || unit == 0 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${units[unit]}';
  }

  static String count(int value, String singular, [String? plural]) {
    final multiple = plural ?? '${singular}s';
    return '$value ${value == 1 ? singular : multiple}';
  }

  static String songCount(int value) => count(value, 'song');

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String date(DateTime value) =>
      '${value.day} ${_months[value.month - 1]} ${value.year}';

  static String relativeDate(DateTime value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final difference = today.difference(day).inDays;
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '$difference days ago';
    return date(value);
  }

  /// "Updated 12 minutes ago" style label used on the library screen.
  static String timeAgo(DateTime? value) {
    if (value == null) return 'Never scanned';
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    }
    if (diff.inHours < 24) {
      return diff.inHours == 1 ? '1 hour ago' : '${diff.inHours} hours ago';
    }
    return relativeDate(value);
  }

  static String initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  static String shorten(String value, int maxCharacters) {
    if (value.length <= maxCharacters) return value;
    return '${value.substring(0, math.max(0, maxCharacters - 1))}…';
  }
}
