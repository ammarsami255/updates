import 'package:equatable/equatable.dart';

/// Chat entity - represents a chat conversation
class Chat extends Equatable {
  final String id;
  final List<String> participantIds;
  final Map<String, String> participantNames;
  final String? listingId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final DateTime? createdAt;
  final Map<String, bool> typing;
  final Map<String, DateTime> lastSeen;
  final Map<String, int> unreadCount;

  const Chat({
    required this.id,
    required this.participantIds,
    this.participantNames = const {},
    this.listingId,
    this.lastMessage,
    this.lastMessageTime,
    this.createdAt,
    this.typing = const {},
    this.lastSeen = const {},
    this.unreadCount = const {},
  });

  /// Get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    return participantIds.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => participantIds.first,
    );
  }

  /// Check if user is participant
  bool isParticipant(String uid) => participantIds.contains(uid);

  @override
  List<Object?> get props => [
        id,
        participantIds,
        participantNames,
        listingId,
        lastMessage,
        lastMessageTime,
        createdAt,
        typing,
        lastSeen,
        unreadCount,
      ];
}

/// Message entity - represents a chat message
class Message extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final MessageType type;
  final bool isSeen;
  final DateTime? seenAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.type = MessageType.text,
    this.isSeen = false,
    this.seenAt,
  });

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        content,
        createdAt,
        type,
        isSeen,
        seenAt,
      ];
}

enum MessageType { text, image }