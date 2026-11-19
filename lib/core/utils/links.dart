import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Small wrappers around the platform browser launcher.
class AppLinks {
  const AppLinks._();

  /// Opens [url] in the user's browser. No network permission is needed: the
  /// browser app performs the request.
  static Future<void> openExternal(BuildContext context, String url) async {
    try {
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    } catch (_) {
      // Fall through to the friendly message below.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open this link.')));
  }
}
