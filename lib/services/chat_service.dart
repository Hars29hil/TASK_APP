import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_models.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();
  final _supabase = Supabase.instance.client;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  /// Fetch the list of all chats (Projects and DMs) for the current user
  Future<List<ChatListItem>> fetchChatList(String query) async {
    if (_currentUserId.isEmpty) return [];

    List<ChatListItem> items = [];

    try {
      // 1. Fetch DMs (Users)
      var userQuery = _supabase.from('profiles').select();
      if (query.isNotEmpty) {
        userQuery = userQuery.or('full_name.ilike.%$query%,email.ilike.%$query%');
      }
      final userResponse = await userQuery.neq('id', _currentUserId).limit(20);

      // 2. Fetch Projects (Task Groups)
      final membershipResponse = await _supabase
          .from('task_members')
          .select('task_id, role')
          .eq('user_id', _currentUserId);

      // Add DMs to the list
      for (var u in userResponse) {
        items.add(
          ChatListItem(
            id: u['id'],
            type: 'dm',
            name: (u['full_name'] != null && u['full_name'].toString().isNotEmpty) 
              ? u['full_name'] 
              : u['email']?.toString().split('@')[0] ?? "User",
            avatar: 'https://i.pravatar.cc/150?u=${u['id']}',
            lastMessage: ChatListItemLastMessage(
              text: 'Tap to start chatting...',
              authorName: '',
              timestamp: DateTime.now(),
            ),
            lastViewedAt: DateTime.now(),
            isOnline: false,
          ),
        );
      }

      // Add Projects to the list
      if (membershipResponse.isNotEmpty) {
        final taskIds = membershipResponse.map((m) => m['task_id']).toList();
        final tasksDetails = await _supabase
            .from('tasks')
            .select('id, title, status')
            .inFilter('id', taskIds);

        for (var task in tasksDetails) {
          if (query.isEmpty || task['title'].toString().toLowerCase().contains(query.toLowerCase())) {
            
            // Map stage status
            String stageStatus = 'done';
            if (task['status'] == 'active' || task['status'] == 'in_progress' || task['status'] == 'ready') {
              stageStatus = 'active';
            }

            items.add(
              ChatListItem(
                id: task['id'],
                type: 'project',
                name: task['title'],
                emoji: '🚀', // Mock
                currentStage: 'Development Phase', // Mock
                stageStatus: stageStatus,
                lastMessage: ChatListItemLastMessage(
                  text: 'Group chat for this task...',
                  authorName: 'System',
                  timestamp: DateTime.now(),
                ),
                lastViewedAt: DateTime.now(),
                memberCount: 3, // Mock
                messageCount: 0, // Mock
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching chat list: $e");
    }

    return items;
  }

  /// Subscribe to Realtime typing events (Mock for now, via Supabase broadcast channel if needed)
  RealtimeChannel subscribeToTyping(String roomId, Function(TypingStatus) onTyping) {
    return _supabase.channel('room-$roomId')
      .onBroadcast(
        event: 'typing',
        callback: (payload) {
          if (payload['userId'] != _currentUserId) {
            onTyping(TypingStatus(
              userId: payload['userId'],
              roomId: roomId,
              startedAt: DateTime.now(),
              expiresAt: DateTime.now().add(const Duration(seconds: 5)),
            ));
          }
        },
      )
      .subscribe();
  }

  /// Broadcast typing event
  Future<void> sendTypingEvent(RealtimeChannel channel, String roomId) async {
    await channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'userId': _currentUserId, 'roomId': roomId},
    );
  }
}
