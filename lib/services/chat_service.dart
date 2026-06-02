import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat_models.dart';

class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();
  final _supabase = Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

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
    
    // Default for Android emulator
    return 'http://10.0.2.2:5000';
  }

  /// Fetch the list of all chats (Projects and DMs) for the current user
  Future<List<ChatListItem>> fetchChatList(String query) async {
    if (currentUserId.isEmpty) return [];

    List<ChatListItem> items = [];

    try {
      // 1. Fetch DMs (Users)
      var userQuery = _supabase.from('profiles').select();
      if (query.isNotEmpty) {
        userQuery = userQuery.or('full_name.ilike.%$query%,email.ilike.%$query%');
      }
      final userResponse = await userQuery.neq('id', currentUserId).limit(20);

      // 2. Fetch Projects (Task Groups)
      final membershipResponse = await _supabase
          .from('task_members')
          .select('task_id, role')
          .eq('user_id', currentUserId);

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
          if (payload['userId'] != currentUserId) {
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
      payload: {'userId': currentUserId, 'roomId': roomId},
    );
  }

  /// Fetch historical messages for a room
  Future<List<Message>> fetchMessages(String roomId, bool isProject) async {
    if (currentUserId.isEmpty) return [];
    
    try {
      if (isProject) {
        final response = await _supabase
            .from('task_group_messages')
            .select('*')
            .eq('task_id', roomId)
            .order('created_at', ascending: true);
            
        return response.map((data) => Message(
          id: data['id'].toString(),
          projectId: data['task_id'],
          authorId: data['sender_id'],
          text: data['content'],
          type: 'text',
          createdAt: DateTime.parse(data['created_at']),
        )).toList();
      } else {
        // DMs
        final response = await _supabase
            .from('messages')
            .select('*')
            .or('and(sender_id.eq.$currentUserId,receiver_id.eq.$roomId),and(sender_id.eq.$roomId,receiver_id.eq.$currentUserId)')
            .order('created_at', ascending: true);
            
        return response.map((data) => Message(
          id: data['id'].toString(),
          authorId: data['sender_id'],
          text: data['content'],
          type: 'text',
          createdAt: DateTime.parse(data['created_at']),
        )).toList();
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
      return [];
    }
  }

  /// Send a new message to a room
  Future<Message?> sendMessage(String roomId, bool isProject, String text) async {
    if (currentUserId.isEmpty) return null;
    
    try {
      if (isProject) {
        final data = await _supabase.from('task_group_messages').insert({
          'task_id': roomId,
          'sender_id': currentUserId,
          'content': text,
        }).select().single();
        
        // Notify backend for group chat
        try {
          await http.post(
            Uri.parse('$_backendUrl/api/send-group-chat-notification'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'task_id': roomId,
              'sender_id': currentUserId,
              'content': text,
            }),
          );
        } catch (e) {
          debugPrint("Push notification error: $e");
        }
        
        return Message(
          id: data['id'].toString(),
          projectId: data['task_id'],
          authorId: data['sender_id'],
          text: data['content'],
          type: 'text',
          createdAt: DateTime.parse(data['created_at']),
        );
      } else {
        final data = await _supabase.from('messages').insert({
          'sender_id': currentUserId,
          'receiver_id': roomId,
          'content': text,
        }).select().single();
        
        // Notify backend for DM
        try {
          await http.post(
            Uri.parse('$_backendUrl/api/send-chat-notification'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sender_id': currentUserId,
              'receiver_id': roomId,
              'content': text,
            }),
          );
        } catch (e) {
          debugPrint("Push notification error: $e");
        }
        
        return Message(
          id: data['id'].toString(),
          authorId: data['sender_id'],
          text: data['content'],
          type: 'text',
          createdAt: DateTime.parse(data['created_at']),
        );
      }
    } catch (e) {
      debugPrint("Error sending message: $e");
      return null;
    }
  }

  /// Subscribe to Realtime messages for a room
  RealtimeChannel subscribeToMessages(String roomId, bool isProject, Function(Message) onMessage) {
    final table = isProject ? 'task_group_messages' : 'messages';
    final filter = isProject 
        ? PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'task_id',
            value: roomId,
          ) 
        : null; 
    
    return _supabase.channel('public:$table:$roomId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (payload) {
          final data = payload.newRecord;
          // For DMs, ensure the message belongs to this conversation
          if (!isProject) {
            final sender = data['sender_id'];
            final receiver = data['receiver_id'];
            if (!((sender == currentUserId && receiver == roomId) || 
                  (sender == roomId && receiver == currentUserId))) {
              return;
            }
          }
          
          final msg = Message(
            id: data['id'].toString(),
            projectId: isProject ? data['task_id'] : null,
            authorId: data['sender_id'],
            text: data['content'],
            type: 'text',
            createdAt: DateTime.parse(data['created_at']),
          );
          onMessage(msg);
        },
      )
      .subscribe();
  }
}
