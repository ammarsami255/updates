import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/listing_entity.dart';

/// Listing model - DTO for Firestore
class ListingModel extends Listing {
  const ListingModel({
    required super.id,
    required super.userId,
    required super.userName,
    required super.phone,
    required super.title,
    required super.description,
    required super.price,
    super.imageUrl,
    super.category,
    super.location,
    super.status,
    required super.createdAt,
    super.updatedAt,
    super.viewCount,
  });

  /// Create from Firestore document
  factory ListingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return ListingModel(
      id: doc.id,
      userId: data?['userId'] as String? ?? '',
      userName: data?['userName'] as String? ?? '',
      phone: data?['phone'] as String? ?? '',
      title: data?['title'] as String? ?? '',
      description: data?['description'] as String? ?? '',
      price: (data?['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: data?['imageUrl'] as String?,
      category: data?['category'] as String?,
      location: data?['location'] as String?,
      status: ListingStatusExtension.fromString(data?['status'] as String? ?? 'active'),
      createdAt: data?['createdAt'] != null
          ? (data!['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data?['updatedAt'] != null
          ? (data!['updatedAt'] as Timestamp).toDate()
          : null,
      viewCount: data?['viewCount'] as int? ?? 0,
    );
  }

  /// Convert to entity
  Listing toEntity() => Listing(
        id: id,
        userId: userId,
        userName: userName,
        phone: phone,
        title: title,
        description: description,
        price: price,
        imageUrl: imageUrl,
        category: category,
        location: location,
        status: status,
        createdAt: createdAt,
        updatedAt: updatedAt,
        viewCount: viewCount,
      );
}