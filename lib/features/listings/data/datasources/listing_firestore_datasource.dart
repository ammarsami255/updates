import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/listing_entity.dart';
import '../../../../core/errors/failures.dart';
import '../models/listing_model.dart';

/// Listing Firestore data source
class ListingFirestoreDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ListingFirestoreDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _listingsCollection =>
      _firestore.collection('listings');

  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get single listing
  Future<({Listing? listing, Failure? failure})> getListing(String id) async {
    try {
      final doc = await _listingsCollection.doc(id).get();
      if (!doc.exists) {
        return (
          listing: null,
          failure: const ValidationFailure(
            message: 'Listing not found',
            code: 'not_found',
          )
        );
      }

      final listing = ListingModel.fromFirestore(doc).toEntity();
      return (listing: listing, failure: null);
    } catch (e) {
      return (
        listing: null,
        failure: ServerFailure(
          message: 'Failed to get listing: ${e.toString()}',
          code: 'get_listing_failed',
        )
      );
    }
  }

  /// Get all active listings with pagination
  Stream<List<Listing>> getListings({
    String? category,
    String? userId,
    int limit = 20,
  }) {
    Query query = _listingsCollection.limit(limit);
    if (category != null) query = query.where('category', isEqualTo: category);
    if (userId != null) query = query.where('userId', isEqualTo: userId);

    return query.snapshots().handleError((e) {
      return [];
    }).map((snapshot) {
      return snapshot.docs.map((doc) {
        return ListingModel.fromFirestore(doc).toEntity();
      }).toList();
    });
  }

  /// Create listing
  Future<({String? id, Failure? failure})> createListing({
    required String userName,
    required String phone,
    required String title,
    required String description,
    required double price,
    String? imageUrl,
    String? category,
    String? location,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return (
        id: null,
        failure: const AuthFailure(
          message: 'Not authenticated',
          code: 'not_authenticated',
        )
      );
    }

    try {
      final docRef = await _listingsCollection.add({
        'userId': userId,
        'userName': userName,
        'phone': phone,
        'title': title,
        'description': description,
        'price': price,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (category != null) 'category': category,
        if (location != null) 'location': location,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'viewCount': 0,
      });

      return (id: docRef.id, failure: null);
    } catch (e) {
      return (
        id: null,
        failure: ServerFailure(
          message: 'Failed to create listing: ${e.toString()}',
          code: 'create_listing_failed',
        )
      );
    }
  }

  /// Update listing
  Future<Failure?> updateListing({
    required String id,
    String? title,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    String? location,
    ListingStatus? status,
  }) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const AuthFailure(
        message: 'Not authenticated',
        code: 'not_authenticated',
      );
    }

    try {
      final doc = await _listingsCollection.doc(id).get();
      if (!doc.exists) {
        return const ValidationFailure(
          message: 'Listing not found',
          code: 'not_found',
        );
      }

      if (doc.data()?['userId'] != userId) {
        return const PermissionFailure(
          message: 'Not authorized',
          code: 'not_authorized',
        );
      }

      final updates = <String, dynamic>{};
      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (price != null) updates['price'] = price;
      if (imageUrl != null) updates['imageUrl'] = imageUrl;
      if (category != null) updates['category'] = category;
      if (location != null) updates['location'] = location;
      if (status != null) updates['status'] = status.name;
      updates['updatedAt'] = FieldValue.serverTimestamp();

      await _listingsCollection.doc(id).update(updates);
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to update listing: ${e.toString()}',
        code: 'update_listing_failed',
      );
    }
  }

  /// Delete listing
  Future<Failure?> deleteListing(String id) async {
    final userId = _currentUserId;
    if (userId == null) {
      return const AuthFailure(
        message: 'Not authenticated',
        code: 'not_authenticated',
      );
    }

    try {
      final doc = await _listingsCollection.doc(id).get();
      if (!doc.exists) {
        return const ValidationFailure(
          message: 'Listing not found',
          code: 'not_found',
        );
      }

      if (doc.data()?['userId'] != userId) {
        return const PermissionFailure(
          message: 'Not authorized',
          code: 'not_authorized',
        );
      }

      await _listingsCollection.doc(id).delete();
      return null;
    } catch (e) {
      return ServerFailure(
        message: 'Failed to delete listing: ${e.toString()}',
        code: 'delete_listing_failed',
      );
    }
  }

  /// Search listings
  Stream<List<Listing>> searchListings(String query, {int limit = 20}) {
    return getListings(limit: limit).map((listings) {
      final q = query.toLowerCase();
      return listings.where((l) {
        return l.title.toLowerCase().contains(q) ||
            l.description.toLowerCase().contains(q);
      }).toList();
    });
  }
}