import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class BadgeChip extends StatelessWidget {
  final String status;
  final bool compact;

  const BadgeChip({
    super.key,
    required this.status,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'ready':
        bgColor = AppColors.electricBlue.withValues(alpha: 0.1);
        textColor = AppColors.electricBlue;
        label = 'Ready';
        break;
      case 'in_progress':
      case 'active':
        bgColor = AppColors.electricBlue.withValues(alpha: 0.1);
        textColor = AppColors.electricBlue;
        label = 'In Progress';
        break;
      case 'waiting_approval':
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        label = 'Waiting';
        break;
      case 'blocked':
        bgColor = AppColors.warning.withValues(alpha: 0.1);
        textColor = AppColors.warning;
        label = 'Blocked';
        break;
      case 'completed':
        bgColor = AppColors.emerald.withValues(alpha: 0.1);
        textColor = AppColors.emerald;
        label = 'Completed';
        break;
      case 'extended':
        bgColor = AppColors.highlight.withValues(alpha: 0.1);
        textColor = AppColors.highlight;
        label = 'Extended';
        break;
      case 'pending':
      default:
        bgColor = AppColors.surfaceGrey;
        textColor = AppColors.textSecondary;
        label = 'Pending';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 2 : 6,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(color: textColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: AppTypography.chip.copyWith(
          color: textColor,
          fontSize: compact ? 10 : 12,
        ),
      ),
    );
  }
}

class PriorityChip extends StatelessWidget {
  final String priority;

  const PriorityChip({
    super.key,
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'high':
        color = AppColors.warning;
        break;
      case 'medium':
        color = AppColors.electricBlue;
        break;
      default:
        color = AppColors.emerald;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag_rounded, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          priority.toUpperCase(),
          style: AppTypography.overline.copyWith(color: color),
        ),
      ],
    );
  }
}

class RoleBadge extends StatelessWidget {
  final String role;

  const RoleBadge({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = role.toLowerCase() == 'admin';
    final isLeader = role.toLowerCase() == 'leader';

    if (!isAdmin && !isLeader) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isAdmin
            ? AppColors.highlight.withValues(alpha: 0.15)
            : AppColors.electricBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin ? Icons.shield_rounded : Icons.star_rounded,
            size: 10,
            color: isAdmin ? AppColors.highlight : AppColors.electricBlue,
          ),
          const SizedBox(width: 4),
          Text(
            role.toUpperCase(),
            style: AppTypography.chip.copyWith(
              fontSize: 9,
              color: isAdmin ? AppColors.highlight : AppColors.electricBlue,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
