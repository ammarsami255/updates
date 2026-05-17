import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';
import '../../../../core/errors/failures.dart';

/// Use case: Sign in with email and password
class SignInWithEmailUseCase {
  final AuthRepository _repository;

  SignInWithEmailUseCase(this._repository);

  Future<({AuthUser user, Failure? failure})> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}

/// Use case: Sign in with Google
class SignInWithGoogleUseCase {
  final AuthRepository _repository;

  SignInWithGoogleUseCase(this._repository);

  Future<({AuthUser user, Failure? failure})> call() {
    return _repository.signInWithGoogle();
  }
}

/// Use case: Register with email and password
class RegisterWithEmailUseCase {
  final AuthRepository _repository;

  RegisterWithEmailUseCase(this._repository);

  Future<({AuthUser user, Failure? failure})> call({
    required String name,
    required String email,
    required String password,
  }) {
    return _repository.registerWithEmail(
      name: name,
      email: email,
      password: password,
    );
  }
}

/// Use case: Sign out
class SignOutUseCase {
  final AuthRepository _repository;

  SignOutUseCase(this._repository);

  Future<Failure?> call() {
    return _repository.signOut();
  }
}

/// Use case: Get current user
class GetCurrentUserUseCase {
  final AuthRepository _repository;

  GetCurrentUserUseCase(this._repository);

  Future<({AuthUser? user, Failure? failure})> call() {
    return _repository.getCurrentUser();
  }
}

/// Use case: Send password reset
class SendPasswordResetUseCase {
  final AuthRepository _repository;

  SendPasswordResetUseCase(this._repository);

  Future<Failure?> call(String email) {
    return _repository.sendPasswordReset(email);
  }
}

/// Use case: Send verification email
class SendVerificationEmailUseCase {
  final AuthRepository _repository;

  SendVerificationEmailUseCase(this._repository);

  Future<Failure?> call() {
    return _repository.sendVerificationEmail();
  }
}

/// Use case: Check if user verified
class CheckUserVerifiedUseCase {
  final AuthRepository _repository;

  CheckUserVerifiedUseCase(this._repository);

  Future<({bool isVerified, Failure? failure})> call() {
    return _repository.isUserVerified();
  }
}