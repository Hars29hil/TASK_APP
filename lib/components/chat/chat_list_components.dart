import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

// 2.2 SearchBar Component
class ChatSearchBar extends StatelessWidget {
  final String placeholder;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const ChatSearchBar({
    super.key,
    required this.placeholder,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), // Tweak vertical padding to center better
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: AppRadius.borderLg,
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 14, color: AppColors.ink.withValues(alpha: 0.4)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTypography.textXs.copyWith(color: AppColors.ink),
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// 2.3 ProjectChatCard Component
class ProjectChatCard extends StatelessWidget {
  final ChatListItem item;
  final VoidCallback onTap;

  const ProjectChatCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine colors based on stage status
    Color badgeBg;
    Color badgeText;
    String badgeIcon;

    switch (item.stageStatus) {
      case 'active':
        badgeBg = AppColors.blueDim;
        badgeText = AppColors.electricBlue;
        badgeIcon = '⚡';
        break;
      case 'testing':
        badgeBg = AppColors.purpleDim;
        badgeText = AppColors.highlight;
        badgeIcon = '🧪';
        break;
      case 'done':
        badgeBg = AppColors.emeraldDim;
        badgeText = AppColors.emerald;
        badgeIcon = '✓';
        break;
      default:
        badgeBg = AppColors.surfaceGrey;
        badgeText = AppColors.textSecondary;
        badgeIcon = '•';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(0, 0, 12, 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18), // radius-xl
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP ROW
            Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.blueDim, // Use project-branded color later
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Center(
                    child: Text(item.emoji ?? '🚀', style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(width: 12),
                // Metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.h3.copyWith(fontSize: 14, fontFamily: 'Syne', fontWeight: FontWeight.w800, color: AppColors.ink),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      if (item.currentStage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$badgeIcon ${item.currentStage}'.toUpperCase(),
                            style: AppTypography.textXs.copyWith(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w700,
                              color: badgeText,
                              fontSize: 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Right
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(item.lastMessage?.timestamp),
                      style: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
                    ),
                    const SizedBox(height: 4),
                    if (item.unreadCount > 0)
                      Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          color: AppColors.electricBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            item.unreadCount.toString(),
                            style: AppTypography.textXs.copyWith(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // MIDDLE ROW
            RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: AppTypography.textSm.copyWith(color: AppColors.textSecondary, height: 1.5),
                children: [
                  if (item.lastMessage?.authorName.isNotEmpty == true)
                    TextSpan(
                      text: '${item.lastMessage!.authorName}: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  TextSpan(text: item.lastMessage?.text ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // BOTTOM ROW
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Mock members
                    SizedBox(
                      height: 22,
                      width: 60,
                      child: Stack(
                        children: [
                          Positioned(left: 0, child: _buildMiniAvatar('A', Colors.purple)),
                          Positioned(left: 16, child: _buildMiniAvatar('B', Colors.green)),
                          Positioned(left: 32, child: _buildMiniAvatar('C', Colors.blue)),
                        ],
                      ),
                    ),
                    Text('+2', style: AppTypography.textXs.copyWith(color: AppColors.textTertiary)),
                  ],
                ),
                Text('${item.messageCount} msgs', style: AppTypography.textXs.copyWith(color: AppColors.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniAvatar(String initial, Color color) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}'; // Simple mock
  }
}

// 2.4 DMRow Component
class DMRow extends StatelessWidget {
  final ChatListItem item;
  final VoidCallback onTap;

  const DMRow({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 0, 12, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14), // radius-lg
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.blueDim, // brand color
                  child: Text(
                    item.name.isNotEmpty ? item.name[0].toUpperCase() : '?',
                    style: AppTypography.textSm.copyWith(
                      fontFamily: 'Syne',
                      fontWeight: FontWeight.w700,
                      color: AppColors.electricBlue,
                    ),
                  ),
                ),
                if (item.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: AppTypography.textSm.copyWith(
                      fontFamily: 'Syne',
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.lastMessage?.text ?? '',
                    style: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatTime(item.lastMessage?.timestamp),
                  style: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
                ),
                const SizedBox(height: 4),
                if (item.unreadCount > 0)
                  Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.electricBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

// 2.5 Section Label
class ChatSectionLabel extends StatelessWidget {
  final String label;

  const ChatSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        label,
        style: AppTypography.textXs.copyWith(
          fontFamily: 'Syne',
          fontWeight: FontWeight.w700,
          color: AppColors.textTertiary,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
