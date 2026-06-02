import 'package:flutter/material.dart';
import '../components/chat/chat_list_components.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _searchController = TextEditingController();
  final _chatService = ChatService.instance;
  
  List<ChatListItem> _allChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChats('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats(String query) async {
    setState(() => _isLoading = true);
    final results = await _chatService.fetchChatList(query);
    if (mounted) {
      setState(() {
        _allChats = results;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    _fetchChats(query);
  }

  @override
  Widget build(BuildContext context) {
    final projects = _allChats.where((c) => c.type == 'project').toList();
    final dms = _allChats.where((c) => c.type == 'dm').toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          elevation: 0,
          title: Text('Messages', style: AppTypography.h2),
          centerTitle: false,
          actions: [
            _buildHeaderIcon(Icons.edit_square, hasBadge: true),
            const SizedBox(width: 20),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(110),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: ChatSearchBar(
                    placeholder: 'Search messages...',
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                  ),
                ),
                TabBar(
                  labelColor: AppColors.electricBlue,
                  unselectedLabelColor: AppColors.textTertiary,
                  indicatorColor: AppColors.electricBlue,
                  labelStyle: AppTypography.labelLarge,
                  unselectedLabelStyle: AppTypography.labelLarge,
                  dividerColor: AppColors.border,
                  tabs: const [
                    Tab(text: 'Direct Messages'),
                    Tab(text: 'Group Chats'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
            : TabBarView(
                children: [
                  _buildList(dms, true),
                  _buildList(projects, false),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<ChatListItem> items, bool isDm) {
    if (items.isEmpty) {
      return _buildEmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, top: 8),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: isDm
              ? DMRow(item: item, onTap: () => _openDMChat(item))
              : ProjectChatCard(item: item, onTap: () => _openProjectChat(item)),
        );
      },
    );
  }

  Widget _buildHeaderIcon(IconData icon, {bool hasBadge = false}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon, size: 18, color: AppColors.ink)),
          if (hasBadge)
            Positioned(
              top: -2,
              right: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.electricBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💬', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          Text('No messages yet', style: AppTypography.h3),
          const SizedBox(height: 8),
          Text(
            'Start collaborating with your team',
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  void _openProjectChat(ChatListItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          roomId: item.id,
          roomType: 'project',
          roomName: item.name,
          currentStage: item.currentStage,
        ),
      ),
    );
  }

  void _openDMChat(ChatListItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailScreen(
          roomId: item.id,
          roomType: 'dm',
          roomName: item.name,
        ),
      ),
    );
  }
}
