import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GradientProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final Color? startColor;
  final Color? endColor;

  const GradientProgressBar({
    super.key,
    required this.progress,
    this.height = 6,
    this.startColor,
    this.endColor,
  });

  @override
  Widget build(BuildContext context) {
    final c1 = startColor ?? AppColors.electricBlue;
    final c2 = endColor ?? AppColors.highlight;
    final bg = AppColors.surfaceGrey;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutQuint,
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [c1, c2],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: c2.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
