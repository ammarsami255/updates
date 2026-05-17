import '../entities/chat_entity.dart';
import '../repositories/chat_repository.dart';
import '../../../../core/errors/failures.dart';

/// Use case: Get chat
class GetChatUseCase {
  final ChatRepository _repository;

  GetChatUseCase(this._repository);

  Future<({Chat? chat, Failure? failure})> call(String chatId) {
    return _repository.getChat(chatId);
  }
}

/// Use case: Get or create chat
class GetOrCreateChatUseCase {
  final ChatRepository _repository;

  GetOrCreateChatUseCase(this._repository);

  Future<({String? chatId, Failure? failure})> call({
    required String otherUserId,
    String? listingId,
  }) {
    return _repository.getOrCreateChat(
      otherUserId: otherUserId,
      listingId: listingId,
    );
  }
}

/// Use case: Get my chats with pagination
class GetMyChatsUseCase {
  final ChatRepository _repository;

  GetMyChatsUseCase(this._repository);

  Stream<List<Chat>> call({int limit = 20}) {
    return _repository.getMyChats(limit: limit);
  }
}

/// Use case: Get messages
class GetMessagesUseCase {
  final ChatRepository _repository;

  GetMessagesUseCase(this._repository);

  Stream<List<Message>> call(String chatId, {int limit = 50}) {
    return _repository.getMessages(chatId, limit: limit);
  }
}

/// Use case: Send message
class SendMessageUseCase {
  final ChatRepository _repository;

  SendMessageUseCase(this._repository);

  Future<({String? messageId, Failure? failure})> call({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  }) {
    return _repository.sendMessage(
      chatId: chatId,
      content: content,
      type: type,
    );
  }
}

/// Use case: Delete chat
class DeleteChatUseCase {
  final ChatRepository _repository;

  DeleteChatUseCase(this._repository);

  Future<Failure?> call(String chatId) {
    return _repository.deleteChat(chatId);
  }
}

/// Use case: Mark messages as seen
class MarkMessagesAsSeenUseCase {
  final ChatRepository _repository;

  MarkMessagesAsSeenUseCase(this._repository);

  Future<Failure?> call(String chatId, List<String> messageIds) {
    return _repository.markMessagesAsSeen(chatId, messageIds);
  }
}

/// Use case: Reset unread count
class ResetUnreadCountUseCase {
  final ChatRepository _repository;

  ResetUnreadCountUseCase(this._repository);

  Future<Failure?> call(String chatId) {
    return _repository.resetUnreadCount(chatId);
  }
}