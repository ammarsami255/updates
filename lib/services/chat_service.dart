import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:el_moza3/models/chat_model.dart';
import 'logger_service.dart';
import 'rate_limiter_service.dart';
import 'connectivity_service.dart';
import 'offline_queue_service.dart';

/// Custom exception for chat operations
class ChatException implements Exception {
  final String code;
  final String message;
  
  const ChatException(this.code, this.message);
  
  @override
  String toString() => 'ChatException($code): $message';
}

class ChatService {
  ChatService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;

  static CollectionReference<Map<String, dynamic>> get _chatsCollection =>
      _firestore.collection('chats');

  static CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  static String? get _currentUserId => _auth.currentUser?.uid;

  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  
  // Simple cache for user names to reduce reads (cleared on app restart)
  static final Map<String, String> _userNameCache = {};
  
  /// Get cached user name or fetch from Firestore
  static Future<String> getUserName(String uid) async {
    // Check cache first
    if (_userNameCache.containsKey(uid)) {
      return _userNameCache[uid]!;
    }
    
    // Fetch from Firestore if not cached
    try {
      final doc = await _usersCollection.doc(uid).get();
      final name = doc.data()?['name'] as String? ?? 'User';
      _userNameCache[uid] = name;
      return name;
    } catch (e) {
      return 'User';
    }
  }
  
  /// Clear user name cache (call on logout)
  static void clearUserCache() {
    _userNameCache.clear();
  }
  
  // ==================== CHAT MANAGEMENT ====================

