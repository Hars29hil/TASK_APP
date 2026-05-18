import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_player/video_player.dart';

class TaskChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  const TaskChatScreen({super.key, required this.taskId, required this.taskTitle});
  @override
  State<TaskChatScreen> createState() => _TaskChatScreenState();
}

class _TaskChatScreenState extends State<TaskChatScreen> {
  final _supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isUploading = false;
  final ImagePicker _picker = ImagePicker();
  RealtimeChannel? _channel;

  String get _backendUrl {
    if (kIsWeb) {
      final envUrl = dotenv.maybeGet('BACKEND_URL');
      if (envUrl != null && envUrl.contains('http') && !envUrl.contains('10.0.2.2')) {
        return envUrl;
      }
      return 'http://localhost:5000';
    }

    final envUrl = dotenv.maybeGet('BACKEND_URL');
    if (envUrl != null && envUrl.isNotEmpty) return envUrl;
    
    if (Theme.of(context).platform == TargetPlatform.android) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }
  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribeRealtime() {
    _channel = _supabase.channel('task-chat-${widget.taskId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'task_group_messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'task_id', value: widget.taskId),
        callback: (_) => _fetchMessages(),
      )
      .subscribe();
  }

  Future<void> _fetchMessages() async {
    try {
      final resp = await http.get(Uri.parse('$_backendUrl/tasks/${widget.taskId}/messages'));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data['success'] == true && mounted) {
          setState(() { _messages = List<Map<String, dynamic>>.from(data['messages']); _isLoading = false; });
          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    setState(() => _isSending = true);
    try {
      await http.post(
        Uri.parse('$_backendUrl/tasks/${widget.taskId}/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'sender_id': _currentUserId, 'content': text}),
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint("Send error: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendAttachment(String fileUrl, String type) async {
    try {
      await http.post(
        Uri.parse('$_backendUrl/tasks/${widget.taskId}/messages'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender_id': _currentUserId,
          'content': type == 'image' ? '[Image]' : type == 'video' ? '[Video]' : type == 'contact' ? '[Contact]' : '[File]',
          'attachment_url': fileUrl,
          'attachment_type': type,
        }),
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint("Error sending attachment: $e");
    }
  }

  // Cloudinary
  static final String _cloudinaryCloudName = dotenv.get('CLOUDINARY_CLOUD_NAME');
  static final String _cloudinaryUploadPreset = dotenv.get('CLOUDINARY_UPLOAD_PRESET');

  Future<File?> _compressImage(File file) async {
    if (kIsWeb) {
      return file;
    }
    try {
      final targetPath = '${file.path}_compressed.jpg';
      final compressedFile = await FlutterImageCompress.compressAndGetFile(file.absolute.path, targetPath, quality: 60);
      return compressedFile != null ? File(compressedFile.path) : file;
    } catch (e) {
      return file;
    }
  }

  Future<String?> _uploadToCloudinary(dynamic file, String resourceType) async {
    setState(() => _isUploading = true);
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload');
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _cloudinaryUploadPreset;
      if (kIsWeb && file is XFile) {
        final bytes = await file.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));
      } else if (file is File) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      } else if (file is XFile) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path));
      }
      final response = await request.send();
      if (response.statusCode == 200) {
        final data = jsonDecode(await response.stream.bytesToString());
        return data['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      String? url;
      if (kIsWeb) {
        url = await _uploadToCloudinary(image, 'image');
      }
      else {
        File originalFile = File(image.path);
        File? compressedFile = await _compressImage(originalFile);
        url = await _uploadToCloudinary(compressedFile ?? originalFile, 'image');
      }
      if (url != null) {
        _sendAttachment(url, 'image');
      }
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
      final url = await _uploadToCloudinary(kIsWeb ? video : File(video.path), 'video');
      if (url != null) {
        _sendAttachment(url, 'video');
      }
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles();
      if (result != null && result.files.single.path != null) {
        if (!mounted) {
          return;
        }
        Navigator.pop(context);
        final url = await _uploadToCloudinary(File(result.files.single.path!), 'auto');
        if (url != null) {
          _sendAttachment(url, 'file');
        }
      }
    } catch (e) { debugPrint('File error: $e'); }
  }

  Future<void> _pickContact() async {
    if (await Permission.contacts.request().isGranted) {
      try {
        final contactId = await FlutterContacts.native.showPicker();
        if (contactId != null) {
          final contact = await FlutterContacts.get(contactId, properties: ContactProperties.all);
          if (contact != null) {
            if (!mounted) {
              return;
            }
            Navigator.pop(context);
            final contactInfo = "${contact.displayName}\n${contact.phones.isNotEmpty ? contact.phones.first.number : ''}";
            await http.post(
              Uri.parse('$_backendUrl/tasks/${widget.taskId}/messages'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'sender_id': _currentUserId,
                'content': "📇 Contact: $contactInfo",
                'attachment_type': 'contact',
              }),
            );
          }
        }
      } catch (e) { debugPrint("Contact error: $e"); }
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _attachmentItem(Icons.image_rounded, "Gallery", Colors.purple, _pickImage),
            _attachmentItem(Icons.videocam_rounded, "Video", Colors.pink, _pickVideo),
            _attachmentItem(Icons.insert_drive_file_rounded, "File", Colors.orange, _pickFile),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF4A00E0), elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.taskTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const Text("Task Group Chat", style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        actions: [
          CircleAvatar(radius: 18, backgroundColor: Colors.white.withValues(alpha: 0.2), child: const Icon(Icons.group_rounded, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF4A00E0)))
            : _messages.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_bubble_outline_rounded, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text("No messages yet", style: TextStyle(color: Colors.grey[400])),
                ]))
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: _messages.length,
                  itemBuilder: (ctx, i) => _buildMessage(_messages[i]),
                ),
        ),
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF4A00E0))),
              const SizedBox(width: 10),
              const Text("Uploading attachment...", style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          ),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == _currentUserId;
    final profile = msg['profiles'];
    final name = profile?['full_name'] ?? 'User';
    final content = msg['content'] ?? '';
    final time = _formatTime(msg['created_at']);
    final attachmentUrl = msg['attachment_url'];
    final attachmentType = msg['attachment_type'];
    final isSystem = content.startsWith('📋') || content.startsWith('✅') || content.startsWith('🎉');

    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: const Color(0xFF4A00E0).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
        child: Text(content, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontStyle: FontStyle.italic)),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
          if (!isMe) Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 10, backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=${msg['sender_id']}')),
              const SizedBox(width: 6),
              Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF4A00E0) : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4), bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (attachmentUrl != null) ...[
                _attachmentPreview(attachmentUrl, attachmentType, isMe),
                const SizedBox(height: 8),
              ],
              if (content.isNotEmpty && attachmentType != 'contact')
                Text(content, style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 14)),
              const SizedBox(height: 4),
              Text(time, style: TextStyle(color: isMe ? Colors.white60 : Colors.grey[400], fontSize: 10)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _attachmentPreview(String url, String? type, bool isMe) {
    if (type == 'image') {
      return GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenImage(url: url))),
        child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(url, width: 200, fit: BoxFit.cover)),
      );
    } else if (type == 'video') {
      return _VideoPreview(url: url, isMe: isMe);
    } else {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: isMe ? Colors.white12 : Colors.black12, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.insert_drive_file_rounded, color: isMe ? Colors.white : Colors.blue, size: 20),
          const SizedBox(width: 8),
          const Text("Attachment", style: TextStyle(fontSize: 13)),
        ]),
      );
    }
  }
  Widget _buildInputBar() => Container(
    padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -3))]),
    child: Row(children: [
      GestureDetector(
        onTap: _showAttachmentMenu,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: const Color(0xFF4A00E0).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: const Icon(Icons.add_rounded, color: Color(0xFF4A00E0), size: 24),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(25)),
        child: TextField(
          controller: _msgCtrl,
          decoration: const InputDecoration(hintText: "Type a message...", border: InputBorder.none),
          onSubmitted: (_) => _sendMessage(),
        ),
      )),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: _isSending ? null : _sendMessage,
        child: Container(
          width: 45, height: 45,
          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFF8E2DE2), Color(0xFF4A00E0)])),
          child: Icon(_isSending ? Icons.hourglass_top_rounded : Icons.send_rounded, color: Colors.white, size: 20),
        ),
      ),
    ]),
  );

  String _formatTime(String? iso) {
    if (iso == null) {
      return '';
    }
    try {
      final d = DateTime.parse(iso).toLocal();
      final h = d.hour.toString().padLeft(2, '0');
      final m = d.minute.toString().padLeft(2, '0');
      return "$h:$m";
    } catch (_) {
      return '';
    }
  }
}

class _FullScreenImage extends StatelessWidget {
  final String url;
  const _FullScreenImage({required this.url});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)), body: Center(child: Image.network(url)));
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VideoPreview({required this.url, required this.isMe});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late VideoPlayerController _ctrl;
  bool _isInit = false;
  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) => setState(() => _isInit = true));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!_isInit) return const SizedBox(width: 200, height: 120, child: Center(child: CircularProgressIndicator()));
    return Container(
      width: 200, height: 120,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black),
      child: Stack(alignment: Alignment.center, children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl))),
        IconButton(icon: const Icon(Icons.play_circle_fill, color: Colors.white, size: 40), onPressed: () => _showFullVideo()),
      ]),
    );
  }
  void _showFullVideo() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(backgroundColor: Colors.black, appBar: AppBar(backgroundColor: Colors.black), body: Center(child: AspectRatio(aspectRatio: _ctrl.value.aspectRatio, child: VideoPlayer(_ctrl))))));
    _ctrl.play();
  }
}
