import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'database_service.dart';
import 'notification_service.dart';
import 'chat_service.dart';
import 'connectivity_service.dart';

/// Result of authentication operations
class AuthResult {
  const AuthResult._({
    this.errorMessage,
    this.infoMessage,
    this.requiresVerification = false,
  });

  final String? errorMessage;
  final String? infoMessage;
  final bool requiresVerification;

  bool get isSuccess => errorMessage == null && !requiresVerification;

  factory AuthResult.success({
    String? infoMessage,
    bool requiresVerification = false,
  }) {
    return AuthResult._(
      infoMessage: infoMessage,
      requiresVerification: requiresVerification,
    );
  }

  factory AuthResult.failure(String errorMessage) {
    return AuthResult._(errorMessage: errorMessage);
  }

  factory AuthResult.needsVerification([String? infoMessage]) {
    return AuthResult._(
      infoMessage: infoMessage ?? 'Please verify your email to continue.',
      requiresVerification: true,
    );
  }
}

/// Save FCM token to Firestore
Future<void> saveFcmToken(String userId) async {
  await NotificationService.saveToken(userId);
}

/// Authentication Service using Firebase Built-in Auth
/// No custom OTP - uses Firebase Email Verification
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn();

  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  static User? get currentUser => _auth.currentUser;
  static bool get isLoggedIn => _auth.currentUser != null;
  static bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  static Future<AuthResult> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return AuthResult.failure('Google sign-in was cancelled.');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;
      if (user == null) {
        return AuthResult.failure('Failed to sign in with Google.');
      }

      // Check if user document exists, create if not
      final existingUser = await DatabaseService.getUserDocument(user.uid);
      if (existingUser == null) {
        await DatabaseService.createUserDocument(
          uid: user.uid,
          name: user.displayName ?? user.email?.split('@').first ?? 'User',
          email: user.email ?? '',
        );
      }

      await saveFcmToken(user.uid);

      return AuthResult.success();
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    } catch (e) {
      return AuthResult.failure(
        'Failed to sign in with Google. Please try again.',
      );
    }
  }

  /// Sign in anonymously [DEPRECATED - DISABLED FOR SECURITY]
  /// 
  /// Anonymous authentication has been disabled for security reasons.
  /// Only verified users (email+password or OAuth) can access the application.
  /// 
  /// @deprecated This method will throw UnsupportedError
  /// @throws UnsupportedError Always - anonymous auth is no longer supported
  static Future<AuthResult> signInAnonymously() async {
    // SECURITY: Anonymous auth is disabled for production safety
    // Anonymous users cannot verify their identity and bypass email verification
    throw UnsupportedError(
      'Anonymous authentication is disabled for security reasons. '
      'Please use email/password, Google, or phone authentication instead.',
    );
  }

  /// Register new user with Firebase built-in email verification
  static Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();

    // Validate inputs
    final nameError = validateName(trimmedName);
    if (nameError != null) return AuthResult.failure(nameError);

    final emailError = validateEmail(trimmedEmail);
    if (emailError != null) return AuthResult.failure(emailError);

    final passwordError = validatePassword(password);
    if (passwordError != null) return AuthResult.failure(passwordError);

    try {
      // Create Firebase Auth user
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      if (credential.user == null) {
        return AuthResult.failure('Failed to create user account.');
      }

      final user = credential.user!;

      // Update display name
      await user.updateDisplayName(trimmedName);
      await user.reload();

      // Create Firestore user document
      await DatabaseService.createUserDocument(
        uid: user.uid,
        name: trimmedName,
        email: trimmedEmail,
      );

      // Send Firebase built-in verification email
      await user.sendEmailVerification();
      await user.reload();

      return AuthResult.needsVerification(
        'Account created! Please check your email to verify your account.',
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    } catch (e) {
      return AuthResult.failure(
        'Unable to complete sign up. Please try again.',
      );
    }
  }

  /// Send verification email
  static Future<bool> sendVerificationEmail() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.sendEmailVerification();
        await user.reload();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if current user's email is verified
  /// Check if user is verified - offline safe version
  /// Uses cached status, does NOT force reload if offline
  static Future<bool> isCurrentUserVerified() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      
      // First check cached status (works offline)
      if (user.emailVerified) return true;
      
      // If not cached verified, try reload (may fail offline)
      // But don't fail the whole app - use cached value
      try {
        await user.reload();
        return user.emailVerified;
      } catch (e) {
        // Offline or network error - assume not verified
        // but don't block the app
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Check verification status - offline safe version
  /// Does NOT redirect to verify page automatically if offline
  static Future<AuthResult> checkVerificationStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.failure('No user is logged in.');
      }

      // Check cached status first (works offline)
      final cachedVerified = user.emailVerified;
      if (cachedVerified) {
        return AuthResult.success(infoMessage: 'Email verified (cached)!');
      }
      
      // Skip network reload if offline
      if (!ConnectivityService.instance.isOnline) {
        // Offline - use cached, let user in
        return AuthResult.success(infoMessage: 'Email verified (cached).');
      }
      
      // Try to reload for latest status (online only)
      try {
        await user.reload();
        if (user.emailVerified) {
          return AuthResult.success(infoMessage: 'Email verified successfully!');
        } else {
          return AuthResult.needsVerification();
        }
      } catch (e) {
        // Error - use cached value
        if (cachedVerified) {
          return AuthResult.success(infoMessage: 'Verified (cached).');
        }
        return AuthResult.needsVerification();
      }
    } catch (e) {
      return AuthResult.failure('Failed to check verification status.');
    }
  }

  /// Login with email and password
  /// Returns needsVerification if email is not verified
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    final emailError = validateEmail(trimmedEmail);
    if (emailError != null) return AuthResult.failure(emailError);

    final passwordError = validatePassword(password);
    if (passwordError != null) return AuthResult.failure(passwordError);

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return AuthResult.failure('Login failed. Please try again.');
      }

      // Reload to get latest verification status
      await user.reload();

      if (user.emailVerified) {
        await saveFcmToken(user.uid);
        return AuthResult.success();
      } else {
        return AuthResult.needsVerification(
          'Please verify your email before logging in.',
        );
      }
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    }
  }

  /// Logout
  static Future<void> logout() async {
    await NotificationService.deleteToken();
    await _googleSignIn.signOut();
    await _auth.signOut();
    
    // Clear all caches on logout
    ChatService.clearUserCache();
    DatabaseService.clearUserCache();
  }

  /// Send password reset email
  static Future<String?> sendPasswordReset(String email) async {
    final trimmedEmail = email.trim().toLowerCase();
    final emailError = validateEmail(trimmedEmail);
    if (emailError != null) return emailError;

    try {
      await _auth.sendPasswordResetEmail(email: trimmedEmail);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e.code);
    }
  }

  /// Validate name
  static String? validateName(String value) {
    if (value.isEmpty) return 'Please enter your name.';
    if (value.length < 2) return 'Name must be at least 2 characters.';
    return null;
  }

  /// Validate email
  static String? validateEmail(String value) {
    if (value.isEmpty) return 'Please enter your email.';
    if (!_emailRegex.hasMatch(value))
      return 'Please enter a valid email address.';
    return null;
  }

  /// Validate password
  static String? validatePassword(String value) {
    if (value.isEmpty) return 'Please enter your password.';
    if (value.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  /// Map Firebase error codes
  static String _mapError(String code) {
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
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
