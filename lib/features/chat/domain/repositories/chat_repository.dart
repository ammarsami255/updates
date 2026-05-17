import '../entities/chat_entity.dart';
import '../../../../core/errors/failures.dart';

/// Chat repository interface
/// NO Firebase code here - this is the contract
abstract class ChatRepository {
  /// Get chat by ID
  Future<({Chat? chat, Failure? failure})> getChat(String chatId);

  /// Get or create chat with another user
  Future<({String? chatId, Failure? failure})> getOrCreateChat({
    required String otherUserId,
    String? listingId,
    String? otherUserName,
  });

  /// Get all chats for current user with pagination
  Stream<List<Chat>> getMyChats({int limit = 20});

  /// Get messages for a chat with pagination
  Stream<List<Message>> getMessages(String chatId, {int limit = 50});

  /// Send a message
  Future<({String? messageId, Failure? failure})> sendMessage({
    required String chatId,
    required String content,
    MessageType type,
  });

  /// Delete a chat
  Future<Failure?> deleteChat(String chatId);

  /// Mark messages as seen
  Future<Failure?> markMessagesAsSeen(String chatId, List<String> messageIds);

  /// Reset unread count
  Future<Failure?> resetUnreadCount(String chatId);

  /// Get unread count stream
  Stream<int> getUnreadCountStream();

  /// Get unread chats count stream
  Stream<int> getUnreadChatsCountStream();
}