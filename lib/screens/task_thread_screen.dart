import 'package:flutter/material.dart';
import '../components/chat/chat_top_bar.dart';
import '../components/chat/chat_message_components.dart';
import '../components/chat/chat_composer.dart';
import '../models/chat_models.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

class TaskThreadScreen extends StatefulWidget {
  final String stageId;
  final String stageName;
  final String projectId;

  const TaskThreadScreen({
    super.key,
    required this.stageId,
    required this.stageName,
    required this.projectId,
  });

  @override
  State<TaskThreadScreen> createState() => _TaskThreadScreenState();
}

class _TaskThreadScreenState extends State<TaskThreadScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Message> _messages = [];
  bool _isLoading = true;
  String _activeTab = 'thread'; // 'thread', 'files', 'updates'

  @override
  void initState() {
    super.initState();
    _loadMockMessages();
  }

  void _loadMockMessages() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _messages = [
          Message(
            id: 't1',
            authorId: 'sys',
            text: '⚡ ${widget.stageName} started',
            type: 'system',
            createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          ),
          Message(
            id: 't2',
            authorId: 'u2',
            text: 'Working on this now. I will upload the files soon.',
            type: 'text',
            createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
          ),
        ];
        _isLoading = false;
      });
      _scrollToBottom();
    });
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

  void _sendMessage(String text, List<dynamic>? attachments) {
    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorId: 'me',
          text: text,
          type: 'text',
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _markStageDone() {
    setState(() {
      _messages.add(
        Message(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          authorId: 'me',
          text: '',
          type: 'status',
          statusData: {
            'title': '${widget.stageName} done',
            'subtitle': 'Moved to review'
          },
          createdAt: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
    // API call would go here
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            ChatTopbar(
              isProject: true,
              title: widget.stageName,
              memberCount: 3,
              messageCount: _messages.length,
              onBackPressed: () => Navigator.pop(context),
              onMorePressed: () {},
            ),

            // Task Context Card
            _buildTaskContextCard(),

            // Tabs
            _buildThreadTabs(),

            // Messages
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
                : _activeTab == 'thread' 
                  ? ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final msg = _messages[index];
                        final isMine = msg.authorId == 'me';
                        final user = User(id: msg.authorId, name: isMine ? 'Me' : 'Alice', email: '');
                        
                        return MessageRow(
                          message: msg,
                          user: user,
                          isMine: isMine,
                          showAvatar: !isMine,
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        '${_activeTab.toUpperCase()} View\n(Coming soon)',
                        textAlign: TextAlign.center,
                        style: AppTypography.textSm.copyWith(color: AppColors.textTertiary),
                      ),
                    ),
            ),

            // Composer with Actions
            if (_activeTab == 'thread')
              ChatComposer(
                isTaskThread: true,
                onSend: _sendMessage,
                onMarkDone: _markStageDone,
                onBlock: () {},
                onAttach: () {},
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskContextCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14), // radius-lg
        border: const Border(left: BorderSide(color: AppColors.electricBlue, width: 3)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CURRENT STAGE',
            style: AppTypography.textXs.copyWith(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w700,
              color: AppColors.electricBlue,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            widget.stageName,
            style: AppTypography.textMd.copyWith(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildChip('👤 Alice'),
              const SizedBox(width: 8),
              _buildChip('⏱ Due today', isUrgent: true),
              const SizedBox(width: 8),
              _buildChip('📁 2 files'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.72,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.electricBlue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '72%',
                style: AppTypography.textXs.copyWith(
                  fontFamily: 'Syne',
                  fontWeight: FontWeight.w700,
                  color: AppColors.electricBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, {bool isUrgent = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent ? AppColors.orangeDim : AppColors.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: AppTypography.textXs.copyWith(
          color: isUrgent ? AppColors.warning : AppColors.ink,
          fontWeight: isUrgent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildThreadTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _buildTab('Thread', 'thread'),
          const SizedBox(width: 4),
          _buildTab('Files', 'files'),
          const SizedBox(width: 4),
          _buildTab('Updates', 'updates'),
        ],
      ),
    );
  }

  Widget _buildTab(String title, String key) {
    final isActive = _activeTab == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: isActive ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.textXs.copyWith(
              fontFamily: 'Syne',
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
