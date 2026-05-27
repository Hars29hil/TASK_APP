import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_typography.dart';

class ChatComposer extends StatefulWidget {
  final bool isTaskThread;
  final bool isLoading;
  final String placeholder;
  final Function(String, List<dynamic>?) onSend;
  final VoidCallback? onMarkDone;
  final VoidCallback? onBlock;
  final VoidCallback? onAttach;
  
  const ChatComposer({
    super.key,
    this.isTaskThread = false,
    this.isLoading = false,
    this.placeholder = 'Type a message...',
    required this.onSend,
    this.onMarkDone,
    this.onBlock,
    this.onAttach,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text.trim();
      if (text.isNotEmpty != _canSend) {
        setState(() => _canSend = text.isNotEmpty);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!_canSend || widget.isLoading) return;
    widget.onSend(_controller.text.trim(), null);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(top: BorderSide(color: AppColors.surfaceGrey, width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isTaskThread) ...[
            // Task actions row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: widget.onMarkDone,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                      decoration: BoxDecoration(color: AppColors.emeraldDim, borderRadius: AppRadius.borderMd),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('✅', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 6),
                          Text('Mark Stage Done', style: AppTypography.textXs.copyWith(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: AppColors.emerald)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onBlock,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
                    decoration: BoxDecoration(color: AppColors.orangeDim, borderRadius: AppRadius.borderMd),
                    child: Row(
                      children: [
                        const Text('🚩', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 6),
                        Text('Block', style: AppTypography.textXs.copyWith(fontFamily: 'Syne', fontWeight: FontWeight.w700, color: AppColors.warning)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach Btn
              GestureDetector(
                onTap: widget.onAttach,
                child: Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                  child: const Center(child: Text('📎', style: TextStyle(fontSize: 16))),
                ),
              ),
              const SizedBox(width: 8),
              
              // Input field
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36, maxHeight: 100),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2), // Tweak padding
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center, // Center icons with text
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLines: null,
                          style: AppTypography.textSm.copyWith(color: AppColors.ink),
                          decoration: InputDecoration(
                            hintText: widget.placeholder,
                            hintStyle: AppTypography.textXs.copyWith(color: AppColors.textTertiary),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10), // Adjust text vertical alignment
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () { /* Emoji picker open */ },
                        child: Opacity(opacity: 0.6, child: const Text('😊', style: TextStyle(fontSize: 16))),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Send btn
              GestureDetector(
                onTap: _handleSend,
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _canSend ? AppColors.electricBlue : AppColors.surfaceGrey,
                    shape: BoxShape.circle,
                    boxShadow: _canSend ? [BoxShadow(color: AppColors.electricBlue.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
                  ),
                  child: Center(
                    child: widget.isLoading 
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
