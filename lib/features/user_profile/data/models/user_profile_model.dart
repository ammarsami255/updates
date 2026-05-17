import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';

/// User profile model - DTO for Firestore
class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.uid,
    required super.name,
    super.email,
    super.phone,
    super.companyName,
    super.address,
    super.profileImage,
    super.isEmailVerified,
    super.isOnline,
    super.lastSeen,
    required super.createdAt,
    super.favoriteIds,
  });

  /// Create from Firestore document
  factory UserProfileModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return UserProfileModel(
      uid: doc.id,
      name: data?['name'] as String? ?? '',
      email: data?['email'] as String?,
      phone: data?['phone'] as String?,
      companyName: data?['companyName'] as String?,
      address: data?['address'] as String?,
      profileImage: data?['profileImage'] as String?,
      isEmailVerified: data?['isEmailVerified'] as bool? ?? false,
      isOnline: data?['online'] as bool? ?? false,
      lastSeen: data?['lastSeen'] != null
          ? (data!['lastSeen'] as Timestamp).toDate()
          : null,
      createdAt: data?['createdAt'] != null
          ? (data!['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      favoriteIds: (data?['favoriteIds'] as List?)?.cast<String>() ?? [],
    );
  }

  /// Convert to entity
  UserProfile toEntity() => UserProfile(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        companyName: companyName,
        address: address,
        profileImage: profileImage,
        isEmailVerified: isEmailVerified,
        isOnline: isOnline,
        lastSeen: lastSeen,
        createdAt: createdAt,
        favoriteIds: favoriteIds,
      );
}