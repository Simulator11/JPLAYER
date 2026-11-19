# JPlayer Architecture

JPlayer is a Flutter Android app that plays media already on the device. The architecture deliberately separates **platform discovery**, **local persistence**, **playback**, and **presentation** so a slow MediaStore scan or a background audio event never blocks the UI.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Flutter UI (Material 3 / Riverpod)                                   │
│ Home · Music · Playlists · Settings · Now Playing · Videos · Search  │
└───────────────┬───────────────────────────────┬──────────────────────┘
                │ watches providers              │ user actions
┌───────────────▼────────────────┐   ┌──────────▼──────────────────────┐
│ Riverpod controllers           │   │ JPlayerAudioHandler             │
│ library, favorites, playlists  │   │ just_audio + audio_service      │
│ settings, equalizer, sleep     │   │ media session / notification    │
└───────┬────────────────┬───────┘   └──────────┬──────────────────────┘
        │                │                      │
┌───────▼──────┐  ┌──────▼────────────┐  ┌──────▼──────────────────────┐
│ Repositories │  │ Services          │  │ Android audio effects       │
│ music        │  │ scanner, artwork  │  │ AndroidEqualizer            │
│ playlists    │  │ lyrics, backup    │  │ LoudnessEnhancer            │
│ settings     │  │ permissions, links│  └─────────────────────────────┘
└───────┬──────┘  └──────┬────────────┘
        │                │ MethodChannel
