import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/user_firestore_datasource.dart';

/// User repository implementation
class UserRepositoryImpl implements UserRepository {
  final UserFirestoreDataSource _dataSource;

  UserRepositoryImpl(this._dataSource);

  @override
  Future<({UserProfile? user, Failure? failure})> getUserProfile(String uid) {
    return _dataSource.getUserProfile(uid);
  }

  @override
  Future<Failure?> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) {
    return _dataSource.createUserProfile(uid: uid, name: name, email: email);
  }

  @override
  Future<Failure?> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? companyName,
    String? address,
  }) {
    return _dataSource.updateUserProfile(
      uid: uid,
      name: name,
      phone: phone,
      companyName: companyName,
      address: address,
    );
  }

  @override
  Future<Failure?> setUserOnlineStatus(String uid, bool isOnline) {
    return _dataSource.setUserOnlineStatus(uid, isOnline);
  }

  @override
  Future<Failure?> addToFavorites(String uid, String listingId) {
    return _dataSource.addToFavorites(uid, listingId);
  }

  @override
  Future<Failure?> removeFromFavorites(String uid, String listingId) {
    return _dataSource.removeFromFavorites(uid, listingId);
  }

  @override
  Future<bool> isFavorite(String uid, String listingId) {
    return _dataSource.isFavorite(uid, listingId);
  }
}