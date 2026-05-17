import '../../domain/entities/auth_user.dart';

/// Auth user data model for Firebase
/// This is the DTO (Data Transfer Object) that maps to/from Firestore
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.uid,
    super.email,
    super.displayName,
    super.photoUrl,
    super.isEmailVerified,
    super.createdAt,
  });

  /// Create from Firebase User
  factory AuthUserModel.fromFirebaseUser(
    firebaseUser, {
    DateTime? createdAt,
  }) {
    return AuthUserModel(
      uid: firebaseUser.uid,
      email: firebaseUser.email,
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      isEmailVerified: firebaseUser.emailVerified,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Convert to AuthUser entity
  AuthUser toEntity() {
    return AuthUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoUrl: photoUrl,
      isEmailVerified: isEmailVerified,
      createdAt: createdAt,
    );
  }

  /// Create copy with updated fields
  AuthUserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isEmailVerified,
    DateTime? createdAt,
  }) {
    return AuthUserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}