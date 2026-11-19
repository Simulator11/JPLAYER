import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:jplayer/app/theme/colors.dart';
import 'package:jplayer/core/constants/app_constants.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  test('brand palette is blue and readable on every theme', () {
    for (final palette in [
      JPlayerPalette.light,
      JPlayerPalette.dark,
      JPlayerPalette.amoled,
    ]) {
      expect(palette.accent.b, greaterThan(palette.accent.r));
      expect(palette.accent.b, greaterThan(palette.accent.g));
      expect(
        _contrast(palette.accent, palette.onAccent),
        greaterThanOrEqualTo(4.5),
        reason: 'Accent text/icons must be readable in both themes',
      );
    }

    expect(
      JPlayerPalette.light.background.b,
      greaterThan(JPlayerPalette.light.background.r),
    );
    expect(
      JPlayerPalette.dark.background.b,
      greaterThan(JPlayerPalette.dark.background.r),
    );
  });

  test('developer details include the portfolio', () {
    expect(AppConstants.developerName, isNotEmpty);
    expect(AppConstants.portfolioUrl, 'https://japhsamsimulator.me.tz');
    expect(AppConstants.portfolioLabel, 'japhsamsimulator.me.tz');
  });
}
