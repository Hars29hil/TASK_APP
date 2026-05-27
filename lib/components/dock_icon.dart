import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class DockIcon extends StatefulWidget {
  final IconData icon;
  final bool isActive;
  final String tooltip;
  final VoidCallback onTap;

  const DockIcon({
    super.key,
    required this.icon,
    this.isActive = false,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<DockIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: widget.tooltip,
          textStyle: AppTypography.labelSmall.copyWith(color: Colors.white),
          decoration: BoxDecoration(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(6),
          ),
          preferBelow: false,
          verticalOffset: 24,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isActive
                  ? AppColors.electricBlue
                  : _isHovered
                      ? AppColors.surfaceGrey
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: widget.isActive ? AppShadows.glow(AppColors.electricBlue) : [],
            ),
            child: Icon(
              widget.icon,
              size: 24,
              color: widget.isActive
                  ? Colors.white
                  : _isHovered
                      ? AppColors.ink
                      : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
