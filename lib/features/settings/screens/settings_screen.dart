import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme/colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/links.dart';
import '../../../data/models/app_settings.dart';
import '../../../shared/widgets/logo.dart';
import '../../equalizer/screens/equalizer_screen.dart';
import '../../music/providers/library_providers.dart';
import '../../player/providers/player_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/sleep_timer_sheet.dart';
import 'about_screen.dart';
import 'folder_exclusions_screen.dart';
import 'privacy_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final settings = ref.watch(settingsProvider);
    final snapshot = ref.watch(libraryProvider).value;
    final scan = ref.watch(scanStatusProvider);
    final sleep = ref.watch(sleepTimerProvider);
    final excluded =
        ref.watch(excludedFoldersProvider).value ?? const <String>[];
    final isDarkNow =
        settings.theme == ThemeSetting.dark ||
        (settings.theme == ThemeSetting.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const _SectionLabel('Appearance'),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Theme',
            subtitle: settings.theme.label,
            onTap: () => _pickTheme(context, ref),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: _IconBox(
              icon: Icons.contrast_rounded,
              color: palette.textSecondary,
            ),
            title: const Text('AMOLED black'),
            subtitle: Text(
              isDarkNow
                  ? 'Pure black surfaces for OLED screens'
                  : 'Dark mode only',
            ),
            value: settings.amoled,
            onChanged: isDarkNow
                ? (value) =>
                      ref.read(settingsProvider.notifier).setAmoled(value)
                : null,
          ),
          const _SectionLabel('Audio'),
          _SettingsTile(
            icon: Icons.equalizer_rounded,
            title: 'Equalizer',
            subtitle: settings.equalizerEnabled
                ? '${settings.equalizerPreset} · On'
                : 'Off',
            onTap: () => AppRoutes.push(context, const EqualizerScreen()),
          ),
          _SettingsTile(
            icon: Icons.headphones_outlined,
            title: 'Audio focus & headphones',
            subtitle: 'Pauses for calls, unplugging and other apps',
            onTap: () => _showFocusInfo(context),
          ),
          const _SectionLabel('Playback'),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: _IconBox(
              icon: Icons.history_rounded,
              color: palette.textSecondary,
            ),
            title: const Text('Resume last session'),
            subtitle: const Text('Continue the last song where you left off'),
            value: settings.resumeLastSession,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setResumeLastSession(value),
          ),
          _SettingsTile(
            icon: Icons.bedtime_outlined,
            title: 'Sleep timer',
            subtitle: sleep.active
                ? sleep.endOfTrack
                      ? 'Pauses at end of track'
                      : 'Pausing in ${Formatters.duration(sleep.remaining)}'
                : 'Off',
            onTap: () => showSleepTimerSheet(context),
          ),
          const _SectionLabel('Library'),
          _SettingsTile(
            icon: Icons.sync_rounded,
            title: 'Scan music',
            subtitle: scan.isBusy
                ? (scan.message ?? 'Scanning…')
                : '${Formatters.songCount(snapshot?.songs.length ?? 0)} · '
                      '${Formatters.timeAgo(snapshot?.lastScanAt)}',
            trailing: scan.isBusy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: scan.isBusy ? null : () => _scan(context, ref),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            secondary: _IconBox(
              icon: Icons.restart_alt_rounded,
              color: palette.textSecondary,
            ),
            title: const Text('Scan on launch'),
            subtitle: const Text(
              'Keeps the library fresh without a manual scan',
            ),
            value: settings.scanOnLaunch,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setScanOnLaunch(value),
          ),
          _SettingsTile(
            icon: Icons.folder_off_outlined,
            title: 'Folder exclusions',
            subtitle: excluded.isEmpty
                ? 'No folders excluded'
                : '${Formatters.count(excluded.length, 'folder')} excluded',
            onTap: () async {
              await AppRoutes.push(context, const FolderExclusionsScreen());
              if (!context.mounted) return;
              await ref.read(libraryProvider.notifier).refresh();
              ref.invalidate(excludedFoldersProvider);
            },
          ),
          const _SectionLabel('Data'),
          _SettingsTile(
            icon: Icons.cloud_off_rounded,
            title: 'Backup & restore',
            subtitle: 'Playlists, favorites and preferences as a local file',
            onTap: () => _showBackupSheet(context, ref),
          ),
          const _SectionLabel('About'),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            subtitle: 'How JPlayer handles your local media',
            onTap: () => AppRoutes.push(context, const PrivacyScreen()),
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About JPlayer',
            subtitle: 'Version ${AppConstants.version}',
            onTap: () => AppRoutes.push(context, const AboutScreen()),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                const JPLogo(size: 34),
                const SizedBox(height: 8),
                Text(
                  AppConstants.slogan,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Developed by ${AppConstants.developerName}',
                  style: Theme.of(context).textTheme.labelSmall
                      ?.copyWith(color: palette.textSecondary),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () =>
                      AppLinks.openExternal(context, AppConstants.portfolioUrl),
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text(AppConstants.portfolioLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _pickTheme(BuildContext context, WidgetRef ref) async {
    final current = ref.read(settingsProvider).theme;
    final selected = await showModalBottomSheet<ThemeSetting>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text('Theme', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            for (final mode in ThemeSetting.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                leading: Icon(_themeIcon(mode)),
                title: Text(mode.label),
                trailing: mode == current
                    ? Icon(Icons.check_rounded, color: context.palette.accent)
                    : null,
                onTap: () => Navigator.of(context).pop(mode),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(settingsProvider.notifier).setTheme(selected);
    }
  }

  IconData _themeIcon(ThemeSetting mode) => switch (mode) {
    ThemeSetting.system => Icons.brightness_auto_rounded,
    ThemeSetting.light => Icons.light_mode_rounded,
    ThemeSetting.dark => Icons.dark_mode_rounded,
  };

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final outcome = await ref.read(libraryProvider.notifier).scan();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (outcome != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Library updated · ${Formatters.songCount(outcome.songs.total)}',
          ),
        ),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(ref.read(scanStatusProvider).message ?? 'Scan failed.'),
        ),
      );
    }
  }

  void _showFocusInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Audio focus'),
        content: const Text(
          'JPlayer follows Android audio rules: music pauses when you receive '
          'a call or another app takes over the audio output, resumes when '
          'appropriate, and pauses when headphones or Bluetooth headphones '
          'are disconnected.\n\nHeadset buttons, Bluetooth controls, the media '
          'notification and lock-screen controls all work while playback runs '
          'in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBackupSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Backup & restore',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Export backup'),
              subtitle: const Text(
                'Save playlists, favorites, exclusions and settings',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _exportBackup(context, ref);
              },
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.download_rounded),
              title: const Text('Restore backup'),
              subtitle: const Text(
                'Merge a JPlayer JSON backup into this library',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _restoreBackup(context, ref);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                'Backups are written only where you choose. JPlayer never '
                'uploads your files.',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(backupServiceProvider).exportJson();
      final now = DateTime.now();
      final date =
          '${now.year}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Save JPlayer backup',
        fileName: 'jplayer-backup-$date.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
      );
      if (saved != null) {
        messenger.showSnackBar(const SnackBar(content: Text('Backup saved')));
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not export backup: $error')),
      );
    }
  }

  Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose JPlayer backup',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;

      String content;
      try {
        content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      } catch (_) {
        messenger.showSnackBar(
          const SnackBar(content: Text('That file could not be read.')),
        );
        return;
      }
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore backup?'),
          content: const Text(
            'Playlists and favorites will be merged into this library. '
            'Settings and folder exclusions from the backup will be applied.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Restore'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final result = await ref.read(backupServiceProvider).restoreJson(content);
      await ref.read(settingsProvider.notifier).reload();
      await ref.read(libraryProvider.notifier).refresh();
      ref.invalidate(favoritesProvider);
      ref.invalidate(playlistsProvider);
      ref.invalidate(smartCountsProvider);
      ref.invalidate(excludedFoldersProvider);

      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Backup restored'),
          content: Text(
            '${result.playlistsRestored} playlists and '
            '${result.favoritesRestored} favorites restored.\n\n'
            '${result.songsMissing} song references were not found on this '
            'device. Run "Scan music" to refresh the library and apply any '
            'folder exclusions from the backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on FormatException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $error')));
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 22, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: _IconBox(icon: icon, color: palette.textSecondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing:
          trailing ??
          Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
      onTap: onTap,
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
