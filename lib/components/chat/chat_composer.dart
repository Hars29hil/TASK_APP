import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
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
  State<ChatComposer> createState() => _ChatComposerState2();
}

class _ChatComposerState2 extends State<ChatComposer> {
  final _controller = TextEditingController();
  bool _canSend = false;
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final text = _controller.text.trim();
      final hasContent = text.isNotEmpty || _attachments.isNotEmpty;
      if (hasContent != _canSend) {
        setState(() => _canSend = hasContent);
      }
    });
  }

  final ImagePicker _picker = ImagePicker();

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _attachmentItem(Icons.image_rounded, "Image", Colors.purple, _pickImage),
            _attachmentItem(Icons.videocam_rounded, "Video", Colors.pink, _pickVideo),
            _attachmentItem(Icons.insert_drive_file_rounded, "Document", Colors.orange, _pickFiles),
            _attachmentItem(Icons.person_rounded, "Contact", Colors.blue, _pickContact),
          ]),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _attachmentItem(IconData icon, String label, Color c, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Column(children: [
      Container(width: 60, height: 60, decoration: BoxDecoration(color: c.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: c, size: 28)),
      const SizedBox(height: 8),
      Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
    ]),
  );

  Future<void> _pickImage() async {
    Navigator.pop(context);
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final file = PlatformFile(
        name: image.name,
        size: await image.length(),
        path: image.path,
        bytes: kIsWeb ? await image.readAsBytes() : null,
      );
      setState(() {
        _attachments.add(file);
        _canSend = true;
      });
      if (widget.onAttach != null) widget.onAttach!();
    }
  }

  Future<void> _pickVideo() async {
    Navigator.pop(context);
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      final file = PlatformFile(
        name: video.name,
        size: await video.length(),
        path: video.path,
        bytes: kIsWeb ? await video.readAsBytes() : null,
      );
      setState(() {
        _attachments.add(file);
        _canSend = true;
      });
      if (widget.onAttach != null) widget.onAttach!();
    }
  }

  Future<void> _pickContact() async {
    Navigator.pop(context);
    if (await Permission.contacts.request().isGranted) {
      try {
        final contactId = await FlutterContacts.native.showPicker();
        if (contactId != null) {
          final contact = await FlutterContacts.get(contactId, properties: ContactProperties.all);
          if (contact != null) {
            final contactInfo = "${contact.displayName}\n${contact.phones.isNotEmpty ? contact.phones.first.number : ''}";
            widget.onSend("📇 Contact: $contactInfo", null);
          }
        }
      } catch (e) {
        debugPrint("Contact error: $e");
      }
    }
  }

  Future<void> _pickFiles() async {
    Navigator.pop(context);
    try {
      final result = await FilePicker.pickFiles(allowMultiple: true);
      if (result != null) {
        setState(() {
          _attachments.addAll(result.files);
          _canSend = _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("File picking failed: $e");
    }
    if (widget.onAttach != null) {
      widget.onAttach!();
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
      _canSend = _controller.text.trim().isNotEmpty || _attachments.isNotEmpty;
    });
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        final emojis = ['😀', '😂', '🥺', '👍', '🙏', '❤️', '🔥', '✨', '🎉', '🚀', '👀', '💯', '🙌', '💡', '✅', '❌'];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Emoji", style: AppTypography.h3.copyWith(color: AppColors.ink)),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                ),
                itemCount: emojis.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _controller.text += emojis[index];
                      Navigator.pop(context);
                    },
                    child: Center(
                      child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleSend() {
    if (!_canSend || widget.isLoading) return;
    widget.onSend(_controller.text.trim(), _attachments.isNotEmpty ? _attachments : null);
    _controller.clear();
    setState(() {
      _attachments.clear();
      _canSend = false;
    });
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
                          Text('Mark Stage Done', style: AppTypography.textXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.emerald)),
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
                        Text('Block', style: AppTypography.textXs.copyWith(fontWeight: FontWeight.w700, color: AppColors.warning)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // Attachments preview
          if (_attachments.isNotEmpty) ...[
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                itemBuilder: (context, index) {
                  final file = _attachments[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8, bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGrey,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.insert_drive_file, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            file.name,
                            style: AppTypography.textXs.copyWith(color: AppColors.ink),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _removeAttachment(index),
                          child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],

          // Input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attach Btn
              GestureDetector(
                onTap: _showAttachmentMenu,
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
                        onTap: _showEmojiPicker,
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
