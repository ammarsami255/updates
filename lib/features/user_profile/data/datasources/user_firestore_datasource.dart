import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/user_profile.dart';
import '../../../../core/errors/failures.dart';
import '../models/user_profile_model.dart';

/// User Firestore data source
class UserFirestoreDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  UserFirestoreDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get user profile
  Future<({UserProfile? user, Failure? failure})> getUserProfile(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists) {
        return (
          user: null,
          failure: const ValidationFailure(
            message: 'User not found',
            code: 'not_found',
          )
        );
      }

      final up = UserProfileModel.fromFirestore(doc).toEntity();
      return (user: up, failure: null);
    } catch (e) {
      return (
        user: null,
        failure: ServerFailure(
          message: 'Failed to get user: ${e.toString()}',
          code: 'get_user_failed',
        )
      );
    }
  }

  /// Create user profile
  Future<Failure?> createUserProfile({
    required String uid,
    required String name,
    required String email,
  }) async {
    try {
      await _usersCollection.doc(uid).set({
        'uid': uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'isEmailVerified': false,
        'online': false,
        'lastSeen': FieldValue.serverTimestamp(),
        'favoriteIds': <String>[],
      });
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to create user: ${e.toString()}',
        code: 'create_user_failed',
      );
    }
  }

  /// Update user profile
  Future<Failure?> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? companyName,
    String? address,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (phone != null) updates['phone'] = phone;
      if (companyName != null) updates['companyName'] = companyName;
      if (address != null) updates['address'] = address;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _usersCollection.doc(uid).update(updates);
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to update user: ${e.toString()}',
        code: 'update_user_failed',
      );
    }
  }

  /// Set user online status
  Future<Failure?> setUserOnlineStatus(String uid, bool isOnline) async {
    try {
      await _usersCollection.doc(uid).update({
        'online': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to update status: ${e.toString()}',
        code: 'update_status_failed',
      );
    }
  }

  /// Add to favorites
  Future<Failure?> addToFavorites(String uid, String listingId) async {
    try {
      await _usersCollection.doc(uid).update({
        'favoriteIds': FieldValue.arrayUnion([listingId]),
      });
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to add favorite: ${e.toString()}',
        code: 'add_favorite_failed',
      );
    }
  }

  /// Remove from favorites
  Future<Failure?> removeFromFavorites(String uid, String listingId) async {
    try {
      await _usersCollection.doc(uid).update({
        'favoriteIds': FieldValue.arrayRemove([listingId]),
      });
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to remove favorite: ${e.toString()}',
        code: 'remove_favorite_failed',
      );
    }
  }

  /// Check if favorite
  Future<bool> isFavorite(String uid, String listingId) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      final favorites = (doc.data()?['favoriteIds'] as List?)?.cast<String>() ?? [];
      return favorites.contains(listingId);
    } catch (e) {
      return false;
    }
  }
}