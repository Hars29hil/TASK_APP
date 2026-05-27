import 'project.dart';

class User {
  final String id;
  final String name;
  final String? email;

  User({required this.id, required this.name, this.email});
}

class Message {
  final String id;
  final String? projectId;
  final String? stageId;
  final String? threadId;
  final String authorId;
  final String text;
  final String type; // 'text', 'system', 'file', 'status', 'reaction'
  
  final DateTime createdAt;
  final DateTime? editedAt;

  final List<String> mentions;
  
  final List<MessageAttachment> attachments;
  final List<MessageReaction> reactions;
  
  final String? systemType;
  final Map<String, dynamic>? systemData;

  final String? statusType;
  final Map<String, dynamic>? statusData;

  final String? replyToId;
  final bool isRead;
  final List<String> readBy;

  Message({
    required this.id,
    this.projectId,
    this.stageId,
    this.threadId,
    required this.authorId,
    required this.text,
    required this.type,
    required this.createdAt,
    this.editedAt,
    this.mentions = const [],
    this.attachments = const [],
    this.reactions = const [],
    this.systemType,
    this.systemData,
    this.statusType,
    this.statusData,
    this.replyToId,
    this.isRead = false,
    this.readBy = const [],
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] ?? '',
      projectId: map['projectId'],
      stageId: map['stageId'],
      threadId: map['threadId'],
      authorId: map['authorId'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
      editedAt: map['editedAt'] != null ? DateTime.parse(map['editedAt']) : null,
      isRead: map['isRead'] ?? false,
      systemType: map['systemType'],
      systemData: map['systemData'],
      statusType: map['statusType'],
      statusData: map['statusData'],
      replyToId: map['replyToId'],
    );
  }
}

class MessageAttachment {
  final String id;
  final String name;
  final int size;
  final String url;
  final String mimeType;

  MessageAttachment({
    required this.id,
    required this.name,
    required this.size,
    required this.url,
    required this.mimeType,
  });
}

class MessageReaction {
  final String emoji;
  final List<String> users;

  MessageReaction({
    required this.emoji,
    required this.users,
  });
}

class ChatRoom {
  final String id;
  final String type; // 'project', 'task', 'dm'
  
  final String? projectId;
  final Project? project;
  
  final String? stageId;
  final Stage? stage;
  
  final List<String> participantIds;
  final List<User> members;
  final List<Message> messages;
  
  final Message? lastMessage;
  final DateTime lastMessageAt;
  
  final int unreadCount;
  final DateTime? mutedUntil;
  final String? pinnedMessageId;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatRoom({
    required this.id,
    required this.type,
    this.projectId,
    this.project,
    this.stageId,
    this.stage,
    this.participantIds = const [],
    this.members = const [],
    this.messages = const [],
    this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.mutedUntil,
    this.pinnedMessageId,
    required this.createdAt,
    required this.updatedAt,
  });
}

class TypingStatus {
  final String userId;
  final String roomId;
  final DateTime startedAt;
  final DateTime expiresAt;

  TypingStatus({
    required this.userId,
    required this.roomId,
    required this.startedAt,
    required this.expiresAt,
  });
}

class ChatListItem {
  final String id;
  final String type; // 'project', 'dm'
  
  final String name;
  final String? emoji;
  final String? avatar;
  
  final String? currentStage;
  final String? stageStatus; // 'active', 'testing', 'done'
  final bool isOnline;
  
  final ChatListItemLastMessage? lastMessage;
  
  final int unreadCount;
  final int memberCount;
  final int messageCount;
  
  final List<User> members;
  final bool isMuted;
  final DateTime lastViewedAt;

  ChatListItem({
    required this.id,
    required this.type,
    required this.name,
    this.emoji,
    this.avatar,
    this.currentStage,
    this.stageStatus,
    this.isOnline = false,
    this.lastMessage,
    this.unreadCount = 0,
    this.memberCount = 0,
    this.messageCount = 0,
    this.members = const [],
    this.isMuted = false,
    required this.lastViewedAt,
  });
}

class ChatListItemLastMessage {
  final String text;
  final String authorName;
  final DateTime timestamp;

  ChatListItemLastMessage({
    required this.text,
    required this.authorName,
    required this.timestamp,
  });
}
