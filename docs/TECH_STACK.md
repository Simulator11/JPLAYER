# JPlayer Technology Stack

This document records the exact stack used by each part of JPlayer. Versions are the resolved versions in `pubspec.lock` and the Android Gradle configuration at the time of the `v1.0.0` build.

## Runtime and language

| Component | Version | Role |
| --- | --- | --- |
| Flutter | 3.50.0 (stable) | Cross-platform UI framework, Android build tooling |
| Dart | 3.14.0 | Application, state, database and service logic |
| Java | 17 | Android compilation (AGP/Kotlin target) |
| Kotlin | 2.4.20 | Native Android bridge |
| Gradle | 9.5.0 | Android build system |
| Android Gradle Plugin | 9.3.1 | Android application build |
| Android SDK | compileSdk 37, targetSdk 36, minSdk 24 | Scoped media APIs and Android 7+ support |
| NDK | 30.0.16248370 (pinned) | Installed toolchain; no JPlayer dependency ships custom native code |

## Dart and Flutter packages

| Package | Resolved version | Used for |
| --- | --- | --- |
| `material_ui` | 1.11.1 | Material 3 widgets, `ThemeData`, `ColorScheme` |
| `flutter_riverpod` / `riverpod` | 3.5.0 | Dependency injection, state, async controllers and streams |
| `just_audio` | 0.10.6 | Audio engine, playlists, seeking, audio effects pipeline |
| `audio_service` | 0.18.19 | Android media session, foreground service, notification and media buttons |
| `audio_session` | 0.2.4 | Music audio session, focus/interruption configuration, becoming-noisy events |
| `sqflite` | 2.4.6 | SQLite persistence on Android |
| `permission_handler` | 13.0.2 | Runtime media/notification permission flow |
| `permission_handler_android` | 14.1.1 | Android permission implementation (requires compileSdk 37) |
| `material_color_utilities` | 0.13.0 | Artwork palette quantization |
| `video_player` | 2.14.1 | Local video playback |
| `video_player_android` | 2.12.4 | Android video platform implementation (Media3) |
| `file_picker` | 13.4.0 | Storage Access Framework pick/save dialogs for lyrics, subtitles and backup |
| `path_provider` | 2.1.6 | App support directory for persistent manual lyrics |
| `path_provider_android` | 2.2.23 (override) | Platform paths without the JNI module used by 2.3.x |
| `url_launcher` | 6.3.3 | Opening the developer portfolio in the device browser |
| `url_launcher_android` | 6.3.35 | Android URL-launch implementation |
| `path` | 1.9.1 | File/path manipulation for lyrics lookup |

## Stack by feature

| Feature | Stack | Implementation |
| --- | --- | --- |
| App bootstrap | Dart, Riverpod, sqflite, audio_service | `main.dart` opens SQLite, loads settings, initialises `JPlayerAudioHandler`, then starts `ProviderScope` with overridden database/settings/handler providers. |
| Design system | Material 3, `material_ui`, `ThemeExtension` | `JPlayerPalette` carries brand surfaces, accent, on-accent and text colours for light, dark and AMOLED themes. `AppTheme` maps them into `ColorScheme` and component themes. |
| Navigation | Flutter Navigator, Riverpod | Root four-tab shell with `IndexedStack`, mini player, animated Now Playing route, nested settings routes. |
| Library state | Riverpod `AsyncNotifier`, `FutureProvider`, `StreamProvider` | `LibraryController` loads cached songs and derives albums/artists/genres/folders; playback and scan providers expose streams. |
| Media discovery | Kotlin, Android `MediaStore`, `MethodChannel` | `MediaChannel.kt` queries audio, genres and video on a background executor, extracts artwork/thumbnails with `MediaMetadataRetriever`, scans files and controls screen brightness. |
| Scan orchestration | Dart, Kotlin, sqflite | `MediaScannerService` filters system sounds/excluded folders, `MusicRepository.syncSongs` reconciles by path or content URI in the background inside SQLite transactions. |
| Persistence | SQLite via sqflite | Versioned schema with songs, favorites, playlists, membership, history, play counts, queue, settings, videos, exclusions, lyrics overrides, searches and EQ presets. Foreign keys cascade. |
| Playback engine | `just_audio`, `audio_service` | One player with a queue of `AudioSource`s; `BaseAudioHandler` exposes media session controls, notification, lock screen and headset events. |
| Queue/resume | `just_audio`, sqflite | Queue IDs and current index are persisted. Position is stored every 10 seconds and restored when “Resume last session” is enabled. |
| Audio focus | `audio_session`, `just_audio` | Music session configuration; interruptions handled by the engine; noisy-headphone event pauses playback and persists position. |
| Equalizer | `just_audio` `AndroidEqualizer`, `AndroidLoudnessEnhancer` | Real Android effects attached through `AudioPipeline`; ten-anchor preset curves are interpolated onto the device bands; custom presets stored in SQLite. |
| Lyrics | Dart parser, `path`, `file_picker` | LRC timestamps/offsets and plain text parsing; adjacent `.lrc`/`.txt` lookup; manual files copied to app support storage for persistence. |
| Video | `video_player`, Android MediaStore | Grid of native thumbnails; full-screen player with seeking, speed, aspect modes, brightness/volume gestures, SRT/WebVTT subtitles and stored positions. |
| Search | sqflite, Dart | SQL `LIKE` search over title, artist, album, genre and filename, with recent-search storage and in-memory album/artist filtering. |
| Playlists/favorites/history | sqflite, Riverpod | Transactional membership operations, maximum 5,000 history rows, smart lists for favorites/recent/most played/recently added. |
| Backup/restore | `file_picker`, `dart:convert` | JSON document containing settings, favorites, playlists, exclusions and EQ presets; songs matched by path or content URI on restore. |
| Permissions | `permission_handler`, Kotlin SDK check | Android 13+ `READ_MEDIA_AUDIO`/`READ_MEDIA_VIDEO`; legacy storage on API ≤32; notification permission; denial and permanently-denied UI paths. |
| Developer links | `url_launcher`, Android `<queries>` | Portfolio opens in an external browser; release build still has no INTERNET permission. |
| Testing | `flutter_test` | 11 unit tests covering formatting, LRC, SRT, EQ mapping, library grouping, folder/system-sound filtering, settings JSON, palette contrast and developer constants. |

## Android platform details

- Package/application ID: `com.jplayer.app`
- Activity: `MainActivity` extends `AudioServiceFragmentActivity`
- Media service: `com.ryanheise.audioservice.AudioService` with `foregroundServiceType="mediaPlayback"`
- Media button receiver: `com.ryanheise.audioservice.MediaButtonReceiver`
- Scoped media permissions; **no** `MANAGE_EXTERNAL_STORAGE`
- Release permission set excludes `INTERNET`; `ACCESS_NETWORK_STATE` is contributed by AndroidX Media3
- Release signing: debug keystore for this public preview build
- Icon/splash assets: adaptive/monochrome vectors plus generated legacy PNGs

## Why these choices

- **MediaStore instead of all-files access:** works with scoped storage and Play Store policy without `MANAGE_EXTERNAL_STORAGE`.
- **SQLite cache instead of rescanning on every screen:** fast browsing on large libraries; MediaStore remains the source of truth.
- **Path/URI reconciliation:** preserves favorites, playlists and history when MediaStore IDs change.
- **One audio engine and one background handler:** avoids duplicate players, notification sessions or audio-focus conflicts.
- **Real Android audio effects:** the equalizer reports unavailable hardware instead of showing decorative sliders.
- **Local-only artwork pipeline:** embedded art and thumbnails are extracted and cached natively; no network artwork fetches.
