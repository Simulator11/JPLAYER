import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/colors.dart';
import '../../../core/utils/formatters.dart';
import '../../player/providers/player_providers.dart';

Future<void> showSleepTimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const SleepTimerSheet(),
  );
}

class SleepTimerSheet extends ConsumerWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final timer = ref.watch(sleepTimerProvider);
    final controller = ref.read(sleepTimerProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    void start(int minutes) {
      controller.start(Duration(minutes: minutes));
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Sleep timer set for $minutes minutes')),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sleep timer', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              timer.active
                  ? timer.endOfTrack
                        ? 'Playback will pause at the end of this track.'
                        : 'Pausing in ${Formatters.duration(timer.remaining)}.'
                  : 'Pause JPlayer automatically so you can drift off.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: palette.textSecondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final minutes in const [10, 15, 30, 45, 60, 90])
                  ActionChip(
                    avatar: Icon(
                      Icons.timer_outlined,
                      size: 18,
                      color: palette.accent,
                    ),
                    label: Text('$minutes min'),
                    onPressed: () => start(minutes),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.music_note_rounded,
                color: palette.textPrimary,
              ),
              title: const Text('End of current track'),
              subtitle: Text(
                'Finish the song, then pause',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onTap: () {
                controller.stopAtEndOfTrack();
                Navigator.of(context).pop();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('JPlayer will pause after this track'),
                  ),
                );
              },
            ),
            if (timer.active) ...[
              Divider(color: palette.divider),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.timer_off_outlined, color: palette.accent),
                title: const Text('Turn off sleep timer'),
                onTap: () {
                  controller.cancel();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
