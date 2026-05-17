import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'logger_service.dart';
import 'rate_limiter_service.dart';

/// Custom exception for listing operations
class ListingException implements Exception {
  final String code;
  final String message;
  
  const ListingException(this.code, this.message);
  
  @override
  String toString() => 'ListingException($code): $message';
}

/// Result wrapper for operations with error handling
class ListingResult<T> {
  final T? data;
  final ListingException? error;
  final bool isSuccess;
  
  const ListingResult._({this.data, this.error, required this.isSuccess});
  
  factory ListingResult.success(T data) => ListingResult._(data: data, isSuccess: true);
  factory ListingResult.failure(String code, String message) => ListingResult._(
    error: ListingException(code, message), 
    isSuccess: false
  );
}

class ListingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Pagination settings
  static const int _defaultLimit = 20;
  static const int _maxLimit = 100;
  
  // Retry configuration
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  /// Get single listing by ID
  static Future<Map<String, dynamic>?> getListing(String id) async {
    if (id.isEmpty) return null;
    
    try {
      final doc = await _db.collection('listings').doc(id).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      data['id'] = doc.id;
      return data;
    } catch (e) {
      _logError('getListing', e);
      return null;
    }
  }

  /// Get all listings with SERVER-SIDE filtering
  static Stream<List<Map<String, dynamic>>> getListings({
    String? category,
    String? location,
    int? minPrice,
    int? maxPrice,
    String? searchQuery,
    int? limit,
  }) {
    var query = _db
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true);

    // Apply category filter at Firestore level
    if (category != null && category.isNotEmpty && category != 'الكل') {
      query = query.where('category', isEqualTo: category);
    }

    final queryLimit = limit ?? _defaultLimit;

    return query.limit(queryLimit.clamp(1, _maxLimit)).snapshots().map((snap) {
      var listings = snap.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      // Only do in-memory filtering for text search
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        listings = listings.where((l) {
          final title = (l['title'] as String?)?.toLowerCase() ?? '';
          final desc = (l['description'] as String?)?.toLowerCase() ?? '';
          return title.contains(query) || desc.contains(query);
        }).toList();
      }

      return listings;
    });
  }

  /// Get listings with cursor-based pagination
  static Future<List<Map<String, dynamic>>> getListingsPage({
    String? category,
    String? location,
    int? minPrice,
    int? maxPrice,
    String? searchQuery,
    DocumentSnapshot? lastDoc,
    int pageSize = 20,
  }) async {
    var query = _db
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (lastDoc != null) {
      query = query.startAfterDocument(lastDoc);
    }

    final snapshot = await query.get();
    var listings = snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();

    if (category != null && category.isNotEmpty && category != 'الكل') {
      listings = listings.where((l) => l['category'] == category).toList();
    }

    return listings;
  }

  /// Get current user's listings only
  static Stream<List<Map<String, dynamic>>> getMyListings({int? limit}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return Stream.value([]);
    }

    var query = _db
        .collection('listings')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true);
    
    // Apply limit for scalability
    if (limit != null && limit > 0) {
      query = query.limit(limit);
    } else {
      query = query.limit(100); // Default max for my listings
    }

    return query.snapshots()
        .map(
          (snap) => snap.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList(),
        );
  }

  /// Add listing with retry logic
  static Future<String?> addListing({
    required String title,
    required String description,
    required String category,
    required String type,
    required String price,
    required String location,
    required String phone,
    List<String>? imageUrls,
  }) async {
    // Rate limiting: prevent spam listings
    if (!RateLimiter.canCreateListing) {
      AppLogger.warning('Listing creation blocked - cooldown active');
      return 'Please wait before creating another listing';
    }

    // Validate inputs
    if (title.trim().isEmpty || title.trim().length > 200) {
      return 'Invalid title';
    }
    if (description.trim().isEmpty || description.trim().length > 5000) {
      return 'Invalid description';
    }
    if (category.trim().isEmpty || category.trim().length > 50) {
      return 'Invalid category';
    }
    if (type.trim().isEmpty || type.trim().length > 50) {
      return 'Invalid type';
    }
    if (price.trim().isEmpty || price.trim().length > 20) {
      return 'Invalid price';
    }
    if (location.trim().isEmpty || location.trim().length > 100) {
      return 'Invalid location';
    }
    if (phone.trim().isEmpty || phone.trim().length > 20) {
      return 'Invalid phone';
    }

    // Retry logic
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          return 'User not authenticated';
        }

        await _db.collection('listings').add({
          'title': title.trim(),
          'description': description.trim(),
          'category': category.trim(),
          'type': type.trim(),
          'price': price.trim(),
          'location': location.trim(),
          'phone': phone.trim(),
          'userId': user.uid,
          'userName': user.displayName ?? '',
          'imageUrls': imageUrls ?? [],
          'status': 'active',
          'viewCount': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        return null;
      } catch (e) {
        _logError('addListing', e);
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      }
    }
    return 'فشل النشر، حاول تاني';
  }

  static Future<void> deleteListing(String id) async {
    await _db.collection('listings').doc(id).delete();
  }

  /// FIXED: Use atomic increment for view count with rate limiting
  static Future<void> incrementViewCount(String listingId) async {
    if (listingId.isEmpty) return;
    
    // Rate limiting: prevent view count abuse
    if (!RateLimiter.canIncrementViewCount) {
      return; // Silently skip - not critical
    }
    if (RateLimiter.isViewCountRateLimited) {
      return; // Silently skip - not critical
    }
    
    try {
      await _db.collection('listings').doc(listingId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      _logError('incrementViewCount', e);
    }
  }

  static Future<int> getUserListingsCount(String userId) async {
    try {
      final snap = await _db
          .collection('listings')
          .where('userId', isEqualTo: userId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      _logError('getUserListingsCount', e);
      return 0;
    }
  }

  static Future<int> getUserTotalViews(String userId) async {
    // Limit query to prevent large collection reads
    try {
      final snap = await _db
          .collection('listings')
          .where('userId', isEqualTo: userId)
          .limit(100)  // Limit to prevent large reads
          .get();

      int totalViews = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        totalViews += (data['viewCount'] as int?) ?? 0;
      }
      return totalViews;
    } catch (e) {
      _logError('getUserTotalViews', e);
      return 0;
    }
  }
  
  static void _logError(String operation, dynamic error) {
    assert(() {
      print('ListingService.$operation error: $error');
      return true;
    }());
  }
}