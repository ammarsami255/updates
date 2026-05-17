import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/errors/failures.dart';
import '../datasources/firebase_auth_datasource.dart';
import '../models/auth_user_model.dart';

/// Concrete auth repository implementation
/// Implements the abstract repository from domain layer
class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuthDataSource _dataSource;

  AuthRepositoryImpl(this._dataSource);

  @override
  bool get isLoggedIn => _dataSource.isLoggedIn;

  @override
  String? get currentUserId => _dataSource.currentUser?.uid;

  @override
  Stream<AuthUser?> get authStateChanges =>
      _dataSource.authStateChanges.map((user) {
        if (user == null) return null;
        return AuthUserModel.fromFirebaseUser(user).toEntity();
      });

  @override
  Future<({AuthUser? user, Failure? failure})> getCurrentUser() async {
    try {
      final firebaseUser = _dataSource.currentUser;
      if (firebaseUser == null) {
        return (user: null, failure: null);
      }

      final user = AuthUserModel.fromFirebaseUser(firebaseUser).toEntity();
      return (user: user, failure: null);
    } catch (e) {
      return (
        user: null,
        failure: AuthFailure(
          message: 'Failed to get current user: ${e.toString()}',
          code: 'get_current_user_failed',
        )
      );
    }
  }

  @override
  Future<({AuthUser user, Failure? failure})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _dataSource.signInWithEmail(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return (
          user: AuthUser.empty,
          failure: AuthFailure(
            message: 'Login failed. Please try again.',
            code: 'login_failed',
          )
        );
      }

      // Reload to get verification status
      await _dataSource.reload();

      // Check if email is verified
      if (!user.emailVerified) {
        final authUser = AuthUserModel.fromFirebaseUser(user).toEntity();
        return (
          user: authUser,
          failure: EmailVerificationFailure(
            message: 'Please verify your email to continue.',
            code: 'email_not_verified',
          )
        );
      }

      final authUser = AuthUserModel.fromFirebaseUser(user).toEntity();
      return (user: authUser, failure: null);
    } on FirebaseAuthException catch (e) {
      return (
        user: AuthUser.empty,
        failure: AuthFailure(
          message: _mapFirebaseError(e.code),
          code: e.code,
        )
      );
    } catch (e) {
      return (
        user: AuthUser.empty,
        failure: AuthFailure(
          message: 'Login failed. Please try again.',
          code: 'login_failed',
        )
      );
    }
  }

  @override
  Future<({AuthUser user, Failure? failure})> signInWithGoogle() async {
    try {
      final credential = await _dataSource.signInWithGoogle();

      final user = credential.user;
      if (user == null) {
        return (
          user: AuthUser.empty,
          failure: AuthFailure(
            message: 'Failed to sign in with Google.',
            code: 'google_sign_in_failed',
          )
        );
      }

      final authUser = AuthUserModel.fromFirebaseUser(user).toEntity();
      return (user: authUser, failure: null);
    } on FirebaseAuthException catch (e) {
      return (
        user: AuthUser.empty,
        failure: AuthFailure(
          message: _mapFirebaseError(e.code),
          code: e.code,
        )
      );
    } catch (e) {
      return (
        user: AuthUser.empty,
        failure: AuthFailure(
          message: 'Failed to sign in with Google.',
          code: 'google_sign_in_failed',
        )
      );
    }
  }

  @override
  Future<({AuthUser user, Failure? failure})> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _dataSource.registerWithEmail(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return (
          user: AuthUser.empty,
          failure: AuthFailure(
            message: 'Failed to create account.',
            code: 'registration_failed',
          )
        );
      }

      // Update display name
      await _dataSource.updateDisplayName(name);
      await _dataSource.reload();

      // Send verification email
      await _dataSource.sendVerificationEmail();

      final authUser = AuthUserModel.fromFirebaseUser(user).toEntity();
      return (user: authUser, failure: null);
    } on FirebaseAuthException catch (e) {
      return (
        user: AuthUser.empty,
        failure: AuthFailure(
          message: _mapFirebaseError(e.code),
          code: e.code,
        )
      );
    } catch (e) {
      return (
        user: AuthUser.empty,
        failure: AuthFailure(
          message: 'Failed to create account.',
          code: 'registration_failed',
        )
      );
    }
  }

  @override
  Future<Failure?> signOut() async {
    try {
      await _dataSource.signOut();
      return null;
    } catch (e) {
      return AuthFailure(
        message: 'Failed to sign out.',
        code: 'sign_out_failed',
      );
    }
  }

  @override
  Future<Failure?> sendPasswordReset(String email) async {
    try {
      await _dataSource.sendPasswordResetEmail(email);
      return null;
    } on FirebaseAuthException catch (e) {
      return AuthFailure(
        message: _mapFirebaseError(e.code),
        code: e.code,
      );
    } catch (e) {
      return AuthFailure(
        message: 'Failed to send password reset email.',
        code: 'password_reset_failed',
      );
    }
  }

  @override
  Future<Failure?> sendVerificationEmail() async {
    try {
      await _dataSource.sendVerificationEmail();
      return null;
    } catch (e) {
      return AuthFailure(
        message: 'Failed to send verification email.',
        code: 'verification_failed',
      );
    }
  }

  @override
  Future<({bool isVerified, Failure? failure})> isUserVerified() async {
    try {
      final user = _dataSource.currentUser;
      if (user == null) {
        return (isVerified: false, failure: null);
      }

      await _dataSource.reload();
      return (isVerified: user.emailVerified, failure: null);
    } catch (e) {
      return (
        isVerified: false,
        failure: AuthFailure(
          message: 'Failed to check verification status.',
          code: 'verification_check_failed',
        )
      );
    }
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'The email or password is incorrect.';
      case 'user-not-found':
        return 'No account was found for this email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many requests. Please try again in a moment.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'popup-closed':
        return 'Sign-in was cancelled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

extension AuthUserExtension on AuthUser {
  static AuthUser empty() {
    return const AuthUser(uid: '');
  }
}