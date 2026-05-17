import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/chat_entity.dart';
import '../../../../core/errors/failures.dart';
import '../models/chat_model.dart';

/// Firebase Firestore data source for Chat
/// ONLY place where Firestore chat operations exist
class ChatFirestoreDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ChatFirestoreDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  /// Public getter for current user ID (fixes encapsulation)
  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== CHAT OPERATIONS ====================

  Future<({Chat? chat, Failure? failure})> getChat(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) {
        return (
          chat: null,
          failure: const ValidationFailure(
            message: 'Chat not found',
            code: 'chat_not_found',
          )
        );
      }

      final chat = ChatModel.fromFirestore(doc).toEntity();
      return (chat: chat, failure: null);
    } catch (e) {
      return (
        chat: null,
        failure: ServerFailure(
          message: 'Failed to get chat: ${e.toString()}',
          code: 'get_chat_failed',
        )
      );
    }
  }

  Future<({String? chatId, Failure? failure})> getOrCreateChat({
    required String otherUserId,
    String? listingId,
    String? otherUserName,
  }) async {
    final uid = currentUserId;
    if (uid == null || otherUserId.isEmpty) {
      return (
        chatId: null,
        failure: const AuthFailure(
          message: 'Not authenticated',
          code: 'not_authenticated',
        )
      );
    }

    try {
      final participants = [uid, otherUserId]..sort();
      final chatId = '${participants[0]}_${participants[1]}';

      final chatDoc = await _chatsCollection.doc(chatId).get();
      if (chatDoc.exists) {
        final existingParticipants =
            (chatDoc.data()?['participants'] as List?)?.cast<String>() ?? [];
        if (existingParticipants.contains(uid) &&
            existingParticipants.contains(otherUserId)) {
          return (chatId: chatId, failure: null);
        }
      }

      // Create new chat - fetch user names from Firestore
      String currentUserName = _auth.currentUser?.displayName ?? _auth.currentUser?.email?.split('@').first ?? 'User';
      String fetchedOtherName = otherUserName ?? 'User';
      try {
        // Fetch current user's name from Firestore
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data()?['name'] != null) {
          currentUserName = userDoc.data()!['name'] as String;
        }
      } catch (_) {
        // Fall back to displayName/email if Firestore fetch fails
      }
      try {
        // Fetch other user's name from Firestore
        final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
        if (otherUserDoc.exists && otherUserDoc.data()?['name'] != null) {
          fetchedOtherName = otherUserDoc.data()!['name'] as String;
        }
      } catch (_) {
        // Fall back to provided name if Firestore fetch fails
      }
      
      await _chatsCollection.doc(chatId).set({
        'participants': participants,
        'participantNames': {
          uid: currentUserName,
          otherUserId: fetchedOtherName,
        },
        if (listingId != null) 'listingId': listingId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'typing': <String, bool>{},
        'lastSeen': <String, dynamic>{},
        'unreadCount_$uid': 0,
        'unreadCount_$otherUserId': 0,
      });

      return (chatId: chatId, failure: null);
    } catch (e) {
      return (
        chatId: null,
        failure: ServerFailure(
          message: 'Failed to create chat: ${e.toString()}',
          code: 'create_chat_failed',
        )
      );
    }
  }

  Stream<List<Chat>> getMyChats({int limit = 20}) {
    final userId = currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    return _chatsCollection
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((e) {
          return [];
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => ChatModel.fromFirestore(doc).toEntity())
              .toList();
        });
  }

  Stream<List<Message>> getMessages(String chatId, {int limit = 50}) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((e) {
          return [];
        })
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc).toEntity())
              .toList();
        });
  }

  Future<({String? messageId, Failure? failure})> sendMessage({
    required String chatId,
    required String senderId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    try {
      String? newMessageId;

      await _firestore.runTransaction((transaction) async {
        final chatRef = _chatsCollection.doc(chatId);
        final chatDoc = await transaction.get(chatRef);

        if (!chatDoc.exists) {
          throw Exception('Chat not found');
        }

        final participants =
            (chatDoc.data()?['participants'] as List?)?.cast<String>() ?? [];

        if (!participants.contains(senderId)) {
          throw Exception('User not in chat');
        }

        final otherUserId = participants.firstWhere(
          (uid) => uid != senderId,
          orElse: () => '',
        );

        final messageRef = chatRef.collection('messages').doc();
        newMessageId = messageRef.id;

        transaction.set(messageRef, {
          'chatId': chatId,
          'senderId': senderId,
          'content': content,
          'type': type.name,
          'createdAt': FieldValue.serverTimestamp(),
          'isSeen': false,
          'seenAt': null,
        });

        transaction.update(chatRef, {
          'lastMessage': content,
          'lastMessageTime': FieldValue.serverTimestamp(),
          if (otherUserId.isNotEmpty)
            'unreadCount_$otherUserId': FieldValue.increment(1),
        });
      });

      return (messageId: newMessageId, failure: null);
    } catch (e) {
      return (
        messageId: null,
        failure: ServerFailure(
          message: 'Failed to send message: ${e.toString()}',
          code: 'send_message_failed',
        )
      );
    }
  }

  Future<Failure?> deleteChat(String chatId) async {
    try {
      final messages = await _chatsCollection.doc(chatId).collection('messages').get();
      final batch = _firestore.batch();
      for (final msg in messages.docs) {
        batch.delete(msg.reference);
      }
      batch.delete(_chatsCollection.doc(chatId));
      await batch.commit();
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to delete chat: ${e.toString()}',
        code: 'delete_chat_failed',
      );
    }
  }

  Future<Failure?> markMessagesAsSeen(String chatId, List<String> messageIds) async {
    try {
      final batch = _firestore.batch();
      for (final msgId in messageIds) {
        batch.update(
          _chatsCollection.doc(chatId).collection('messages').doc(msgId),
          {
            'isSeen': true,
            'seenAt': FieldValue.serverTimestamp(),
          },
        );
      }
      await batch.commit();
      await resetUnreadCount(chatId);
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to mark messages as seen: ${e.toString()}',
        code: 'mark_seen_failed',
      );
    }
  }

  Future<Failure?> resetUnreadCount(String chatId) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      await _chatsCollection.doc(chatId).update({
        'unreadCount_$userId': 0,
        'lastSeen.$userId': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to reset unread count: ${e.toString()}',
        code: 'reset_unread_failed',
      );
    }
  }

  Stream<int> getUnreadCountStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value(0);

    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unreadField = data['unreadCount_$userId'];
            if (unreadField != null) {
              total += (unreadField as num).toInt();
            }
          }
          return total;
        });
  }
}