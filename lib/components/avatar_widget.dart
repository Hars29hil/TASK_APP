import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

/// Avatar component with initials fallback and online indicator.
class AvatarWidget extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final bool showOnline;
  final bool isOnline;

  const AvatarWidget({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 36,
    this.showOnline = false,
    this.isOnline = false,
  });

  const AvatarWidget.sm({
    super.key,
    required this.name,
    this.imageUrl,
    this.showOnline = false,
    this.isOnline = false,
  }) : size = 24;

  const AvatarWidget.lg({
    super.key,
    required this.name,
    this.imageUrl,
    this.showOnline = false,
    this.isOnline = false,
  }) : size = 48;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.electricBlue,
      AppColors.emerald,
      AppColors.highlight,
      AppColors.warning,
      AppColors.ink,
    ];
    final colorIndex = name.codeUnits.fold(0, (a, b) => a + b) % colors.length;
    final bgColor = colors[colorIndex];

    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: imageUrl == null ? bgColor : AppColors.surfaceGrey,
            shape: BoxShape.circle,
            image: imageUrl != null
                ? DecorationImage(
                    image: NetworkImage(imageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: imageUrl == null
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: AppTypography.labelLarge.copyWith(
                      color: Colors.white,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
        ),
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: isOnline ? AppColors.emerald : AppColors.surfaceGrey,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.warmWhite,
                  width: size * 0.05,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A stacked overlapping row of avatars for team visualization.
class AvatarStack extends StatelessWidget {
  final List<String?> imageUrls;
  final List<String> names;
  final double size;
  final int maxDisplay;

  const AvatarStack({
    super.key,
    required this.imageUrls,
    required this.names,
    this.size = 28,
    this.maxDisplay = 3,
  });

  @override
  Widget build(BuildContext context) {
    final displayCount = names.length > maxDisplay ? maxDisplay : names.length;
    final extraCount = names.length - displayCount;

    return SizedBox(
      height: size,
      width: size + ((displayCount - 1) * size * 0.7) + (extraCount > 0 ? size * 0.7 : 0),
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * size * 0.7,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warmWhite, width: 2),
                ),
                child: AvatarWidget(
                  name: names[i],
                  imageUrl: imageUrls[i],
                  size: size - 4, // Account for border
                ),
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: displayCount * size * 0.7,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: AppColors.surfaceGrey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.warmWhite, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: AppTypography.labelSmall.copyWith(
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
