import 'package:equatable/equatable.dart';

/// User profile entity - represents user data in Firestore
class UserProfile extends Equatable {
  final String uid;
  final String name;
  final String? email;
  final String? phone;
  final String? companyName;
  final String? address;
  final String? profileImage;
  final bool isEmailVerified;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;
  final List<String> favoriteIds;

  const UserProfile({
    required this.uid,
    required this.name,
    this.email,
    this.phone,
    this.companyName,
    this.address,
    this.profileImage,
    this.isEmailVerified = false,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
    this.favoriteIds = const [],
  });

  @override
  List<Object?> get props => [
        uid,
        name,
        email,
        phone,
        companyName,
        address,
        profileImage,
        isEmailVerified,
        isOnline,
        lastSeen,
        createdAt,
        favoriteIds,
      ];
}