  static Future<String?> getOrCreateChat(
    String otherUserId, {
    String? listingId,
    String? otherUserName,
  }) async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || otherUserId.isEmpty) return null;

    final participants = [currentUserId, otherUserId]..sort();
    final chatId = '${participants[0]}_${participants[1]}';

    // Retry logic
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final chatDoc = await _chatsCollection.doc(chatId).get();
        if (chatDoc.exists) {
          final existingParticipants =
              (chatDoc.data()?['participants'] as List<dynamic>?)
                  ?.cast<String>() ??
              [];
          if (existingParticipants.contains(currentUserId) &&
              existingParticipants.contains(otherUserId)) {
            return chatId;
          }
        }
        
        // Create new chat
        await _chatsCollection.doc(chatId).set({
          'participants': participants,
          'participantNames': {
            currentUserId:
                _auth.currentUser?.displayName ??
                _auth.currentUser?.email?.split('@').first ??
                'User',
            otherUserId: otherUserName ?? 'User',
          },
          if (listingId != null) 'listingId': listingId,
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'typing': {},
          'lastSeen': {},
          'unreadCount_$currentUserId': 0,
          'unreadCount_$otherUserId': 0,
        });
        return chatId;
      } catch (e) {
        _logError('getOrCreateChat', e);
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      }
    }
    return null;
  }

  static Future<ChatModel?> getChat(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) return null;
      return ChatModel.fromFirestore(doc);
    } catch (e) {
      _logError('getChat', e);
      return null;
    }
  }

  static Future<void> deleteChat(String chatId) async {
    try {
      final messages = await _chatsCollection
          .doc(chatId)
          .collection('messages')
          .get();
      final batch = _firestore.batch();
      for (final msg in messages.docs) {
        batch.delete(msg.reference);
      }
      batch.delete(_chatsCollection.doc(chatId));
      await batch.commit();
    } catch (e) {
      _logError('deleteChat', e);
    }
  }

  // ==================== STREAMS WITH PROPER ERROR HANDLING ====================
  
  // Default chat list limit to reduce initial load
  static const int _defaultChatLimit = 50;

  static Stream<List<Map<String, dynamic>>> getMyChats({int? limit}) {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value([]);
    }

    // Apply limit to prevent loading too many chats
    var query = _chatsCollection
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true);
    
    // Apply limit if specified
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    } else {
      query = query.limit(_defaultChatLimit);
    }

    return query.snapshots()
        .handleError((e) {
          // Handle stream errors gracefully
          print('ChatService.getMyChats error: $e');
          return <Map<String, dynamic>>[]; // Return empty on error
        })
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            
            final unreadField = data['unreadCount_$userId'];
            final unreadMap = data['unreadCount'] as Map<dynamic, dynamic>?;

            if (unreadField != null) {
              data['unreadCount'] = (unreadField as num).toInt();
            } else if (unreadMap != null && unreadMap[userId] != null) {
              data['unreadCount'] = unreadMap[userId].toString();
            } else {
              data['unreadCount'] = 0;
            }
            return data;
          }).toList();
        });
  }

  static Stream<List<Map<String, dynamic>>> getMessages(
    String chatId, {
    int limit = 50,
  }) {
    return _chatsCollection
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .handleError((e) {
          // Handle stream errors gracefully
          print('ChatService.getMessages error: $e');
          return <Map<String, dynamic>>[]; // Return empty on error
        })
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            
            // Support old seenBy array
            if (data['isSeen'] == null) {
              final seenBy = data['seenBy'] as List<dynamic>? ?? [];
              data['isSeen'] = seenBy.isNotEmpty;
            }
            
            return data;
          }).toList(),
        );
  }

  // ==================== SEND MESSAGES ====================

  static Future<String?> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  }) async {
    final userId = _currentUserId;
    if (userId == null || content.trim().isEmpty) return null;

    // Rate limiting: prevent spam
    if (!RateLimiter.canSendMessage) {
      AppLogger.warning('Message send blocked - cooldown active');
      return null;
    }
    if (RateLimiter.isMessageRateLimited) {
      AppLogger.warning('Message send blocked - rate limit exceeded');
      return null;
    }

    // Generate local ID first (for offline queue)
    final localId = OfflineQueueService.generateLocalId();
    
    // IMMEDIATELY queue locally for offline-first UX
    final pendingMsg = PendingMessage(
      localId: localId,
      chatId: chatId,
      senderId: userId,
      content: content.trim(),
      createdAt: DateTime.now(),
      status: 'sending',
    );
    await OfflineQueueService.queueMessage(pendingMsg);
    
    // If offline, return local ID immediately
    if (!ConnectivityService.instance.isOnline) {
      AppLogger.info('Message queued offline: $localId');
      return localId;
    }

    // Try to send via Firestore
    bool success = false;
    String? messageId;
    
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final chatDoc = await _chatsCollection.doc(chatId).get();
        if (!chatDoc.exists) {
          await OfflineQueueService.markAsFailed(localId);
          return null;
        }

        final participants =
            (chatDoc.data()?['participants'] as List<dynamic>?)?.cast<String>() ??
            [];
        if (!participants.contains(userId)) {
          await OfflineQueueService.markAsFailed(localId);
          return null;
        }

        final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');
        if (otherUserId.isEmpty) {
          await OfflineQueueService.markAsFailed(localId);
          return null;
        }

        await _firestore.runTransaction((transaction) async {
          final chat = await transaction.get(_chatsCollection.doc(chatId));
          if (!chat.exists) return;

          final messageRef = _chatsCollection
              .doc(chatId)
              .collection('messages')
              .doc();
              
          transaction.set(messageRef, {
            'chatId': chatId,
            'senderId': userId,
            'content': content.trim(),
            'type': type.name,
            'createdAt': FieldValue.serverTimestamp(),
            'isSeen': false,
            'seenAt': null,
            'localId': localId, // Store for duplicate prevention
          });
          messageId = messageRef.id;

          transaction.update(_chatsCollection.doc(chatId), {
            'lastMessage': content.trim(),
            'lastMessageTime': FieldValue.serverTimestamp(),
            'unreadCount_$otherUserId': FieldValue.increment(1),
          });
        });

        success = true;
        break;
      } catch (e) {
        _logError('sendMessage', e);
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      }
    }
    
    // Mark in queue
    if (success) {
      await OfflineQueueService.markAsSent(localId);
      AppLogger.info('Message sent successfully: $messageId');
      return messageId;
    } else {
      await OfflineQueueService.markAsFailed(localId);
      return localId; // Still return localId so UI shows pending
    }
  }

  static Future<String?> sendImageMessage({
    required String chatId,
    required String imageUrl,
  }) async {
    return sendMessage(
      chatId: chatId,
      content: imageUrl,
      type: MessageType.image,
    );
  }

  // ==================== SEEN SYSTEM ====================

  static Future<void> resetUnreadCount(String chatId) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _chatsCollection.doc(chatId).update({
        'unreadCount_$userId': 0,
        'lastSeen.$userId': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logError('resetUnreadCount', e);
    }
  }

  static Future<void> markMessagesAsSeen(String chatId, List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    
    try {
      final batch = _firestore.batch();
      
      for (final msgId in messageIds) {
        batch.update(_chatsCollection.doc(chatId).collection('messages').doc(msgId), {
          'isSeen': true,
          'seenAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      _logError('markMessagesAsSeen', e);
    }
  }

  // ==================== PRESENCE ====================

  static StreamSubscription? _presenceSubscription;

  static Future<void> setOnline() async {
    initializePresence();
  }

  static void initializePresence() {
    final userId = _currentUserId;
    if (userId == null) return;

    // Clean up previous subscription
    _presenceSubscription?.cancel();

    final connectedRef = _database.ref('.info/connected');
    final userStatusRef = _database.ref('status/$userId');

    _presenceSubscription = connectedRef.onValue.listen((event) {
      if (event.snapshot.value == true) {
        userStatusRef.onDisconnect().set({
          'online': false,
          'lastSeen': ServerValue.timestamp,
        }).then((_) {
          userStatusRef.set({
            'online': true,
            'lastSeen': ServerValue.timestamp,
          });
          
          _usersCollection.doc(userId).update({
            'online': true,
            'lastSeen': FieldValue.serverTimestamp(),
          }).catchError((_) {});
        });
      }
    });
  }

  static Future<void> setOffline() async {
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
    
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _database.ref('status/$userId').set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
      
      await _usersCollection.doc(userId).update({
        'online': false,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((_) {});
    } catch (e) {
      _logError('setOffline', e);
    }
  }

  static Stream<Map<String, dynamic>> getUserPresenceStream(String userId) {
    return _database.ref('status/$userId').onValue.map((event) {
      if (event.snapshot.value == null) return {'online': false, 'lastSeen': null};
      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      return {
        'online': data['online'] == true,
        'lastSeen': data['lastSeen'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(data['lastSeen'] as int) 
            : null,
      };
    });
  }

  // ==================== TYPING INDICATOR ====================

  static Future<void> setTyping(String chatId, bool isTyping) async {
    final userId = _currentUserId;
    if (userId == null) return;
    try {
      await _chatsCollection.doc(chatId).update({'typing.$userId': isTyping});
    } catch (e) {
      _logError('setTyping', e);
    }
  }

  static Stream<Map<String, bool>> getTypingStatus(String chatId) {
    return _chatsCollection.doc(chatId).snapshots().map((doc) {
      final data = doc.data() ?? {};
      final typing =
          (data['typing'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), v as bool),
          ) ??
          {};
      return Map<String, bool>.from(typing);
    });
  }

  // ==================== CHAT BADGE (FIXED: No more N+1 queries) ====================

  static Stream<int> getUnreadCountStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);

    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int total = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unreadField = data['unreadCount_$userId'];
            final unreadMap = data['unreadCount'] as Map<dynamic, dynamic>?;
            
            if (unreadField != null) {
              total += (unreadField as num).toInt();
            } else if (unreadMap != null && unreadMap[userId] != null) {
              total += (unreadMap[userId] as num).toInt();
            }
          }
          return total;
        });
  }

  static Stream<int> getUnreadChatsStream() {
    final userId = _currentUserId;
    if (userId == null) return Stream.value(0);

    return _chatsCollection
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          int count = 0;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final unreadField = data['unreadCount_$userId'];
            final unreadMap = data['unreadCount'] as Map<dynamic, dynamic>?;
            
            int unread = 0;
            if (unreadField != null) {
              unread = (unreadField as num).toInt();
            } else if (unreadMap != null && unreadMap[userId] != null) {
              unread = (unreadMap[userId] as num).toInt();
            }
            if (unread > 0) count++;
          }
          return count;
        });
  }

  static Future<List<String>> getParticipants(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      return (doc.data()?['participants'] as List<dynamic>?)?.cast<String>() ?? [];
    } catch (e) {
      _logError('getParticipants', e);
      return [];
    }
  }

  /// Get chat with participant details
  static Future<Map<String, dynamic>?> getChatWithParticipantDetails(String chatId) async {
    try {
      final doc = await _chatsCollection.doc(chatId).get();
      if (!doc.exists) return null;
      return doc.data();
    } catch (e) {
      _logError('getChatWithParticipantDetails', e);
      return null;
    }
  }
  
  /// Clean up resources - call this when done with the service
  static void dispose() {
    _presenceSubscription?.cancel();
    _presenceSubscription = null;
  }
  
  static void _logError(String operation, dynamic error) {
    assert(() {
      print('ChatService.$operation error: $error');
      return true;
    }());
  }
}