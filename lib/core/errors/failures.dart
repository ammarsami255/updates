/// Core failures for domain layer error handling
abstract class Failure {
  final String message;
  final String? code;
  
  const Failure({required this.message, this.code});
  
  @override
  String toString() => 'Failure: $message (code: $code)';
}

/// Server-related failures
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});
}

/// Email verification required failure
class EmailVerificationFailure extends AuthFailure {
  const EmailVerificationFailure({required super.message, super.code});
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code});
}

/// Permission failures
class PermissionFailure extends Failure {
  const PermissionFailure({required super.message, super.code});
}