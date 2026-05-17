import '../entities/user_profile.dart';
import '../../../../core/errors/failures.dart';

/// User repository interface - contract for data layer
abstract class UserRepository {
  /// Get user profile
  Future<({UserProfile? user, Failure? failure})> getUserProfile(String uid);

  /// Create user profile
  Future<Failure?> createUserProfile({
    required String uid,
    required String name,
    required String email,
  });

  /// Update user profile
  Future<Failure?> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? companyName,
    String? address,
  });

  /// Set user online status
  Future<Failure?> setUserOnlineStatus(String uid, bool isOnline);

  /// Add to favorites
  Future<Failure?> addToFavorites(String uid, String listingId);

  /// Remove from favorites
  Future<Failure?> removeFromFavorites(String uid, String listingId);

  /// Check if favorite
  Future<bool> isFavorite(String uid, String listingId);
}