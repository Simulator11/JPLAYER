# JPlayer

**JPlayer – Your Music, Your Way.**

JPlayer is a free, ad-free, offline-first music player for Android, built with Flutter and Dart. It plays the audio already stored on the device and adds a local video section as a secondary feature. There is no account, no subscription, no advertising SDK, no analytics and no internet permission.

The app is designed for a simple, reliable flow:

> **Open JPlayer → find your music → tap a song → enjoy listening.**

## Build and install

No prebuilt APK is stored in this repository. Build the current source locally:

```bash
flutter pub get
flutter build apk --release
```

The output is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

Install it with `adb install -r build/app/outputs/flutter-apk/app-release.apk`. Release binaries are distributed separately by the developer (kept backed up in Google Drive), so the Git repository stays small and contains source only.

## Developer

**Japhsam Simulator** — developer of JPlayer.

Portfolio: **[japhsamsimulator.me.tz](https://japhsamsimulator.me.tz)**

---

## Highlights

- A light-blue Material 3 design system with light, dark and AMOLED themes.
- Automatic local music discovery through Android MediaStore, cached in SQLite.
- Songs, albums, artists, genres and folders, with search, sorting and multi-select actions.
- Favorites, user playlists, recently played, most played and recently added — all persisted.
- Immersive Now Playing screen with artwork-derived accent colours, animated transitions and a live queue.
- Background playback with Android media notification, lock-screen controls, Bluetooth/headset buttons and audio-focus handling.
- A real five/ten-band Android equalizer, bass/treble shaping and loudness enhancement (never decorative sliders).
- Local `.lrc` / `.txt` lyrics with synced highlighting and manual file selection.
- Local video playback with gestures, subtitles, aspect modes and remembered positions.
- Local folder exclusions, sleep timer, backup/restore and a clear privacy policy.
- No ads, no trackers, no mandatory registration, no network permission.

## Documentation

- [Architecture and data flow](docs/ARCHITECTURE.md)
- [Exact technology stack by feature](docs/TECH_STACK.md)
- [Build, signing and release guide](docs/BUILD_AND_RELEASE.md)

---

## App structure

| Area | What it does |
| --- | --- |
| **Home** | Branding, search, settings, quick shuffle/favorites/videos actions, recently played, recently added, most played and recently played albums. |
| **Music** | Songs / Albums / Artists / Genres / Folders tabs, search, sort, multi-select, per-song menus, folder exclusion, videos shortcut. |
| **Playlists** | Smart playlists (Favorites, Recently played, Most played, Recently added) and persistent user playlists with add/remove/reorder/rename/delete/shuffle/play. |
| **Settings** | Theme and AMOLED, equalizer, audio-focus information, resume session, sleep timer, scan, folder exclusions, backup/restore, privacy, about. |
| **Now Playing** | Large artwork, palette-aware backdrop, seek bar, shuffle/repeat, queue, lyrics, equalizer, favorite, sleep timer and song actions. |
| **Videos** | Local video grid with thumbnails, full-screen player, speed, aspect ratio, subtitles, brightness/volume gestures and resume. |

---

## Project layout

```text
lib/
  main.dart                      # bootstrap: database, settings, audio handler
  app/
    app.dart                     # MaterialApp + theme selection
    navigation.dart              # root tab state
    root_shell.dart              # bottom navigation + mini player
    routes.dart                  # player transition + navigation helpers
    startup_gate.dart            # onboarding, auto-scan, splash and error screens
    theme/                       # centralised colours, typography, ThemeData
  core/
    audio/equalizer_presets.dart # preset curves + band interpolation
    constants/
    permissions/
    providers/                   # data / channel / service providers
    services/                    # MediaChannel, scanner, artwork, lyrics, backup…
    utils/
  data/
    database/app_database.dart   # SQLite schema (v1)
    models/                      # Song, Album, Artist, Genre, Folder, Playlist…
    repositories/                # music, playlists/history, settings
  features/
    home/ music/ playlists/ settings/ player/ equalizer/ lyrics/ videos/
    search/ onboarding/
  shared/widgets/                # artwork, tiles, rails, queue, mini player…
android/
  app/src/main/kotlin/com/jplayer/app/
    MainActivity.kt              # AudioServiceFragmentActivity + channel
    media/MediaChannel.kt        # native MediaStore + artwork bridge
  app/src/main/res/              # icon, splash, notification icon, themes
test/
  widget_test.dart              # LRC, SRT, formatting and EQ unit tests
  library_models_test.dart      # grouping, exclusions, system sounds, settings
  theme_test.dart               # palette contrast + developer/portfolio checks
tool/generate_icons.ps1          # regenerates legacy launcher PNGs
docs/                            # architecture, tech stack, build instructions
```

---

## Technology

| Purpose | Package |
| --- | --- |
| UI / Material | `material_ui` (official Flutter Material UI library for Flutter 3.47+) |
| State management | `flutter_riverpod` |
| Playback engine | `just_audio` |
| Background audio / media session | `audio_service` |
| Audio focus / interruptions | `audio_session` |
| Local database | `sqflite` |
| Media discovery | Custom Kotlin MediaStore bridge (`MethodChannel`) |
| Artwork and thumbnails | `MediaMetadataRetriever` in the native bridge |
| Video playback | `video_player` |
| File selection | `file_picker` (Storage Access Framework) |
| Permissions | `permission_handler` |
| Palette extraction | `material_color_utilities` + `dart:ui` |
| External portfolio link | `url_launcher` |

The project targets Flutter 3.50 / Dart 3.14, Android minSdk 24, targetSdk 36 and compileSdk 37.

---

## Getting started

### Requirements

- Flutter **3.50+** (Dart 3.14+) with Android tooling.
- Android SDK platform **37** and build-tools 36.
- JDK **17** (Android Studio's bundled JBR works).
- An Android 7.0+ device or emulator. Real-device testing is strongly recommended for audio focus, Bluetooth and notifications.

### Install dependencies and run

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

### Build APKs

```bash
flutter build apk --debug
flutter build apk --release
```

Artifacts are written to:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

Reference build from this workspace:

| APK | Size | Notes |
| --- | --- | --- |
| `app-debug.apk` | 245.6 MB | Flutter debug runtime, all ABIs; includes Flutter’s development INTERNET permission. |
| `app-release.apk` | 62.0 MB | `minSdk 24`, `targetSdk 36`, no INTERNET permission, signed with the debug key. |

Install on a connected device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### Build notes for this repository

- `compileSdk` is pinned to **37** because `permission_handler_android` 14.1.1 compiles against API 37. The installed SDK already contains `platforms/android-37.0`.
- `ndkVersion` is pinned to the installed NDK `30.0.16248370`. No JPlayer dependency needs the Flutter-default NDK 28.2.
- `path_provider_android` is pinned to **2.2.23** through `dependency_overrides`. The 2.3.x line adds a JNI native module and a second NDK requirement; the 2.2.x implementation provides the same platform channels without native code.
- The release build uses the debug signing key so the APK is installable from this repository. Replace `signingConfig` with your own release keystore before publishing.
- `android/gradle.properties` limits the Gradle heap to 1.28 GB and uses a single-use daemon because the reference build machine has only 3 GB of RAM. Raise `org.gradle.jvmargs` on a normal workstation if you want faster builds.
- `tool/generate_icons.ps1` regenerates the legacy PNG launcher icons; adaptive icons (Android 8+) and the splash/notification vectors live under `android/app/src/main/res/`.

---

## Android permissions

| Permission | Why | Behaviour |
| --- | --- | --- |
| `READ_MEDIA_AUDIO` | Find local music on Android 13+ | Requested on first launch. |
| `READ_MEDIA_VIDEO` | Optional local video browser on Android 13+ | Requested only when opening Videos; denial does not affect music. |
| `READ_EXTERNAL_STORAGE` (`maxSdkVersion=32`) | Local music/video on Android 12 and below | Requested only on older devices. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK` | Background audio playback | Used by the audio service. |
| `POST_NOTIFICATIONS` | Media notification visibility on Android 13+ | Requested after audio access; denial does not block playback. |
| `ACCESS_NETWORK_STATE` | Added by AndroidX Media3 | Used only for local decoder/network-state bookkeeping; grants no internet access. |
| `INTERNET` | **Removed** in release with `tools:node="remove"` | JPlayer is fully offline. Debug builds include it only because the Flutter tool uses it for hot reload/observatory. |

JPlayer does **not** request `MANAGE_EXTERNAL_STORAGE`. Media access uses MediaStore; the Storage Access Framework is used only for user-initiated files (lyrics, subtitles, backups, restore).

---

## Local media discovery

The Flutter layer calls a native Kotlin bridge (`com.jplayer/media`) that queries:

- `MediaStore.Audio.Media` (all external volumes) for music.
- `MediaStore.Audio.Genres` + genre membership for genre browsing.
- `MediaStore.Video.Media` for the secondary video section.
- `MediaMetadataRetriever` for embedded artwork and video thumbnails, cached as JPEGs under the app cache.

`MediaScannerService` then:

1. Filters songs whose `relative_path` matches an excluded folder.
2. Upserts them into the SQLite `songs` table in batches (300 rows per commit) with progress updates.
3. Removes rows that disappeared from MediaStore; foreign keys cascade cleanup to favorites, playlists, history and the queue.
4. Caches the last scan time.

Scans run asynchronously off the UI thread. The app scans automatically on first launch and when `scanOnLaunch` is enabled and the cache is empty or older than 24 hours. Manual rescans are available from Home (pull to refresh), Music → overflow → Rescan, Settings and Folder exclusions.

Duplicate entries are avoided with `media_id` as the primary key plus path reconciliation. If a file moved and MediaStore reused an id, the existing row is updated instead of duplicated.

MediaStore normally surfaces MP3, M4A/AAC, FLAC, WAV, OGG/Opus and (where indexed by the device) WMA. JPlayer accepts any audio row Android exposes except ringtones, notification sounds and alarms; decoding ultimately depends on the device's media codecs, so an unsupported file is reported and skipped instead of crashing.

---

## Playback and background audio

- `JPlayerAudioHandler` owns one `just_audio` player with a gapless playlist queue. It implements `BaseAudioHandler`, so `audio_service` receives the media session, notification, lock-screen, Bluetooth and headset events.
- `AudioService.init` registers `AudioServiceConfig` with the `drawable/ic_stat_music` notification icon and light-blue notification colour.
- `MainActivity` extends `AudioServiceFragmentActivity`; the service and media-button receiver are declared in the manifest with `foregroundServiceType="mediaPlayback"`.
- `audio_session` is configured for music. `just_audio` handles audio focus and interruptions; `becomingNoisyEventStream` pauses playback when headphones are unplugged.
- The queue, current index, last song, playback position and repeat mode are persisted in SQLite. On restart the mini-player restores the queue; pressing play resumes the saved position when **Resume last session** is enabled.
- Shuffle is implemented by just_audio's shuffle order; repeat off/all/one maps to `LoopMode`. Queue reorder/remove/add-next operate on both the engine and the persisted queue.
- Playback errors (missing/corrupt files) are reported in a snackbar; `maxSkipsOnError: 5` lets the queue skip unavailable tracks instead of stopping.

---

## Equalizer

The equalizer is implemented with Android's real audio effects through just_audio's `AudioPipeline`:

- `AndroidEqualizer` — five or ten bands depending on the device, with the device's own min/max dB range.
- `AndroidLoudnessEnhancer` — loudness boost when the device supports it.
- `AudioPipeline(androidAudioEffects: [equalizer, loudness])` attached to the single player.

Presets are stored as gain curves at ten anchor frequencies (31 Hz … 16 kHz) and interpolated onto whatever bands the device exposes. Built-in presets: Normal, Bass Boost, Classical, Dance, Electronic, Hip Hop, Jazz, Pop, Rock, Vocal. Custom curves can be saved to SQLite. Bass/Treble are convenience offsets applied to the low/high bands. All adjustments are persisted and re-applied after the player reactivates.

If the device does not expose audio effects, the screen explains this and offers a retry rather than showing fake controls.

---

## Lyrics

- JPlayer looks for an `.lrc` or `.txt` file next to the song, or in a `lyrics/` subfolder.
- LRC timestamp tags (multiple tags per line, `[offset:]` metadata) are parsed and synced to playback.
- Plain text files are displayed as scrollable lyrics.
- A lyrics file can be chosen manually through the Storage Access Framework; the override is stored per song.
- Tapping a synced line seeks to that timestamp; the list auto-scrolls with playback.

Embedded ID3 `USLT`/`SYLT` extraction is not exposed by Android's public metadata API, so JPlayer does not claim it. Local `.lrc`/`.txt` files and manual selection keep the feature fully offline.

---

## Videos

Local videos are discovered through MediaStore and displayed with native thumbnails. The player supports:

- Play/pause, seek bar, ±10s via seek bar, previous/next video.
- Playback speed 0.5×–2×.
- Aspect modes: fit, crop (cover) and stretch (fill).
- Vertical drag on the left for screen brightness, on the right for player volume, with overlays.
- Horizontal drag to preview and seek.
- SRT/WebVTT subtitle loading and rendering.
- Immersive full-screen mode, landscape toggle, remembered playback position.

Codec support depends on the device decoder. Formats such as MKV/AVI only play if the device exposes a compatible decoder; unsupported files show a clear error instead of crashing.

---

## Database and persistence

SQLite schema (version 1) in `app_database.dart`:

| Table | Contents |
| --- | --- |
| `songs` | MediaStore metadata cache (id, title, artist, album, genre, duration, path, URI, folder, etc.) |
| `favorites` | Song ids + timestamp |
| `playlists`, `playlist_songs` | User playlists and ordered membership |
| `play_history`, `play_counts` | Listening history and play counts |
| `queue` | Persisted playback queue order |
| `settings` | JSON app settings, last position, queue index, last scan time |
| `videos` | Video metadata + last position |
| `excluded_folders` | Relative folder paths |
| `lyrics_paths` | Per-song manual lyrics override |
| `searches` | Recent search history |
| `eq_presets` | Saved custom equalizer curves |

Foreign keys use `ON DELETE CASCADE ON UPDATE CASCADE` so removed/moved media cannot leave orphaned favorites, playlist entries or history. The database stores references and metadata only — never copies of the user's audio.

Preferences persist theme, AMOLED, scan-on-launch, resume session, equalizer enable/preset/gains/bass/treble/loudness and repeat mode.

### Backup and restore

`BackupService` writes a JSON document containing:

- Favorites and playlists (matched by file path).
- App settings.
- Excluded folders.
- Custom equalizer presets.

Export uses the Android file picker; restore merges playlists/favorites and applies settings/exclusions. A restore report shows how many references were matched. A rescan is recommended afterwards because folder exclusions can remove cached songs.

---

## Privacy

- No account, no ads, no subscriptions, no analytics, no advertising SDKs.
- No internet permission in the release APK: local-only by construction. (Debug builds contain INTERNET solely for Flutter's hot-reload connection.)
- Media permissions are limited to Android's scoped media permissions; no all-files access.
- The SQLite database, artwork cache and preferences live inside the app's private storage.
- Backups are generated only on request and written where the user chooses.
- `android:allowBackup="false"` prevents Android cloud backup of JPlayer's private data.
- The full policy is also available in-app: **Settings → Privacy**.

---

## Testing

### Automated checks

```bash
flutter analyze     # No issues found
flutter test        # 11 tests: formatting, LRC (synced/plain), SRT, EQ mapping,
                    # library grouping, folder exclusion, system sounds,
                    # settings JSON round-trip, blue palette contrast,
                    # developer/portfolio constants
```

### Device smoke test

The final release APK was installed and launched successfully on a Pixel 7 Pro running Android 17 (API 37). The Flutter engine, audio service and Android media session started without a crash. The device was locked, so the interactive library/playback flows below still need to be exercised after unlocking.

### Manual test checklist

Use a real device and a library of mixed formats. The following flows form the device acceptance checklist; run them on a real device before publishing:

1. First launch → welcome screen → media permission → automatic scan.
2. Permission denial and permanently-denied → Settings shortcut.
3. Library appears with title, artist, album, duration and artwork.
4. Songs / Albums / Artists / Genres / Folders browsing and sorting.
5. Search by title, artist, album, genre and file name; clear + history.
6. Tap a song → mini-player appears and playback starts.
7. Now Playing: play/pause, seek, next/previous, shuffle, repeat off/all/one.
8. Queue: open, jump, reorder, remove, add-next.
9. Favorite toggle persists across restart.
10. Multi-select: play, queue, add to playlist, favorite.
11. Create/rename/delete playlist; add/remove/reorder songs; shuffle; persistence after restart.
12. Folder exclusion removes songs; include + rescan restores them.
13. Background playback while minimizing, locking the screen and switching apps.
14. Media notification, lock-screen controls and Bluetooth/headset buttons.
15. Headphone unplug pauses playback.
16. Incoming call/audio focus interruption pauses and resumes appropriately.
17. Equalizer: enable, preset change, band change, bass/treble/loudness, reset, saved preset, persistence.
18. Theme switching (system/light/dark), AMOLED surfaces, persistence.
19. Lyrics: adjacent `.lrc`, plain `.txt`, manual picker, synced highlight, tapping a line.
20. Video: permission flow, grid thumbnails, play, seek, speed, aspect, subtitles, brightness/volume gestures, resume position.
21. Sleep timer (duration and end-of-track).
22. Backup export → change data → restore → merge report.
23. Kill and restart app: queue, song, position, playlists, favorites and settings restored.
24. Remove/rename a media file externally, rescan: no crash, stale rows cleaned up.
25. Large library (5,000+ songs): scrolling, search and playback stay responsive.

---

## Known limitations

- **Embedded lyrics**: Android does not expose ID3 `USLT`/`SYLT` through public metadata APIs. JPlayer supports adjacent `.lrc`/`.txt` and manual files.
- **Audio codecs** (WMA, ALAC, etc.) depend on the device's decoders; unsupported files are reported and skipped.
- **Video codecs** (MKV/AVI) depend on the device decoder; local container support is not guaranteed.
- **Equalizer availability** is device-specific. Some OEMs do not expose `AudioEffect` sessions; JPlayer reports this instead of faking it.
- **Folder selection** is exclusion-based over MediaStore rather than importing arbitrary SAF trees. MediaStore already covers internal storage, SD cards and user media folders while respecting scoped storage.
- **Release signing**: the repository's release build is signed with the debug key for installability. Configure your own keystore for distribution.
- The app targets Android 7.0+ (minSdk 24).

---

## Definition of done

- [x] App launches with a branded splash and onboarding.
- [x] Media permission flow (Android 13+ and legacy).
- [x] Automatic MediaStore discovery + manual rescan + folder exclusions.
- [x] Metadata, artwork and all five browse categories.
- [x] Playback with queue, shuffle, repeat, seek, resume and background service.
- [x] Media notification, lock-screen/Bluetooth/headset controls, audio focus and unplug handling.
- [x] Persistent favorites, playlists, history and queue (SQLite).
- [x] Search across title, artist, album, genre and file name.
- [x] Now Playing with palette artwork, transitions, queue, lyrics and equalizer shortcuts.
- [x] Real Android equalizer with presets and custom curves.
- [x] Lyrics via `.lrc`/`.txt` and manual selection.
- [x] Local video playback (secondary feature).
- [x] Themed light/dark/AMOLED UI with no hardcoded widget colours.
- [x] Sleep timer, backup/restore, privacy and about.
- [x] No ads, accounts or analytics; no INTERNET permission in the release APK.
- [x] `flutter analyze` clean, 11 unit tests passing, debug and release APKs built.

**Artifacts**: `build/app/outputs/flutter-apk/app-debug.apk` and `app-release.apk`.
