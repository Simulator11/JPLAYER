import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/app_settings.dart';
import '../features/settings/providers/settings_providers.dart';
import 'startup_gate.dart';
import 'theme/app_theme.dart';

class JPlayerApp extends ConsumerWidget {
  const JPlayerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp(
      title: 'JPlayer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(amoled: settings.amoled),
      themeMode: switch (settings.theme) {
        ThemeSetting.system => ThemeMode.system,
        ThemeSetting.light => ThemeMode.light,
        ThemeSetting.dark => ThemeMode.dark,
      },
      home: const StartupGate(),
    );
  }
}
