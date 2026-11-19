import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:material_color_utilities/material_color_utilities.dart';

import '../../app/theme/colors.dart';

/// A small set of colours derived from album artwork.
class ArtworkPalette {
  const ArtworkPalette({required this.primary, required this.secondary});

  final Color primary;
  final Color secondary;

  static const ArtworkPalette fallback = ArtworkPalette(
    primary: AppColors.primaryAccent,
    secondary: AppColors.secondaryAccent,
  );

  Color get gradientTop => Color.alphaBlend(
    primary.withValues(alpha: 0.32),
    const Color(0xFF121212),
  );

  Color get gradientBottom => const Color(0xFF0C0C0C);
}

/// Extracts a dominant accent colour from a local artwork file using
/// material_color_utilities' Celebi quantizer.
class ArtworkColorExtractor {
  const ArtworkColorExtractor._();

  static final Map<String, Future<ArtworkPalette>> _cache = {};

  static Future<ArtworkPalette> fromFile(String? path) {
    if (path == null || path.isEmpty) {
      return Future.value(ArtworkPalette.fallback);
    }
    return _cache.putIfAbsent(path, () => _extract(path));
  }

  static Future<ArtworkPalette> _extract(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return ArtworkPalette.fallback;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return ArtworkPalette.fallback;

      final pixels = <int>[];
      final bytesView = data.buffer.asUint8List();
      for (var i = 0; i + 3 < bytesView.length; i += 4) {
        final r = bytesView[i];
        final g = bytesView[i + 1];
        final b = bytesView[i + 2];
        final a = bytesView[i + 3];
        if (a < 160) continue;
        pixels.add((a << 24) | (r << 16) | (g << 8) | b);
      }
      if (pixels.isEmpty) return ArtworkPalette.fallback;

      final result = await QuantizerCelebi().quantize(pixels, 8);
      int? best;
      var bestScore = -1.0;
      final total = pixels.length;
      result.colorToCount.forEach((argb, count) {
        final color = Color(argb);
        final hsl = HSLColor.fromColor(color);
        if (hsl.lightness < 0.10 || hsl.lightness > 0.92) return;
        final chroma = hsl.saturation;
        final balancedLightness = 1 - (hsl.lightness - 0.5).abs() * 1.2;
        final score = chroma * balancedLightness * (1 + count / total);
        if (score > bestScore) {
          bestScore = score;
          best = argb;
        }
      });

      final bestArgb = best;
      if (bestArgb == null) return ArtworkPalette.fallback;
      final primary = Color(bestArgb);
      final hsl = HSLColor.fromColor(primary);
      final secondary = hsl
          .withHue((hsl.hue + 28) % 360)
          .withLightness((hsl.lightness + 0.12).clamp(0.35, 0.72).toDouble())
          .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0).toDouble())
          .toColor();
      return ArtworkPalette(primary: primary, secondary: secondary);
    } catch (_) {
      return ArtworkPalette.fallback;
    }
  }
}
