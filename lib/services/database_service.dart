import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'connectivity_service.dart';

/// Simple in-memory cache for user data to reduce Firestore reads
/// Uses 5-minute TTL to keep data fresh while reducing costs
class _UserCache {
  static final Map<String, _CacheEntry<Map<String, dynamic>>> _cache = {};
  static const _cacheDuration = Duration(minutes: 5);
  
  static Map<String, dynamic>? get(String uid) {
    final entry = _cache[uid];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > _cacheDuration) {
      _cache.remove(uid);
      return null;
    }
    return entry.data;
  }
  
  static void set(String uid, Map<String, dynamic> data) {
    _cache[uid] = _CacheEntry(data, DateTime.now());
  }
  
  static void invalidate(String uid) {
    _cache.remove(uid);
  }
  
  static void clear() {
    _cache.clear();
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime timestamp;
  _CacheEntry(this.data, this.timestamp);
}

/// Extended user caches for chat participants
class _ParticipantCache {
  // Cache participant profiles for quick chat list rendering
  static final Map<String, Map<String, dynamic>> _profiles = {};
  
  static Map<String, dynamic>? get(String uid) {
    return _profiles[uid];
  }
  
  static void set(String uid, Map<String, dynamic> profile) {
    _profiles[uid] = profile;
  }
  
  static void clear() {
    _profiles.clear();
  }
}

class DatabaseService {
  DatabaseService._();

  factory DatabaseService() => DatabaseService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  static CollectionReference<Map<String, dynamic>> get _listingsCollection =>
      _firestore.collection('listings');

  static Future<void> createUserDocument({
    required String uid,
    required String name,
    required String email,
  }) {
    return _usersCollection.doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'isEmailVerified': false,
      'online': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  /// Update user online status
  static Future<void> setUserOnlineStatus(String uid, bool isOnline) async {
    await _usersCollection.doc(uid).update({
      'online': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  static Future<Map<String, dynamic>?> getUserDocument(String uid) async {
    // Try cache first
    final cached = _UserCache.get(uid);
    if (cached != null) return cached;
    
    // Don't try to fetch if offline - use null (will use cache or show nothing)
    if (!ConnectivityService.instance.isOnline) {
      return null;
    }
    
    try {
      // Fetch from Firestore if online
      final snapshot = await _usersCollection.doc(uid).get();
      final data = snapshot.data();
      
      // Cache the result
      if (data != null) {
        _UserCache.set(uid, data);
      }
      
      return data;
    } catch (e) {
      // Network error - return null, use cached if available
      return cached;
    }
  }
  
  /// Force refresh user document (bypass cache)
  static Future<Map<String, dynamic>?> refreshUserDocument(String uid) async {
    _UserCache.invalidate(uid);
    return getUserDocument(uid);
  }

  static Stream<Map<String, dynamic>?> watchUserDocument(String uid) {
    return _usersCollection.doc(uid).snapshots().map((snapshot) {
      return snapshot.data();
    });
  }

  /// Get user name by ID (for chat avatars)
  static Future<String> getUserName(String uid) async {
    final user = await getUserDocument(uid);
    return user?['name'] as String? ?? 'User';
  }

  /// Get user profile image URL by ID
  static Future<String?> getUserProfileImage(String uid) async {
    final user = await getUserDocument(uid);
    return user?['profileImage'] as String?;
  }

  /// Check if user's email is verified
  ///优先检查Firebase Auth状态,再检查Firestore
  static Future<bool> isUserEmailVerified(String uid) async {
    // 先检查Firebase Auth的验证状态
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && firebaseUser.emailVerified) {
      return true;
    }
    // 再检查Firestore的自定义验证状态 (from cache if available)
    final user = await getUserDocument(uid);
    return user?['isEmailVerified'] == true;
  }
  
  /// Cache multiple participant profiles at once (batch fetch)
  /// This prevents N+1 when loading chat lists
  static Future<void> cacheParticipantProfiles(List<String> uids) async {
    if (uids.isEmpty) return;
    
    // Filter out already cached
    final uncached = uids.where((uid) => 
      _ParticipantCache.get(uid) == null && _UserCache.get(uid) == null
    ).toList();
    
    if (uncached.isEmpty) return;
    
    // Batch fetch in one query using _in operator (requires composite index)
    // Fallback to parallel fetches for small lists
    final futures = uncached.map((uid) => _usersCollection.doc(uid).get());
    final docs = await Future.wait(futures);
    
    for (final doc in docs) {
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final uid = doc.id;
        _ParticipantCache.set(uid, data);
        _UserCache.set(uid, data); // Also set in main cache
      }
    }
  }
  
  /// Get cached participant profile
  static Map<String, dynamic>? getParticipantProfile(String uid) {
    return _ParticipantCache.get(uid);
  }
  
  /// Clear all user caches (call on logout)
  static void clearUserCache() {
    _UserCache.clear();
    _ParticipantCache.clear();
  }

  /// Update user profile
  static Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    String? companyName,
    String? address,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phone != null) updates['phone'] = phone;
    if (companyName != null) updates['companyName'] = companyName;
    if (address != null) updates['address'] = address;
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _usersCollection.doc(uid).update(updates);
    
    // Invalidate cache so next read gets fresh data
    _UserCache.invalidate(uid);
  }

  /// Mark email as verified
  static Future<void> markEmailVerified(String uid) async {
    await _usersCollection.doc(uid).update({
      'isEmailVerified': true,
      'emailVerifiedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add to favorites
  static Future<void> addToFavorites(String uid, String listingId) async {
    await _usersCollection.doc(uid).update({
      'favoriteIds': FieldValue.arrayUnion([listingId]),
    });
  }

  /// Remove from favorites
  static Future<void> removeFromFavorites(String uid, String listingId) async {
    await _usersCollection.doc(uid).update({
      'favoriteIds': FieldValue.arrayRemove([listingId]),
    });
  }

  /// Check if listing is favorited
  static Future<bool> isFavorite(String uid, String listingId) async {
    final user = await getUserDocument(uid);
    final favorites =
        (user?['favoriteIds'] as List<dynamic>?)?.cast<String>() ?? [];
    return favorites.contains(listingId);
  }

  /// Get favorite listings
  static Future<List<Map<String, dynamic>>> getFavoriteListings(
    String uid,
  ) async {
    final user = await getUserDocument(uid);
    final favorites =
        (user?['favoriteIds'] as List<dynamic>?)?.cast<String>() ?? [];

    if (favorites.isEmpty) return [];

    final futures = favorites.map((id) => _listingsCollection.doc(id).get());
    final snapshots = await Future.wait(futures);
    return snapshots
        .map((s) => s.data())
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  /// Increment view count
  static Future<void> incrementViewCount(String listingId) async {
    // View counts are intentionally not client-controlled.
    return;
  }
}
