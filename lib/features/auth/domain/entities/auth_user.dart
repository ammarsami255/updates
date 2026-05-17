import 'package:equatable/equatable.dart';

/// Auth user entity
class AuthUser extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isEmailVerified;
  final DateTime? createdAt;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isEmailVerified = false,
    this.createdAt,
  });

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, isEmailVerified, createdAt];

  /// Empty user for initial states
  static const AuthUser empty = AuthUser(uid: '');
}