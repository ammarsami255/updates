import '../../domain/entities/chat_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../../../../core/errors/failures.dart';

/// Use case: Get all chats
GetMyChatsUseCase getGetMyChatsUseCase(ChatRepository repository) {
  return GetMyChatsUseCase(repository);
}

/// Use case: Get messages
GetMessagesUseCase getGetMessagesUseCase(ChatRepository repository) {
  return GetMessagesUseCase(repository);
}

/// Use case: Send message
SendMessageUseCase getSendMessageUseCase(ChatRepository repository) {
  return SendMessageUseCase(repository);
}

/// Use case: Mark as seen
MarkMessagesAsSeenUseCase getMarkMessagesAsSeenUseCase(ChatRepository repository) {
  return MarkMessagesAsSeenUseCase(repository);
}