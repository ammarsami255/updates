import '../entities/auth_user.dart';
import '../../../../core/errors/failures.dart';

/// Extension to provide AuthResult-like interface
extension AuthRepositoryResultExt on ({AuthUser? user, Failure? failure}) {
  bool get isSuccess => failure == null && user != null;
  bool get requiresVerification => failure is EmailVerificationFailure;
  String? get errorMessage => failure?.message;
}

/// Abstract auth repository - NO Firebase code here
/// This is the contract that the data layer must implement
abstract class AuthRepository {
  /// Get current authenticated user
  Future<({AuthUser? user, Failure? failure})> getCurrentUser();

  /// Sign in with email and password
  Future<({AuthUser user, Failure? failure})> signInWithEmail({
    required String email,
    required String password,
  });

  /// Sign in with Google
  Future<({AuthUser user, Failure? failure})> signInWithGoogle();

  /// Register with email and password
  Future<({AuthUser user, Failure? failure})> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  /// Sign out
  Future<Failure?> signOut();

  /// Send password reset email
  Future<Failure?> sendPasswordReset(String email);

  /// Send verification email
  Future<Failure?> sendVerificationEmail();

  /// Check if user is verified
  Future<({bool isVerified, Failure? failure})> isUserVerified();

  /// Stream of auth state changes
  Stream<AuthUser?> get authStateChanges;

  /// Check if currently logged in
  bool get isLoggedIn;

  /// Get current user ID directly (sync)
  String? get currentUserId;
}