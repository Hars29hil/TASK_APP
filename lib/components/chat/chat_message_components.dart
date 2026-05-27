import 'package:flutter/material.dart';
import '../../models/chat_models.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

// 3.5 DateDivider
class DateDivider extends StatelessWidget {
  final DateTime date;
  
  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: AppColors.surfaceGrey)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _formatDate(date).toUpperCase(),
              style: AppTypography.textXs.copyWith(
                fontFamily: 'Syne',
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: AppColors.surfaceGrey)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Yesterday';
    }
    // Mock simple formatting
    return '${date.month}/${date.day}/${date.year}';
  }
}

// 3.6 & 3.7 MessageRow & Group
class MessageRow extends StatelessWidget {
  final Message message;
  final User user;
  final bool isMine;
  final bool showAvatar;

  const MessageRow({
    super.key,
    required this.message,
    required this.user,
    required this.isMine,
    required this.showAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            if (showAvatar)
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.blueDim,
                child: Text(
                  user.name.isNotEmpty ? user.name[0] : '?',
                  style: AppTypography.textXs.copyWith(
                    fontFamily: 'Syne',
                    fontWeight: FontWeight.w700,
                    color: AppColors.electricBlue,
                  ),
                ),
              )
            else
              const SizedBox(width: 26),
            const SizedBox(width: 8),
          ],
          
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine && showAvatar) // Sender Label
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 3),
                    child: Text(
                      user.name.toUpperCase(),
                      style: AppTypography.textXs.copyWith(
                        fontFamily: 'Syne',
                        fontWeight: FontWeight.w700,
                        color: AppColors.textTertiary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                
                // Bubble logic
                _buildBubble(),
                
                // Reactions
                if (message.reactions.isNotEmpty)
                  ReactionRow(reactions: message.reactions),
                
                // Timestamp
                if (showAvatar || isMine) // Show timestamp on last msg of group
                  Padding(
                    padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: AppTypography.textXs.copyWith(
                            fontFamily: 'Syne',
                            fontWeight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (isMine && message.isRead)
                          Text(
                            ' ✓✓',
                            style: AppTypography.textXs.copyWith(
                              fontFamily: 'Syne',
                              fontWeight: FontWeight.w700,
                              color: AppColors.electricBlue,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildBubble() {
    if (message.type == 'system') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.warmWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.surfaceGrey),
        ),
        child: Text(
          message.text,
          style: AppTypography.textXs.copyWith(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    if (message.type == 'status') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.emeraldDim,
          borderRadius: AppRadius.borderMd,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.statusData?['title'] ?? 'Status updated',
                  style: AppTypography.textXs.copyWith(color: AppColors.emerald, fontWeight: FontWeight.w600),
                ),
                if (message.statusData?['subtitle'] != null)
                  Text(
                    message.statusData!['subtitle'],
                    style: AppTypography.textXs.copyWith(color: AppColors.emerald.withValues(alpha: 0.7)),
                  ),
              ],
            )
          ],
        ),
      );
    }

    if (message.attachments.isNotEmpty) {
      // Mock File Attachment Bubble
      final file = message.attachments.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: AppRadius.borderMd),
              child: const Center(child: Text('📎')),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: AppTypography.textXs.copyWith(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: AppColors.ink)),
                Text('${(file.size / 1024 / 1024).toStringAsFixed(1)} MB', style: AppTypography.textXs.copyWith(color: AppColors.textTertiary)),
              ],
            )
          ],
        ),
      );
    }

    // Default text bubble
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMine ? AppColors.electricBlue : AppColors.surfaceWhite,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isMine ? 16 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 16),
        ),
        boxShadow: isMine ? null : AppShadows.soft,
      ),
      child: Text(
        message.text,
        style: AppTypography.textSm.copyWith(
          color: isMine ? Colors.white : AppColors.ink,
          height: 1.5,
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// 3.10 ReactionRow
class ReactionRow extends StatelessWidget {
  final List<MessageReaction> reactions;
  const ReactionRow({super.key, required this.reactions});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.map((r) {
          final isMine = r.users.contains('me'); // mock
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isMine ? AppColors.blueDim : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isMine ? AppColors.electricBlue : AppColors.surfaceGrey),
              boxShadow: AppShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(r.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 3),
                Text(
                  r.users.length.toString(),
                  style: AppTypography.textXs.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// 3.12 TypingIndicator
class TypingIndicator extends StatefulWidget {
  final User user;
  const TypingIndicator({super.key, required this.user});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.blueDim,
            child: Text(
              widget.user.name.isNotEmpty ? widget.user.name[0] : '?',
              style: AppTypography.textXs.copyWith(
                fontFamily: 'Syne',
                fontWeight: FontWeight.w700,
                color: AppColors.electricBlue,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 3),
                _buildDot(0.2),
                const SizedBox(width: 3),
                _buildDot(0.4),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${widget.user.name} typing...',
            style: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
          )
        ],
      ),
    );
  }

  Widget _buildDot(double delay) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Simple mock of td animation
        final progress = (_ctrl.value - delay) % 1.0;
        final scale = progress > 0 && progress < 0.4 ? 1.3 : 1.0;
        final opacity = progress > 0 && progress < 0.4 ? 1.0 : 0.4;
        
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(color: AppColors.textTertiary, shape: BoxShape.circle),
            ),
          ),
        );
      },
    );
  }
}
