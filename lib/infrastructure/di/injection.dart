import 'package:get_it/get_it.dart';

import '../../features/auth/data/datasources/firebase_auth_datasource.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/chat/data/datasources/chat_firestore_datasource.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/listings/data/datasources/listing_firestore_datasource.dart';
import '../../features/listings/domain/repositories/listing_repository.dart';
import '../../features/listings/data/repositories/listing_repository_impl.dart';
import '../../features/user_profile/data/datasources/user_firestore_datasource.dart';
import '../../features/user_profile/domain/repositories/user_repository.dart';
import '../../features/user_profile/data/repositories/user_repository_impl.dart';
import '../../services/database_service.dart';

final getIt = GetIt.instance;

/// Initialize all dependencies using get_it
/// This replaces all static singletons
Future<void> initializeDependencies() async {
  // ==================== DATA SOURCES ====================
  
  // Firebase Auth
  getIt.registerLazySingleton<FirebaseAuthDataSource>(
    () => FirebaseAuthDataSource(),
  );

  // Firestore Data Sources
  getIt.registerLazySingleton<ChatFirestoreDataSource>(
    () => ChatFirestoreDataSource(),
  );
  
  getIt.registerLazySingleton<ListingFirestoreDataSource>(
    () => ListingFirestoreDataSource(),
  );
  
  getIt.registerLazySingleton<UserFirestoreDataSource>(
    () => UserFirestoreDataSource(),
  );

  // ==================== REPOSITORIES ====================
  
  // Register ABSTRACT interfaces with concrete implementations
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(getIt<FirebaseAuthDataSource>()),
  );

  getIt.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(getIt<ChatFirestoreDataSource>()),
  );
  
  getIt.registerLazySingleton<ListingRepository>(
    () => ListingRepositoryImpl(getIt<ListingFirestoreDataSource>()),
  );
  
  getIt.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(getIt<UserFirestoreDataSource>()),
  );

  // Legacy services (temp - migrate to repositories later)
  getIt.registerLazySingleton<DatabaseService>(
    () => DatabaseService(),
  );
}