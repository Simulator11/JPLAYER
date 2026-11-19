# Build and Release

JPlayer is source-only in Git. Prebuilt APKs are not committed; the developer keeps installable release builds backed up separately (Google Drive) for distribution.

## Requirements

- Flutter 3.50.0 stable / Dart 3.14.0
- Android SDK platform 37 and build-tools 36
- JDK 17 (Android Studio's bundled JBR is fine)
- An Android 7.0+ device for installation

## Build commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Flutter writes the APKs to:

```text
build/app/outputs/flutter-apk/app-debug.apk
build/app/outputs/flutter-apk/app-release.apk
```

Install the release build with:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Android configuration

| Setting | Value |
| --- | --- |
| Application ID | `com.jplayer.app` |
| compileSdk | 37 |
| targetSdk | 36 |
| minSdk | 24 |
| NDK | 30.0.16248370 (pinned) |
| AGP | 9.3.1 |
| Kotlin | 2.4.20 |
| Gradle | 9.5.0 |
| Java | 17 |

The release build sets `isMinifyEnabled = false` and `isShrinkResources = false`. Source/resource shrinking is intentionally omitted while the app is in its first public preview; this keeps crash reports and local testing easier to interpret.

## Signing

`android/app/build.gradle.kts` currently uses the debug signing configuration for release builds so the APK is installable without distributing a private keystore.

Before a production/Play Store release:

1. Create a private upload keystore.
2. Add a `signingConfigs.release` block using environment variables or a local properties file.
3. Set `signingConfig = signingConfigs.getByName("release")`.
4. Never commit the keystore or its passwords.
5. Keep the same application ID and signing key for future updates.

## Permissions and privacy

- `READ_MEDIA_AUDIO` and `READ_MEDIA_VIDEO` on Android 13+
- `READ_EXTERNAL_STORAGE` with `maxSdkVersion=32`
- Foreground-service and wake-lock permissions for playback
- `POST_NOTIFICATIONS` for media notification visibility
- No `MANAGE_EXTERNAL_STORAGE`
- No `INTERNET` permission in the release APK
- `ACCESS_NETWORK_STATE` is merged by AndroidX Media3 and does not grant network access

Debug builds include `INTERNET` because the Flutter development tool uses it for hot reload/observatory; release builds do not.

## Source distribution

Git tracks source, tests and documentation only. The release APK is intentionally not committed.

1. Commit the source and documentation on `main`.
2. Push `main` to `https://github.com/Simulator11/JPLAYER.git`.
3. Build the release APK locally.
4. Keep a backup of the APK in Google Drive for distribution.
5. Record its SHA-256 when you upload the backup.

```powershell
git add .
git commit -m "Describe your change"
git push origin main
certutil -hashfile build/app/outputs/flutter-apk/app-release.apk SHA256
```

The binary is kept out of Git so the repository stays small and cloning is fast.

## Verification checklist

```bash
flutter analyze
flutter test
aapt dump badging build/app/outputs/flutter-apk/app-release.apk
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

Expected release facts:

- package `com.jplayer.app`
- versionName `1.0.0`, versionCode `1`
- minSdk 24, targetSdk 36, compileSdk 37
- no `INTERNET` permission
- debug certificate: `CN=Android Debug`
- assets: launcher/splash icons and notification icon present

Device smoke test performed: the release APK was installed and launched on a Pixel 7 Pro running Android 17. The Flutter engine, audio service and media session initialised without a fatal exception. The phone was locked, so the interactive tests in the README checklist still need to be run after unlocking.

## Low-memory build machine

The reference build machine has 3 GB RAM. `android/gradle.properties` therefore caps Gradle at:

```properties
org.gradle.jvmargs=-Xmx1280m -XX:MaxMetaspaceSize=512m -XX:ReservedCodeCacheSize=192m
org.gradle.daemon=false
org.gradle.parallel=false
org.gradle.workers.max=1
kotlin.daemon.jvmargs=-Xmx768m
```

On a larger workstation, raising the heap and enabling the daemon/parallel workers will make builds faster.
