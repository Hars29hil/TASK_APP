import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../services/chat_service.dart';
import '../components/chat/chat_top_bar.dart';
import '../components/chat/chat_message_components.dart';
import '../components/chat/chat_composer.dart';
import '../models/chat_models.dart';
import '../models/project.dart';
import '../theme/app_theme.dart';
import 'task_thread_screen.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String roomType; // 'project', 'dm'
  final String roomName;
  final String? currentStage;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.roomType,
    required this.roomName,
    this.currentStage,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;
  RealtimeChannel? _subscription;
  Timer? _pollingTimer;
  String _currentUserId = '';
  final Map<String, String> _userNames = {}; // Cache sender_id -> name

  static final String _cloudinaryCloudName = dotenv.get('CLOUDINARY_CLOUD_NAME', fallback: '');
  static final String _cloudinaryUploadPreset = dotenv.get('CLOUDINARY_UPLOAD_PRESET', fallback: '');

  @override
  void initState() {
    super.initState();
    _currentUserId = ChatService.instance.currentUserId;
    _loadMessages();
  }

  void _loadMessages() async {
    final isProject = widget.roomType == 'project';
    
    // Fetch historical messages
    final msgs = await ChatService.instance.fetchMessages(widget.roomId, isProject);
    if (!mounted) return;
    
    setState(() {
      _messages = msgs;
      _isLoading = false;
    });

    // Fetch unique user profiles for sender names
    final uniqueIds = msgs.map((m) => m.authorId).toSet();
    for (final uid in uniqueIds) {
      _fetchSingleUserName(uid);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Subscribe to new messages
    _subscription = ChatService.instance.subscribeToMessages(
      widget.roomId, 
      isProject, 
      (Message newMsg) {
        if (!mounted) return;
        
        // Prevent exact duplicates just in case
        if (_messages.any((m) => m.id == newMsg.id)) return;
        
        setState(() {
          _messages.add(newMsg);
        });
        _scrollToBottom();
      }
    );

    // Setup polling for group chats to bypass RLS Realtime limitations
    if (isProject) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        _pollNewMessages();
      });
    }
  }

  void _pollNewMessages() async {
    if (!mounted) return;
    final isProject = widget.roomType == 'project';
    final msgs = await ChatService.instance.fetchMessages(widget.roomId, isProject);
    if (!mounted) return;
    
    bool addedAny = false;
    for (final newMsg in msgs) {
      if (!_messages.any((m) => m.id == newMsg.id)) {
        _messages.add(newMsg);
        addedAny = true;
        _fetchSingleUserName(newMsg.authorId);
      }
    }
    
    if (addedAny) {
      setState(() {});
      _scrollToBottom();
    }
  }

  void _fetchSingleUserName(String uid) async {
    if (_userNames.containsKey(uid)) return;
    if (uid == _currentUserId) {
      _userNames[uid] = 'Me';
      return;
    }
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, email')
          .eq('id', uid)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _userNames[uid] = profile['full_name'] ?? profile['email']?.toString().split('@')[0] ?? 'User';
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _pollingTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<String?> _uploadToCloudinary(PlatformFile file, String resourceType) async {
    setState(() => _isUploading = true);
    try {
      final url = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/$resourceType/upload');
      final request = http.MultipartRequest('POST', url);
      request.fields['upload_preset'] = _cloudinaryUploadPreset;
      
      if (kIsWeb && file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else if (file.path != null) {
        request.files.add(await http.MultipartFile.fromPath('file', file.path!));
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
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _sendMessage(String text, List<dynamic>? attachments) async {
    final isProject = widget.roomType == 'project';
    String? attachmentUrl;
    String? attachmentType;

    if (attachments != null && attachments.isNotEmpty) {
      final file = attachments.first as PlatformFile;
      final ext = file.extension?.toLowerCase() ?? '';
      
      if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
        attachmentType = 'image';
      } else if (['mp4', 'mov', 'avi'].contains(ext)) {
        attachmentType = 'video';
      } else {
        attachmentType = 'raw'; // Used for raw files in Cloudinary
      }

      attachmentUrl = await _uploadToCloudinary(file, attachmentType == 'raw' ? 'raw' : (attachmentType == 'image' ? 'image' : 'video'));
      
      if (attachmentUrl != null) {
        if (text.isEmpty) text = '[${attachmentType == 'image' ? 'Image' : (attachmentType == 'video' ? 'Video' : 'File')}]';
        if (attachmentType == 'raw') attachmentType = 'file'; // Convert back for DB
      } else {
        // If upload failed, don't send message
        return;
      }
    } else if (text.startsWith("📇 Contact:")) {
      attachmentType = 'contact';
    }

    final realMsg = await ChatService.instance.sendMessage(
      widget.roomId, 
      isProject, 
      text,
      attachmentUrl: attachmentUrl,
      attachmentType: attachmentType,
    );
    
    if (realMsg != null && mounted) {
      if (!_messages.any((m) => m.id == realMsg.id)) {
        setState(() {
          _messages.add(realMsg);
        });
        _scrollToBottom();
      }
    }
  }

  void _openTaskThread() {
    // Navigate to task thread (using stage info)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskThreadScreen(
          stageId: 's1', // mock
          stageName: widget.currentStage ?? 'Current Stage',
          projectId: widget.roomId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isProject = widget.roomType == 'project';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            ChatTopbar(
              isProject: isProject,
              title: widget.roomName,
              memberCount: isProject ? 3 : 2,
              messageCount: _messages.length,
              onBackPressed: () => Navigator.pop(context),
              onMorePressed: () {},
            ),
            
            // Stage Banner (If active project stage exists)
            if (isProject && widget.currentStage != null)
              StageBanner(
                stage: Stage(
                  id: 's1',
                  title: widget.currentStage!,
                  status: 'active',
                  stepNumber: 1,
                ), // mock
                isActive: true,
                onOpenStage: _openTaskThread,
              ),

            // Messages Area
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg.authorId == _currentUserId;
                      
                      final user = User(
                        id: msg.authorId,
                        name: _userNames[msg.authorId] ?? (isMine ? 'Me' : 'User'),
                        email: '',
                      );

                      // Date divider logic (mock)
                      bool showDate = index == 0;
                      
                      return Column(
                        children: [
                          if (showDate) DateDivider(date: msg.createdAt),
                          MessageRow(
                            message: msg,
                            user: user,
                            isMine: isMine,
                            showAvatar: !isMine, // In real app, check if previous msg is from same user
                          ),
                        ],
                      );
                    },
                  ),
            ),

            if (_isUploading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.electricBlue)),
                    SizedBox(width: 10),
                    Text("Uploading attachment...", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

            // Composer
            ChatComposer(
              isTaskThread: false,
              onSend: _sendMessage,
              onAttach: () {
                // file picker
              },
            ),
          ],
        ),
      ),
    );
  }
}
