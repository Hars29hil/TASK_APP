import 'package:flutter/material.dart';
import '../../models/project.dart'; // For Project/Stage
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

class ChatTopbar extends StatelessWidget {
  final bool isProject;
  final String title;
  final int memberCount;
  final int messageCount;
  final VoidCallback onBackPressed;
  final VoidCallback onMorePressed;

  const ChatTopbar({
    super.key,
    this.isProject = false,
    required this.title,
    required this.memberCount,
    required this.messageCount,
    required this.onBackPressed,
    required this.onMorePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(bottom: BorderSide(color: AppColors.surfaceGrey, width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBackPressed,
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: AppRadius.borderSm,
              ),
              child: const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.ink),
            ),
          ),
          const SizedBox(width: 12),
          // Icon
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: isProject ? AppColors.blueDim : AppColors.surfaceGrey,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                isProject ? '🚀' : '💬',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTypography.textMd.copyWith(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$memberCount members · $messageCount messages',
                  style: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          // More btn
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.ink),
            onPressed: onMorePressed,
          ),
        ],
      ),
    );
  }
}

class StageBanner extends StatefulWidget {
  final Stage stage;
  final bool isActive;
  final VoidCallback onOpenStage;

  const StageBanner({
    super.key,
    required this.stage,
    required this.isActive,
    required this.onOpenStage,
  });

  @override
  State<StageBanner> createState() => _StageBannerState();
}

class _StageBannerState extends State<StageBanner> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _opacityAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _opacityAnim = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.electricBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Pulse Dot
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnim.value,
                child: Opacity(
                  opacity: _opacityAnim.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          // Text block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE STAGE',
                  style: AppTypography.textXs.copyWith(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  widget.stage.title,
                  style: AppTypography.textSm.copyWith(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          // Button
          GestureDetector(
            onTap: widget.onOpenStage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: AppRadius.borderSm,
              ),
              child: Text(
                'Open →',
                style: AppTypography.textXs.copyWith(
                  fontFamily: 'Syne',
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
