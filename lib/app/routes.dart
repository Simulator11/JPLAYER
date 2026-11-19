import 'package:material_ui/material_ui.dart';

import '../features/player/screens/now_playing_screen.dart';

/// Centralised navigation helpers. JPlayer keeps the route graph intentionally
/// small: a root shell with tabs plus pushed detail/player screens.
class AppRoutes {
  const AppRoutes._();

  static Route<T> playerRoute<T>() {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) => const NowPlayingScreen(),
      transitionsBuilder: (_, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    );
  }

  static Future<T?> push<T>(BuildContext context, Widget page) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute<T>(builder: (_) => page));
  }

  static Future<T?> pushPlayer<T>(BuildContext context) {
    return Navigator.of(context).push<T>(playerRoute<T>());
  }
}
