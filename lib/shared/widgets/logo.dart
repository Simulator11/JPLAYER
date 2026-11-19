import 'package:material_ui/material_ui.dart';

import '../../app/theme/colors.dart';

/// JPlayer's app mark: a light-blue play disc on a rounded tile.
class JPLogo extends StatelessWidget {
  const JPLogo({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: context.palette.accentGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: context.palette.accent.withValues(alpha: 0.25),
            blurRadius: size * 0.35,
            offset: Offset(0, size * 0.1),
          ),
        ],
      ),
      child: Icon(
        Icons.play_arrow_rounded,
        color: context.palette.onAccent,
        size: size * 0.62,
      ),
    );
  }
}

class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        JPLogo(size: compact ? 30 : 36),
        SizedBox(width: compact ? 8 : 10),
        Text(
          'JPlayer',
          style: TextStyle(
            fontSize: compact ? 19 : 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: palette.textPrimary,
          ),
        ),
      ],
    );
  }
}
