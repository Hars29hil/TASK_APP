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
    // Simple debounce could go here
    _fetchChats(query);
  }

  @override
  Widget build(BuildContext context) {
    final projects = _allChats.where((c) => c.type == 'project').toList();
    final dms = _allChats.where((c) => c.type == 'dm').toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Chats',
                    style: AppTypography.h2.copyWith(fontFamily: 'Syne', fontWeight: FontWeight.w800, fontSize: 22),
                  ),
                  Row(
                    children: [
                      _buildHeaderIcon(Icons.search_rounded),
                      const SizedBox(width: 12),
                      _buildHeaderIcon(Icons.edit_square, hasBadge: true),
                    ],
                  ),
                ],
              ),
            ),
            
            // Search Bar
            ChatSearchBar(
              placeholder: 'Search projects or people...',
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
            
            // List
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.electricBlue))
                : _allChats.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        if (projects.isNotEmpty) ...[
                          const ChatSectionLabel('PROJECTS'),
                          ...projects.map((p) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: ProjectChatCard(
                                  item: p,
                                  onTap: () => _openProjectChat(p),
                                ),
                              )),
                        ],
                        if (dms.isNotEmpty) ...[
                          const ChatSectionLabel('DIRECT MESSAGES'),
                          ...dms.map((dm) => Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: DMRow(
                                  item: dm,
                                  onTap: () => _openDMChat(dm),
                                ),
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon, {bool hasBadge = false}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        boxShadow: AppShadows.soft,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(child: Icon(icon, size: 16, color: AppColors.ink)),
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
                  border: Border.all(color: AppColors.bg, width: 2),
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
