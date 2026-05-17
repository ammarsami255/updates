import 'package:el_moza3/infrastructure/di/injection.dart';
import '../../domain/entities/chat_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/errors/failures.dart';
import '../../../user_profile/domain/repositories/user_repository.dart';
import '../datasources/chat_firestore_datasource.dart';

/// Chat repository implementation - implements abstract repository from domain
class ChatRepositoryImpl implements ChatRepository {
  final ChatFirestoreDataSource _dataSource;

  ChatRepositoryImpl(this._dataSource);

  @override
  Future<({Chat? chat, Failure? failure})> getChat(String chatId) {
    return _dataSource.getChat(chatId);
  }

  @override
  Future<({String? chatId, Failure? failure})> getOrCreateChat({
    required String otherUserId,
    String? listingId,
    String? otherUserName,
  }) async {
    // Use provided name, or fetch from UserRepository if not provided
    final nameToUse = otherUserName ?? (await getIt<UserRepository>().getUserProfile(otherUserId)).user?.name;
    
    return _dataSource.getOrCreateChat(
      otherUserId: otherUserId,
      listingId: listingId,
      otherUserName: nameToUse,
    );
  }

  @override
  Stream<List<Chat>> getMyChats({int limit = 20}) {
    return _dataSource.getMyChats(limit: limit);
  }

  @override
  Stream<List<Message>> getMessages(String chatId, {int limit = 50}) {
    return _dataSource.getMessages(chatId, limit: limit);
  }

  @override
  Future<({String? messageId, Failure? failure})> sendMessage({
    required String chatId,
    required String content,
    MessageType type = MessageType.text,
  }) {
    final senderId = _dataSource.currentUserId;
    if (senderId == null || senderId.isEmpty) {
      return Future.value((
        messageId: null,
        failure: const AuthFailure(
          message: 'User not authenticated',
          code: 'not_authenticated',
        ),
      ));
    }
    return _dataSource.sendMessage(
      chatId: chatId,
      senderId: senderId,
      content: content,
      type: type,
    );
  }

  @override
  Future<Failure?> deleteChat(String chatId) {
    return _dataSource.deleteChat(chatId);
  }

  @override
  Future<Failure?> markMessagesAsSeen(String chatId, List<String> messageIds) {
    return _dataSource.markMessagesAsSeen(chatId, messageIds);
  }

  @override
  Future<Failure?> resetUnreadCount(String chatId) {
    return _dataSource.resetUnreadCount(chatId);
  }

  @override
  Stream<int> getUnreadCountStream() {
    return _dataSource.getUnreadCountStream();
  }

  @override
  Stream<int> getUnreadChatsCountStream() {
    return _dataSource.getUnreadCountStream();
  }
}