┌───────▼──────┐  ┌──────▼─────────────────────────────────────────────┐
│ SQLite       │  │ MediaChannel.kt (MainActivity's FlutterEngine)      │
│ sqflite      │  │ MediaStore audio/genres/video · artwork · thumbnails│
└──────────────┘  └────────────────────────────────────────────────────┘
```

## 1. Startup

1. `main()` initialises Flutter bindings and edge-to-edge system UI.
2. `AppDatabase.open()` opens `jplayer.db` with `PRAGMA foreign_keys = ON`.
3. Repositories are created and `SettingsRepository.loadSettings()` reads JSON preferences.
4. `JPlayerAudioHandler.init()` calls `AudioService.init` with the media notification configuration, then restores the saved queue and repeat mode.
5. The widget tree starts in a `ProviderScope` that overrides the database, initial settings and audio handler.
6. `StartupGate` shows onboarding when audio permission is missing, otherwise builds `RootShell` and schedules an automatic scan when the cache is empty or older than 24 hours.
7. Startup failures are caught and rendered by a small fallback app instead of leaving a blank screen.

## 2. Permissions

`PermissionService` resolves the Android SDK through the native channel:

- API 33+: `Permission.audio` (`READ_MEDIA_AUDIO`), optional `Permission.videos` (`READ_MEDIA_VIDEO`).
- API ≤32: `Permission.storage` (`READ_EXTERNAL_STORAGE`, limited by manifest `maxSdkVersion=32`).
- Android 13+ notification permission is requested after audio access.
- Denial returns control to the Welcome screen; permanently denied offers an Android Settings shortcut.
- Video access is requested only when the user opens Videos. A denied/absent video permission never blocks music.

The manifest does not request `MANAGE_EXTERNAL_STORAGE`. JPlayer reads indexed media only. Release builds remove `INTERNET`; `ACCESS_NETWORK_STATE` comes from AndroidX Media3 and grants no data access.

## 3. Media discovery and scanning

### Native side

`com.jplayer.app.media.MediaChannel` is registered on the activity's Flutter engine and handles:

| Method | Work |
| --- | --- |
| `querySongs` | Queries `MediaStore.Audio.Media` across `VOLUME_EXTERNAL`, including ID, title, artist/artist ID, album/album ID, duration, size, dates, DATA, display name, track, year and relative path (API 29+). Includes music rows and audio MIME rows, ignores clips ≤1 second, and resolves one genre map per scan. |
| `queryVideos` | Queries `MediaStore.Video.Media` with title, duration, size, date, DATA, bucket, dimensions and display name. |
| `getArtwork` | Reads embedded art or album art with `MediaMetadataRetriever`, downsamples it and caches JPEGs in the app cache. |
| `getVideoThumbnail` | Extracts and caches a video frame as JPEG. |
| `scanFile` / scanner helpers | Requests a MediaScanner refresh after external changes. |
| `setScreenBrightness` | Applies the video player's brightness gesture on the activity window and resets on exit. |
| `platformInfo` | SDK, device and app metadata. |

Queries run on a three-thread executor. A null cursor is treated as a failure, not as an empty library, so a provider failure cannot wipe the cache.

### Dart side

`MediaScannerService.scan()`:

1. Calls `querySongs()`.
2. Drops system audio paths (`Ringtones`, `Notifications`, `Alarms`).
3. Drops folders in `excluded_folders` using case-insensitive prefix matching.
4. Calls `MusicRepository.syncSongs()` with progress callbacks.
5. Optionally refreshes videos. Video failure is isolated from the music result.
6. Saves `last_scan_at`, marks the scan complete and exposes counts/messages through `ScanStatusController`.

`MusicRepository.syncSongs()` runs in one transaction:

- Existing rows are loaded with `media_id`, `path` and `uri`.
- A file is reconciled by absolute path, or by content URI when `DATA` is unavailable.
- Same file → UPDATE in place, preserving the song ID and every foreign-key relationship.
- MediaStore reused an ID → UPDATE the existing row.
- New file → INSERT OR IGNORE.
- Rows absent from the scan are deleted; `ON DELETE CASCADE` cleans favorites, playlist membership, play history, play counts, queue, lyrics overrides and excluded references.
- Batches are committed every 300 rows; progress is reported to the UI.

A scan error preserves the previous snapshot and shows a friendly scan error; it never clears the library.

## 4. Database and projections

The SQLite schema is created in `app_database.dart`:

| Table | Purpose |
| --- | --- |
| `songs` | MediaStore metadata cache; primary key `media_id`, indexes on path, title, artist, album, date added and folder. |
| `favorites` | `song_id` + timestamp. |
| `playlists` / `playlist_songs` | Case-insensitive unique playlist names; ordered membership with `(playlist_id, song_id)` primary key. |
| `play_history` / `play_counts` | Timestamped plays and aggregate counts; history capped at 5,000 rows. |
| `queue` | Persisted queue positions and song IDs. |
| `settings` | JSON preferences, last queue index, last position, last scan time and lyrics paths. |
| `videos` | Video metadata and last playback position. |
| `excluded_folders` | Case-insensitive folder paths. |
| `lyrics_paths` | Per-song manual lyrics override. |
| `searches` | Recent searches, capped at 20. |
| `eq_presets` | Saved custom equalizer curves. |

All song-referencing tables use `ON DELETE CASCADE ON UPDATE CASCADE`. The database stores references and metadata only; audio files are never copied.

`LibrarySnapshot.fromSongs()` builds albums, artists, genres and folders in memory from the one cached song list. This keeps all tabs consistent, avoids four separate MediaStore queries and makes refresh cheap after a scan. Album/artist grouping uses stable IDs where available and display names as fallback.

## 5. Playback and background audio

`JPlayerAudioHandler` extends `BaseAudioHandler` and owns exactly one `just_audio` player:

- `AudioService.init` registers a media session, foreground service, notification channel and media-button receiver.
- `AudioPipeline(androidAudioEffects: [AndroidEqualizer, AndroidLoudnessEnhancer])` attaches real Android effects.
- `setAudioSources` loads the queue; `playSongs` resets current song, queue, shuffle and record state.
- `currentIndexStream` updates `mediaItem`, the current song stream, history, queue index and media session state.
- Playback state exposes previous/play/pause/next controls, compact notification actions, seek, stop and queue index.
- Shuffle uses `just_audio`'s shuffle order; repeat maps to `LoopMode.off/all/one`.
- Queue add, add-next, reorder and remove operate on both the engine and the persisted queue.
- `becomingNoisyEventStream` pauses and saves position when headphones are unplugged.
- `audio_session` is configured for music; the engine handles focus and interruptions.
- Playback errors surface through `errorStream`; `maxSkipsOnError` lets the queue skip corrupt/unavailable files.

Resume behavior:

- Queue IDs and current index are written to SQLite after queue changes.
- Position is written every 10 seconds and when pausing/stopping.
- On startup the saved queue is restored without autoplay.
- When “Resume last session” is enabled and the saved song matches, pressing play seeks to the saved position.
- Clearing the queue clears the persisted rows and media item instead of leaving stale data.

### Equalizer

`EqualizerController` reads the device's real `AndroidEqualizer` parameters. Presets are defined at ten anchor frequencies (31 Hz–16 kHz) and interpolated to the device's actual bands. Bass/treble offsets and loudness gain are applied as real effect parameters, persisted to settings. If the device exposes no effects, the UI reports that instead of showing fake sliders. Custom curves can be saved and are included in backups.

### Sleep timer

`SleepTimerController` supports a duration timer or end-of-track mode. It stops the audio handler, reports a completed state to the UI and cancels its timers when acknowledged.

## 6. Lyrics

`LyricsService` is fully local:

- Candidate order: manual override → `<song>.lrc/.LRC/.Lrc/.txt/.TXT` beside the file → sanitized title file → `lyrics/<base>.lrc`.
- LRC parser supports multiple timestamp tags per line, `[offset:]` metadata, hundredths/milliseconds and plain text fallback.
- Synced lines are binary-searched for the current playback position; tapping a line seeks.
- A manually picked file is read through the Storage Access Framework and, when it has no filesystem path, copied into the app support directory so it survives restarts.
- Embedded ID3 `USLT`/`SYLT` is not claimed because Android's public metadata API does not expose it.

## 7. Video pipeline

- `VideosScreen` requests video permission only on entry and builds a responsive grid from `MediaStore.Video`.
- Thumbnails come from native `MediaMetadataRetriever` JPEGs cached by video ID; no network thumbnails.
- `VideoPlayerScreen` uses `video_player`/Media3 with:
  - tap-to-toggle controls and play/pause,
  - seek bar and horizontal drag preview,
  - ±10 second, previous/next video,
  - 0.5×–2× speed,
  - fit/crop/stretch aspect modes,
  - vertical drag for brightness (left) or volume (right),
  - full-screen/landscape immersive mode,
  - SRT/WebVTT subtitle loading and timed overlay,
  - remembered video position.
- Unsupported codecs show an error state instead of crashing; codec support is device-dependent.

## 8. Search, playlists and smart lists

- `MusicRepository.searchSongs()` escapes `LIKE` wildcards and searches title, artist, album, genre and filename.
- Recent searches are stored in SQLite and capped at 20.
- Favorites toggles are transactional; batch favorite operations use a SQLite batch.
- Smart lists are derived from favorites/history/counts and refresh when playback starts or favorites change.
- Playlist membership is ordered; reorder rewrites positions; adding songs ignores duplicates and continues positions.
- Recently played/most played queries join the cached songs table, so removed media disappears automatically.

## 9. Backup and restore

`BackupService` exports a single JSON document:

```json
{
  "app": "JPlayer",
  "format": 1,
  "exportedAt": "...",
  "settings": { "...": "AppSettings JSON" },
  "favorites": ["/path/to/song.mp3", "content://media/..."],
  "playlists": [{ "name": "Road trip", "songs": ["/path/..."] }],
  "excludedFolders": ["Podcasts"],
  "equalizerPresets": [{ "name": "Warm", "gains": [1, 2, 0] }]
}
```

Favorites and playlists are keyed by absolute path, falling back to the content URI. On restore, current songs are indexed by both path and URI, so a backup survives MediaStore ID changes. The restore report counts matched references; settings and exclusions are applied immediately, and a rescan is recommended.

## 10. UI and design system

- Material 3 with a central `JPlayerPalette` `ThemeExtension`; widgets read `context.palette` rather than raw colors.
- Light theme: ice-blue surfaces `#F3FAFF` / `#E6F4FE`, accent `#0369A1`, accent-soft `#38BDF8`.
- Dark theme: navy `#0A1420`, cards `#15283C`, accent `#7DD3FC`.
- AMOLED: true black background with near-black blue surfaces and the same light-blue accent.
- `onAccent` supplies accessible foregrounds for buttons, play controls, switches, checkboxes and gradients.
- Typography lives in `app/theme/typography.dart`; component themes cover app bar, navigation bar, cards, inputs, dialogs, sheets, snackbars, buttons and selection controls.
- Root shell keeps four tabs alive with `IndexedStack` and shows the mini player above the navigation bar.
- Now Playing uses artwork-derived palette colors, an animated blurred backdrop and a responsive wide layout.
- Developer credit and the portfolio link live in About and the Settings footer.

## 11. Error handling and resilience

- Startup failure → fallback screen explaining that media was not changed.
- Permission denial → contextual explanation and Settings shortcut.
- Scan failure → previous library snapshot retained.
- Missing/null MediaStore cursor → exception, never a destructive empty sync.
- Playback failure → snackbar and automatic skip policy.
- Database writes are best-effort for non-critical position/history updates.
- Corrupt preference JSON falls back to defaults.
- Corrupt/unreadable lyrics/subtitles/backups show a readable error instead of crashing.
- Queue restoration catches corrupt queue data and starts cleanly.

## 12. Performance decisions

- One MediaStore query and one in-memory projection per library revision.
- SQLite indexes on title, artist, album, path, folder and date.
- Batched inserts/updates in one transaction.
- Sorted song list memoized until the library list identity or sort mode changes.
- Lazy `ListView.builder`/`GridView.builder` with constrained artwork decode sizes.
- History pruning at 5,000 rows and recent-search pruning at 20.
- Native artwork/thumbnail extraction off the UI thread with JPEG cache.
- Position persistence every 10 seconds instead of every frame.

## 13. Tests and release verification

`flutter test` covers:

1. Duration formatting.
2. Synced LRC.
3. Plain lyrics.
4. SRT subtitles.
5. Equalizer preset interpolation.
6. Album/artist/genre/folder grouping.
7. Folder exclusion.
8. System-sound filtering.
9. Settings JSON round trip.
10. Blue palette contrast in light/dark/AMOLED.
11. Developer/portfolio constants.

`flutter analyze` is clean. Release manifest verification for `v1.0.0`: minSdk 24, targetSdk 36, compileSdk 37, no `INTERNET` permission. The release APK was installed and launched on a Pixel 7 Pro running Android 17; the device was locked, so interactive playback remains on the manual checklist in the README.

## 14. Source map

```text
lib/main.dart                          bootstrap + audio service
lib/app/                               shell, routes, themes, startup gate
lib/core/audio/                        equalizer preset math
lib/core/providers/                    repositories/services DI
lib/core/services/                     native bridge, scanner, artwork, lyrics, backup, permissions
lib/core/utils/                        formatting, external links
lib/data/database/                     SQLite schema
lib/data/models/                       songs, library projections, playlists, settings
lib/data/repositories/                 queries and transactions
lib/features/*/                        home, music, search, playlists, player,
                                       equalizer, lyrics, videos, settings, onboarding
lib/shared/widgets/                    artwork, tiles, rails, queue, mini player
android/app/src/main/kotlin/com/jplayer/app/
  MainActivity.kt                      audio-service activity + channel setup
  media/MediaChannel.kt                MediaStore/artwork/thumbnail bridge
test/                                  unit tests
tool/generate_icons.ps1                legacy launcher PNG generator
docs/                                  architecture, stack, build/release
```
