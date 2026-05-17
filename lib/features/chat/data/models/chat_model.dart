import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/chat_entity.dart';

/// Chat model for Firestore - DTO
class ChatModel extends Chat {
  const ChatModel({
    required super.id,
    required super.participantIds,
    super.participantNames,
    super.listingId,
    super.lastMessage,
    super.lastMessageTime,
    super.createdAt,
    super.typing,
    super.lastSeen,
    super.unreadCount,
  });

  /// Create from Firestore document
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return ChatModel(
      id: doc.id,
      participantIds: (data?['participants'] as List?)?.cast<String>() ?? [],
      participantNames: (data?['participantNames'] as Map?)?.cast<String, String>() ?? {},
      listingId: data?['listingId'] as String?,
      lastMessage: data?['lastMessage'] as String?,
      lastMessageTime: data?['lastMessageTime'] != null
          ? (data!['lastMessageTime'] as Timestamp).toDate()
          : null,
      createdAt: data?['createdAt'] != null
          ? (data!['createdAt'] as Timestamp).toDate()
          : null,
      typing: (data?['typing'] as Map?)?.cast<String, bool>() ?? {},
      lastSeen: (data?['lastSeen'] as Map?)?.cast<String, dynamic>().map(
            (k, v) => MapEntry(
              k,
              v is Timestamp ? v.toDate() : DateTime.now(),
            ),
          ) ??
          {},
      unreadCount: () {
        final map = <String, int>{};
        if (data != null) {
          data.forEach((key, value) {
            if (key.startsWith('unreadCount_')) {
              final uid = key.replaceFirst('unreadCount_', '');
              map[uid] = (value as num?)?.toInt() ?? 0;
            }
          });
        }
        return map;
      }(),
    );
  }

  /// Convert to Chat entity
  Chat toEntity() => Chat(
        id: id,
        participantIds: participantIds,
        participantNames: participantNames,
        listingId: listingId,
        lastMessage: lastMessage,
        lastMessageTime: lastMessageTime,
        createdAt: createdAt,
        typing: typing,
        lastSeen: lastSeen,
        unreadCount: unreadCount,
      );
}

/// Message model for Firestore - DTO
class MessageModel extends Message {
  const MessageModel({
    required super.id,
    required super.chatId,
    required super.senderId,
    required super.content,
    required super.createdAt,
    super.type,
    super.isSeen,
    super.seenAt,
  });

  /// Create from Firestore document
  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return MessageModel(
      id: doc.id,
      chatId: data?['chatId'] as String? ?? '',
      senderId: data?['senderId'] as String? ?? '',
      content: data?['content'] as String? ?? '',
      createdAt: data?['createdAt'] != null
          ? (data!['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      type: MessageType.values.firstWhere(
        (t) => t.name == (data?['type'] as String? ?? 'text'),
        orElse: () => MessageType.text,
      ),
      isSeen: (data?['isSeen'] as bool?) ?? false,
      seenAt: data?['seenAt'] != null
          ? (data!['seenAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Message entity
  Message toEntity() => Message(
        id: id,
        chatId: chatId,
        senderId: senderId,
        content: content,
        createdAt: createdAt,
        type: type,
        isSeen: isSeen,
        seenAt: seenAt,
      );
}