import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
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
  RealtimeChannel? _subscription;
  String _currentUserId = '';

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
    _scrollToBottom();

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
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
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

  void _sendMessage(String text, List<dynamic>? attachments) async {
    final isProject = widget.roomType == 'project';
    
    final realMsg = await ChatService.instance.sendMessage(widget.roomId, isProject, text);
    if (realMsg != null && mounted) {
      // Add the real message from DB to the UI instantly.
      // The realtime subscription will ignore it because the ID matches.
      setState(() {
        _messages.add(realMsg);
      });
      _scrollToBottom();
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
                      
                      // Mock user mapping (in real app, fetch user profiles from DB)
                      final user = User(
                        id: msg.authorId,
                        name: isMine ? 'Me' : 'Alice',
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
