import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;
  const ChatDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;
  bool _isTyping = false;
  late Stream<List<Map<String, dynamic>>> _messageStream;
  late StreamSubscription<List<Map<String, dynamic>>> _messageSubscription;
  final Set<String> _markedAsSeenIds = {};

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';
  String get _receiverId => widget.userId;
  late Stream<Map<String, dynamic>> _receiverStatusStream;

  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();

    // Initialize the stream for UI
    _messageStream = _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);

    // Side-effects handled in subscription to avoid infinite loops and build-phase crashes
    _messageSubscription = _messageStream.listen((messages) {
      if (!mounted) return;
      for (final msg in messages) {
        final senderId = msg['sender_id']?.toString();
        final receiverId = msg['receiver_id']?.toString();
        final status = msg['status']?.toString();
        final id = msg['id']?.toString();

        if (id != null &&
            receiverId == _currentUserId &&
            senderId == _receiverId &&
            status != 'seen' &&
            !_markedAsSeenIds.contains(id)) {
          _markedAsSeenIds.add(id);
          _markAsSeen(id);
        }
      }
    });

    // Track receiver online status
    _receiverStatusStream = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', _receiverId)
        .map((data) => data.isNotEmpty ? data.first : {});

    _messageController.addListener(() {
      if (_isTyping != _messageController.text.isNotEmpty) {
        setState(() {
          _isTyping = _messageController.text.isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _messageSubscription.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsSeen(String messageId) async {
    try {
      await _supabase
          .from('messages')
          .update({'status': 'seen'})
          .eq('id', messageId)
          .eq('receiver_id', _currentUserId);
    } catch (e) {
      debugPrint("Error marking as seen: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_currentUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: You must be logged in to send messages."),
        ),
      );
      return;
    }

    _messageController.clear();

    try {
      await _supabase.from('messages').insert({
        'content': text,
        'sender_id': _currentUserId,
        'receiver_id': _receiverId,
        'status': 'sent',
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Supabase Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error (400): $e")));
      }
    }
  }

  Future<void> _sendAttachment(String fileUrl, String type) async {
    try {
      await _supabase.from('messages').insert({
        'content': type == 'image'
            ? '[Image]'
            : type == 'video'
                ? '[Video]'
                : type == 'contact'
                    ? '[Contact]'
                    : '[File]',
        'sender_id': _currentUserId,
        'receiver_id': _receiverId,
        'status': 'sent',
        'attachment_url': fileUrl,
        'attachment_type': type,
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending attachment: $e");
    }
  }

  // ── Cloudinary Configuration ──
  static final String _cloudinaryCloudName = dotenv.get('CLOUDINARY_CLOUD_NAME');
  static final String _cloudinaryUploadPreset = dotenv.get('CLOUDINARY_UPLOAD_PRESET');

  /// Compress image before uploading to reduce bandwidth and storage.
  /// Skips compression on web since dart:io is not available.
  Future<File?> _compressImage(File file) async {
    if (kIsWeb) return file; // compression not supported on web
    try {
      final targetPath = '${file.path}_compressed.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 60,
      );
      return compressedFile != null ? File(compressedFile.path) : file;
    } catch (e) {
      debugPrint('Compression failed, using original: $e');
      return file;
    }
  }

  /// Upload a file to Cloudinary using an unsigned upload preset.
  /// Supports both mobile (File) and web (XFile bytes).
  Future<String?> _uploadToCloudinary(dynamic file, String resourceType) async {
    setState(() => _isUploading = true);
    try {
      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload',
      );

      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _cloudinaryUploadPreset;

      if (kIsWeb && file is XFile) {
        // Web: read bytes from XFile
        final bytes = await file.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
          ),
        );
      } else if (file is File) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );
      } else if (file is XFile) {
        request.files.add(
          await http.MultipartFile.fromPath('file', file.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final data = jsonDecode(responseData);
        return data['secure_url'] as String?;
      } else {
        final errorBody = await response.stream.bytesToString();
        debugPrint('Cloudinary upload failed (${response.statusCode}): $errorBody');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) return;
      Navigator.pop(context);

      String? url;
      if (kIsWeb) {
        // Web: skip compression, upload XFile directly
        url = await _uploadToCloudinary(image, 'image');
      } else {
        // Mobile: compress then upload
        File originalFile = File(image.path);
        File? compressedFile = await _compressImage(originalFile);
        url = await _uploadToCloudinary(compressedFile ?? originalFile, 'image');
      }
      if (url != null) _sendAttachment(url, 'image');
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      if (!mounted) return;
      Navigator.pop(context);
      if (kIsWeb) {
        final url = await _uploadToCloudinary(video, 'video');
        if (url != null) _sendAttachment(url, 'video');
      } else {
        final url = await _uploadToCloudinary(File(video.path), 'video');
        if (url != null) _sendAttachment(url, 'video');
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.pickFiles();
      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        Navigator.pop(context);
        final url = await _uploadToCloudinary(
          File(result.files.single.path!),
          'auto',
        );
        if (url != null) _sendAttachment(url, 'file');
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
  }

  Future<void> _pickContact() async {
    if (await Permission.contacts.request().isGranted) {
      try {
        final String? contactId = await FlutterContacts.native.showPicker();
        if (contactId != null) {
          final Contact? contact = await FlutterContacts.get(
            contactId,
            properties: ContactProperties.all,
          );
          if (contact != null) {
            if (!mounted) return;
            Navigator.pop(context);
            final contactInfo =
                "${contact.displayName}\n${contact.phones.isNotEmpty ? contact.phones.first.number : ''}";
            await _supabase.from('messages').insert({
              'content': "📇 Contact: $contactInfo",
              'sender_id': _currentUserId,
              'receiver_id': _receiverId,
              'status': 'sent',
              'attachment_type': 'contact',
            });
          }
        }
      } catch (e) {
        debugPrint("Contact picker error: $e");
      }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildAttachmentItem(
                  Icons.image_rounded,
                  "Gallery",
                  Colors.purple,
                  _pickImage,
                ),
                _buildAttachmentItem(
                  Icons.videocam_rounded,
                  "Video",
                  Colors.pink,
                  _pickVideo,
                ),
                _buildAttachmentItem(
                  Icons.insert_drive_file_rounded,
                  "File",
                  Colors.orange,
                  _pickFile,
                ),
                _buildAttachmentItem(
                  Icons.person_rounded,
                  "Contact",
                  Colors.blue,
                  _pickContact,
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(decoration: BoxDecoration(color: Colors.white)),
          ),

          Positioned.fill(
            child: Column(
              children: [
                Expanded(child: _buildMessageStream()),
                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 10),
                          Text(
                            "Uploading attachment...",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                _buildInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageStream() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messageStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final rawData = snapshot.data!;

        final Set<String> seenIds = {};
        final messages = rawData.where((msg) {
          final id = msg['id']?.toString();
          if (id == null) return false;
          if (seenIds.contains(id)) return false;
          seenIds.add(id);

          final sId = msg['sender_id']?.toString().toLowerCase().trim() ?? '';
          final rId = msg['receiver_id']?.toString().toLowerCase().trim() ?? '';
          final myId = _currentUserId.toLowerCase().trim();
          final theirId = _receiverId.toLowerCase().trim();

          final matches =
              (sId == myId && rId == theirId) ||
              (sId == theirId && rId == myId);

          return matches;
        }).toList();

        if (messages.isEmpty) {
          return const Center(child: Text("No messages yet."));
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          padding: const EdgeInsets.only(
            top: 100,
            bottom: 20,
            left: 15,
            right: 15,
          ),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            final isMe = msg['sender_id'] == _currentUserId;

            return AnimatedOpacity(
              key: ValueKey(msg['id']),
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: isMe ? _buildSentMessage(msg) : _buildReceivedMessage(msg),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.black87,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Hero(
            tag: 'chat_avatar_${widget.userId}',
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(
                'https://i.pravatar.cc/150?u=${widget.userId}',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.userName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                StreamBuilder<Map<String, dynamic>>(
                  stream: _receiverStatusStream,
                  builder: (context, snapshot) {
                    final isOnline = snapshot.data?['is_online'] == true;
                    return Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOnline ? "Online" : "Offline",
                          style: TextStyle(
                            color: isOnline ? Colors.green : Colors.grey,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          onPressed: () => setState(() {}),
        ),
        const SizedBox(width: 10),
      ],
    );
  }

  Widget _buildSentMessage(Map<String, dynamic> msg) {
    final text = msg['content'] ?? '';
    final status = msg['status'] ?? 'sent';
    final attachmentUrl = msg['attachment_url'];
    final attachmentType = msg['attachment_type'];

    IconData statusIcon = Icons.done_rounded;
    Color iconColor = Colors.white70;

    if (status == 'delivered') {
      statusIcon = Icons.done_all_rounded;
    } else if (status == 'seen') {
      statusIcon = Icons.done_all_rounded;
      iconColor = Colors.cyanAccent;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A00E0).withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachmentUrl != null)
              _buildAttachmentPreview(attachmentUrl, attachmentType, true),
            if (text.isNotEmpty && attachmentType != 'contact')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            const SizedBox(height: 4),
            Icon(statusIcon, size: 14, color: iconColor),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedMessage(Map<String, dynamic> msg) {
    final text = msg['content'] ?? '';
    final attachmentUrl = msg['attachment_url'];
    final attachmentType = msg['attachment_type'];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (attachmentUrl != null)
              _buildAttachmentPreview(attachmentUrl, attachmentType, false),
            if (text.isNotEmpty && attachmentType != 'contact')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.black87, fontSize: 15),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(String url, String? type, bool isMe) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () => _showFullScreenImage(context, url),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.network(
            url,
            width: 200,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return SizedBox(
                width: 200,
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: isMe ? Colors.white : const Color(0xFF4A00E0),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 200,
                height: 120,
                decoration: BoxDecoration(
                  color: isMe ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_rounded,
                    color: isMe ? Colors.white70 : Colors.grey,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else if (type == 'video') {
      return _VideoThumbnailWidget(url: url, isMe: isMe);
    } else {
      return Container(
        width: 200,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe ? Colors.white24 : Colors.black12,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: isMe ? Colors.white : Colors.blue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Attachment",
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _dot(int delay) {
    return Container(
      margin: const EdgeInsets.only(right: 3),
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Color(0xFF4A00E0),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            GestureDetector(
              onTap: _showAttachmentMenu,
              child: _buildInputCircle(Icons.add_rounded),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: Colors.white),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.sentiment_satisfied_alt_rounded,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: _isTyping
                    ? _buildInputCircle(
                        Icons.send_rounded,
                        isPrimary: true,
                        key: const ValueKey("send"),
                      )
                    : _buildInputCircle(
                        Icons.mic_rounded,
                        isPrimary: true,
                        key: const ValueKey("mic"),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputCircle(IconData icon, {bool isPrimary = false, Key? key}) {
    return Container(
      key: key,
      width: 45,
      height: 45,
      decoration: BoxDecoration(
        gradient: isPrimary
            ? const LinearGradient(
                colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
              )
            : null,
        color: isPrimary ? null : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isPrimary
                ? const Color(0xFF4A00E0).withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: isPrimary ? Colors.white : const Color(0xFF4A00E0),
        size: 22,
      ),
    );
  }
}

/// Inline video thumbnail widget that plays video from Cloudinary URL.
class _VideoThumbnailWidget extends StatefulWidget {
  final String url;
  final bool isMe;

  const _VideoThumbnailWidget({required this.url, required this.isMe});

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _initialized = false;

  void _initPlayer() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller!.play();
          _isPlaying = true;
        }
      });

    _controller!.addListener(() {
      if (mounted) {
        // When video ends, show the play button again
        if (_controller!.value.position >= _controller!.value.duration &&
            _controller!.value.duration > Duration.zero) {
          setState(() => _isPlaying = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (!_initialized) {
          _initPlayer();
        } else if (_isPlaying) {
          _controller?.pause();
          setState(() => _isPlaying = false);
        } else {
          _controller?.play();
          setState(() => _isPlaying = true);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 220,
          height: 160,
          child: _initialized && _controller != null
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                    if (!_isPlaying)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(8),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                  ],
                )
              : Container(
                  color: Colors.black26,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          color: widget.isMe ? Colors.white : Colors.white70,
                          size: 50,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to play',
                          style: TextStyle(
                            color: widget.isMe ? Colors.white70 : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
