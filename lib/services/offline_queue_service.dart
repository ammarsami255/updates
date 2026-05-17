import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'logger_service.dart';

/// Pending message model for offline queue
class PendingMessage {
  final String localId;
  final String chatId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String status; // 'sending', 'sent', 'failed'
  final int retryCount;

  PendingMessage({
    required this.localId,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.status = 'sending',
    this.retryCount = 0,
  });

  PendingMessage copyWith({
    String? status,
    int? retryCount,
  }) {
    return PendingMessage(
      localId: localId,
      chatId: chatId,
      senderId: senderId,
      content: content,
      createdAt: createdAt,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() => {
    'localId': localId,
    'chatId': chatId,
    'senderId': senderId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'status': status,
    'retryCount': retryCount,
  };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
    localId: json['localId'],
    chatId: json['chatId'],
    senderId: json['senderId'],
    content: json['content'],
    createdAt: DateTime.parse(json['createdAt']),
    status: json['status'] ?? 'sending',
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Simple offline message queue using in-memory + SharedPreferences
class OfflineQueueService {
  static const String _storageKey = 'pending_messages';
  
  // In-memory cache for fast access
  static final List<PendingMessage> _queue = [];
  
  static bool _isInitialized = false;
  static bool get hasPending => _queue.any((m) => m.status != 'sent');

  // ==================== QUEUE OPERATIONS ====================

  /// Add message to pending queue
  static Future<void> queueMessage(PendingMessage message) async {
    _queue.add(message);
    await _persist();
    AppLogger.info('Queued message: ${message.localId}');
  }

  /// Get all pending messages for a chat
  static List<PendingMessage> getPendingForChat(String chatId) {
    return _queue
        .where((m) => m.chatId == chatId && m.status != 'sent')
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Get all pending messages (any chat)
  static List<PendingMessage> getAllPending() {
    return _queue.where((m) => m.status != 'sent').toList();
  }

  /// Mark message as sent
  static Future<void> markAsSent(String localId) async {
    final index = _queue.indexWhere((m) => m.localId == localId);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(status: 'sent');
      await _persist();
      AppLogger.info('Message sent: $localId');
    }
    // Remove sent messages from queue
    _queue.removeWhere((m) => m.status == 'sent');
    await _persist();
  }

  /// Mark message as failed
  static Future<void> markAsFailed(String localId) async {
    final index = _queue.indexWhere((m) => m.localId == localId);
    if (index != -1) {
      final msg = _queue[index];
      if (msg.retryCount >= 3) {
        // Max retries reached - remove permanently
        _queue.removeAt(index);
        AppLogger.error('Message failed permanently: $localId');
      } else {
        _queue[index] = msg.copyWith(
          status: 'failed',
          retryCount: msg.retryCount + 1,
        );
        AppLogger.info('Message failed, retry ${msg.retryCount + 1}: $localId');
      }
      await _persist();
    }
  }

  /// Check if message already queued/sent (duplicate prevention)
  static bool hasMessage(String localId) {
    return _queue.any((m) => m.localId == localId);
  }

  /// Retry all failed messages
  static List<PendingMessage> getFailedMessages() {
    return _queue.where((m) => m.status == 'failed' && m.retryCount < 3).toList();
  }

  /// Clear all queued messages (logout)
  static Future<void> clearAll() async {
    _queue.clear();
    await _persist();
    AppLogger.info('Queue cleared');
  }

  // ==================== PERSISTENCE ====================

  /// Load queued messages from storage
  static Future<void> loadQueue() async {
    if (_isInitialized) return;
    
    try {
      // For now use in-memory only - SharedPreferences would be added in real implementation
      _isInitialized = true;
      AppLogger.info('Queue loaded: ${_queue.length} messages');
    } catch (e) {
      AppLogger.error('Queue load error', error: e);
    }
  }

  /// Persist queue to storage (mock - would use SharedPreferences in production)
  static Future<void> _persist() async {
    // In production, this would save to SharedPreferences
    // For now we keep in-memory only
  }

  /// Generate unique local ID for message
  static String generateLocalId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}

/// Extension to convert PendingMessage to chat format for UI
extension PendingMessageToChat on PendingMessage {
  Map<String, dynamic> toChatFormat() {
    return {
      'id': localId,
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'createdAt': TimestampSerializer.toTimestamp(createdAt),
      'isPending': true,
      'status': status,
    };
  }
}

/// Helper to convert DateTime to Firestore timestamp (mock)
class TimestampSerializer {
  static dynamic toTimestamp(DateTime dateTime) {
    // In real implementation, return Firestore timestamp
    return dateTime.millisecondsSinceEpoch;
  }
}