import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/library_models.dart';
import '../../../shared/widgets/common.dart';
import '../../music/providers/library_providers.dart';

class FolderExclusionsScreen extends ConsumerWidget {
  const FolderExclusionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final excludedAsync = ref.watch(excludedFoldersProvider);
    final excluded = excludedAsync.value ?? const <String>[];
    final snapshot = ref.watch(libraryProvider).value;

    void message(String text, {SnackBarAction? action}) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(text), action: action));
    }

    Future<void> include(String path) async {
      await ref.read(musicRepositoryProvider).includeFolder(path);
      ref.invalidate(excludedFoldersProvider);
      await ref.read(libraryProvider.notifier).refresh();
      message(
        'Folder included. Rescan to bring its songs back.',
        action: SnackBarAction(
          label: 'Rescan',
          onPressed: () => ref.read(libraryProvider.notifier).scan(),
        ),
      );
    }

    Future<void> exclude(MusicFolder folder) async {
      await ref.read(musicRepositoryProvider).excludeFolder(folder.path);
      ref.invalidate(excludedFoldersProvider);
      await ref.read(libraryProvider.notifier).refresh();
      message('"${folder.displayName}" excluded from JPlayer');
    }

    Future<void> addFolder() async {
      final available = [
        for (final folder in snapshot?.folders ?? const <MusicFolder>[])
          if (folder.path.isNotEmpty &&
              !excluded.any(
                (path) => path.toLowerCase() == folder.path.toLowerCase(),
              ))
            folder,
      ];
      if (available.isEmpty) {
        message('There are no other folders to exclude.');
        return;
      }
      final chosen = await showModalBottomSheet<MusicFolder>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Exclude a folder',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: available.length,
                    itemBuilder: (context, index) {
                      final folder = available[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                        ),
                        leading: Icon(
                          Icons.folder_outlined,
                          color: palette.accent,
                        ),
                        title: Text(folder.displayName),
                        subtitle: Text(
                          folder.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          Formatters.songCount(folder.songCount),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        onTap: () => Navigator.of(context).pop(folder),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      if (chosen != null) await exclude(chosen);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Folder exclusions'),
        actions: [
          IconButton(
            tooltip: 'Add folder',
            onPressed: addFolder,
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Rescan music',
            onPressed: () => ref.read(libraryProvider.notifier).scan(),
            icon: const Icon(Icons.sync_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: excludedAsync.isLoading && excluded.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : excluded.isEmpty
          ? EmptyState(
              icon: Icons.folder_off_outlined,
              title: 'No excluded folders',
              message:
                  'Hide ringtones, voice notes or folders you do not want '
                  'in your music library. Excluded folders are skipped '
                  'while scanning.',
              actionLabel: 'Choose a folder',
              onAction: addFolder,
            )
          : _ExclusionsList(excluded: excluded, onInclude: include),
    );
  }
}

class _ExclusionsList extends StatelessWidget {
  const _ExclusionsList({required this.excluded, required this.onInclude});

  final List<String> excluded;
  final ValueChanged<String> onInclude;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 20, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Excluded folders are skipped during scans. Their songs are '
                  'removed from JPlayer until you include the folder again and '
                  'rescan.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final path in excluded)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: palette.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.folder_off_outlined,
                color: palette.textSecondary,
              ),
            ),
            title: Text(
              path.split('/').last,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: TextButton(
              onPressed: () => onInclude(path),
              child: const Text('Include'),
            ),
          ),
      ],
    );
  }
}
