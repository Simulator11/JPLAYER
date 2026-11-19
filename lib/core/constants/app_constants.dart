/// Centralised, static values used across JPlayer.
class AppConstants {
  const AppConstants._();

  static const String appName = 'JPlayer';
  static const String slogan = 'Your Music, Your Way.';
  static const String version = '1.0.0';
  static const String packageName = 'com.jplayer.app';

  /// Developer credit shown in About and Settings.
  static const String developerName = 'Japhsam Simulator';
  static const String portfolioUrl = 'https://japhsamsimulator.me.tz';
  static const String portfolioLabel = 'japhsamsimulator.me.tz';

  static const String databaseName = 'jplayer.db';
  static const int databaseVersion = 1;

  /// Number of songs kept in transient "recently played" views.
  static const int homeSectionSize = 20;

  /// A full MediaStore rescan is skipped on launch until this interval elapses.
  static const Duration autoScanInterval = Duration(hours: 24);

  static const String notificationChannel = 'com.jplayer.app.playback';
  static const String notificationChannelName = 'Playback';
  static const String notificationChannelDescription =
      'Playback controls for music playing in JPlayer';

  /// Extensions used for the "supported formats" documentation and for
  /// filtering user-picked lyric/subtitle files.
  static const List<String> audioExtensions = [
    'mp3',
    'm4a',
    'aac',
    'flac',
    'wav',
    'ogg',
    'opus',
    'wma',
  ];

  static const List<String> videoExtensions = [
    'mp4',
    'mkv',
    'avi',
    'mov',
    '3gp',
    'webm',
  ];
}
