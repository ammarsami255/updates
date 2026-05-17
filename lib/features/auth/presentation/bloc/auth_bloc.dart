import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:el_moza3/infrastructure/di/injection.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';
import 'auth_state_event.dart';

/// Auth BLoC - handles all authentication logic
/// No Firebase code here - only uses use cases
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// Late final fields - initialized in constructor
  late final AuthRepository _authRepository;
  late final GetCurrentUserUseCase _getCurrentUser;
  late final SignInWithEmailUseCase _signInWithEmail;
  late final SignInWithGoogleUseCase _signInWithGoogle;
  late final RegisterWithEmailUseCase _registerWithEmail;
  late final SignOutUseCase _signOut;
  late final SendPasswordResetUseCase _sendPasswordReset;

  AuthBloc()
      : super(AuthInitial()) {
    // Initialize fields before auto-checking auth status
    _authRepository = getIt<AuthRepository>();
    _getCurrentUser = GetCurrentUserUseCase(_authRepository);
    _signInWithEmail = SignInWithEmailUseCase(_authRepository);
    _signInWithGoogle = SignInWithGoogleUseCase(_authRepository);
    _registerWithEmail = RegisterWithEmailUseCase(_authRepository);
    _signOut = SignOutUseCase(_authRepository);
    _sendPasswordReset = SendPasswordResetUseCase(_authRepository);

    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSignInWithEmailRequested>(_onSignInWithEmail);
    on<AuthSignInWithGoogleRequested>(_onSignInWithGoogle);
    on<AuthRegisterRequested>(_onRegister);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthResetPasswordRequested>(_onResetPassword);

    // Auto-check auth status on initialization
    add(AuthCheckRequested());
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _getCurrentUser();

    if (result.failure != null) {
      emit(AuthUnauthenticated());
      return;
    }

    if (result.user == null) {
      emit(AuthUnauthenticated());
      return;
    }

    final needsVerification = !result.user!.isEmailVerified;
    emit(AuthAuthenticated(user: result.user!, needsVerification: needsVerification));
  }

  Future<void> _onSignInWithEmail(
    AuthSignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInWithEmail(
      email: event.email,
      password: event.password,
    );

    if (result.failure != null) {
      if (result.failure is EmailVerificationFailure) {
        emit(AuthAuthenticated(user: result.user, needsVerification: true));
      } else {
        emit(AuthError(result.failure!.message));
      }
      return;
    }

    final needsVerification = !result.user.isEmailVerified;
    emit(AuthAuthenticated(user: result.user, needsVerification: needsVerification));
  }

  Future<void> _onSignInWithGoogle(
    AuthSignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInWithGoogle();

    if (result.failure != null) {
      emit(AuthError(result.failure!.message));
      return;
    }

    emit(AuthAuthenticated(user: result.user));
  }

  Future<void> _onRegister(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _registerWithEmail(
      name: event.name,
      email: event.email,
      password: event.password,
    );

    if (result.failure != null) {
      emit(AuthError(result.failure!.message));
      return;
    }

    // After registration, require verification
    emit(AuthAuthenticated(
      user: result.user,
      needsVerification: true,
    ));
  }

  Future<void> _onSignOut(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final failure = await _signOut();

    if (failure != null) {
      emit(AuthError(failure.message));
      return;
    }

    emit(AuthUnauthenticated());
  }

  Future<void> _onResetPassword(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final failure = await _sendPasswordReset(event.email);

    if (failure != null) {
      emit(AuthError(failure.message));
      return;
    }

    emit(AuthUnauthenticated());
  }
}

/// Type alias for getting AuthRepository from DI container
