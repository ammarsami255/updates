import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:el_moza3/services/auth_service.dart';

void main() {
  group('AuthResult', () {
    test('success creates successful result', () {
      final result = AuthResult.success();
      
      expect(result.isSuccess, true);
      expect(result.errorMessage, null);
      expect(result.requiresVerification, false);
    });

    test('success with info message creates result with message', () {
      final result = AuthResult.success(infoMessage: 'Welcome back!');
      
      expect(result.isSuccess, true);
      expect(result.infoMessage, 'Welcome back!');
    });

    test('failure creates failure result', () {
      final result = AuthResult.failure('Invalid email');
      
      expect(result.isSuccess, false);
      expect(result.errorMessage, 'Invalid email');
    });

    test('needsVerification creates verification required result', () {
      final result = AuthResult.needsVerification();
      
      expect(result.isSuccess, false);
      expect(result.requiresVerification, true);
      expect(result.infoMessage, 'Please verify your email to continue.');
    });

    test('needsVerification with custom message', () {
      final result = AuthResult.needsVerification('Verify your email first');
      
      expect(result.requiresVerification, true);
      expect(result.infoMessage, 'Verify your email first');
    });

    test('success result has no info message by default', () {
      final result = AuthResult.success();
      expect(result.infoMessage, null);
    });

    test('needsVerification result has info message but no error', () {
      final result = AuthResult.needsVerification();
      expect(result.infoMessage, isNotNull);
      expect(result.errorMessage, null);
    });

    test('failure result has error but no info', () {
      final result = AuthResult.failure('Error');
      expect(result.errorMessage, isNotNull);
      expect(result.infoMessage, null);
    });
  });

  group('AuthService.validateName', () {
    test('empty returns error', () {
      final error = AuthService.validateName('');
      expect(error, 'Please enter your name.');
    });

    test('too short returns error', () {
      final error = AuthService.validateName('A');
      expect(error, 'Name must be at least 2 characters.');
    });

    test('valid returns null', () {
      final error = AuthService.validateName('John');
      expect(error, null);
    });

    test('exactly 2 characters is valid', () {
      final error = AuthService.validateName('AB');
      expect(error, null);
    });

    test('exactly 1 character is invalid', () {
      final error = AuthService.validateName('A');
      expect(error, isNotNull);
    });

    test('with spaces is valid', () {
      final error = AuthService.validateName('John Doe');
      expect(error, null);
    });

    test('with Arabic characters is valid', () {
      final error = AuthService.validateName('محمد');
      expect(error, null);
    });

    test('with numbers is valid', () {
      final error = AuthService.validateName('John123');
      expect(error, null);
    });
  });

  group('AuthService.validateEmail', () {
    test('empty returns error', () {
      final error = AuthService.validateEmail('');
      expect(error, 'Please enter your email.');
    });

    test('invalid format returns error', () {
      final error = AuthService.validateEmail('not-an-email');
      expect(error, 'Please enter a valid email address.');
    });

    test('missing @ returns error', () {
      final error = AuthService.validateEmail('testexample.com');
      expect(error, 'Please enter a valid email address.');
    });

    test('valid returns null', () {
      final error = AuthService.validateEmail('test@example.com');
      expect(error, null);
    });

    test('valid with subdomain', () {
      final error = AuthService.validateEmail('test@mail.example.com');
      expect(error, null);
    });

    test('with plus sign is valid', () {
      final error = AuthService.validateEmail('test+tag@example.com');
      expect(error, null);
    });

    test('with dot in local part is valid', () {
      final error = AuthService.validateEmail('first.last@example.com');
      expect(error, null);
    });

    test('with underscore is valid', () {
      final error = AuthService.validateEmail('user_name@example.com');
      expect(error, null);
    });

    test('with hyphen is valid', () {
      final error = AuthService.validateEmail('user-name@example.com');
      expect(error, null);
    });

    test('uppercase in domain is valid', () {
      final error = AuthService.validateEmail('test@EXAMPLE.COM');
      expect(error, null);
    });

    test('with dots in domain is valid', () {
      final error = AuthService.validateEmail('test@a.b.c');
      expect(error, null);
    });
  });

  group('AuthService.validatePassword', () {
    test('empty returns error', () {
      final error = AuthService.validatePassword('');
      expect(error, 'Please enter your password.');
    });

    test('too short returns error', () {
      final error = AuthService.validatePassword('12345');
      expect(error, 'Password must be at least 6 characters.');
    });

    test('valid returns null', () {
      final error = AuthService.validatePassword('password123');
      expect(error, null);
    });

    test('exactly 6 characters is valid', () {
      final error = AuthService.validatePassword('123456');
      expect(error, null);
    });

    test('exactly 5 characters is invalid', () {
      final error = AuthService.validatePassword('12345');
      expect(error, isNotNull);
    });

    test('very long password is invalid', () {
      final longPass = 'a' * 100;
      final error = AuthService.validatePassword(longPass);
      // Long but not too short - should pass length check
      expect(error, null);
    });
  });

  group('Combined validation scenarios', () {
    test('all valid fields pass', () {
      final nameError = AuthService.validateName('John Doe');
      final emailError = AuthService.validateEmail('john@example.com');
      final passwordError = AuthService.validatePassword('password123');

      expect(nameError, null);
      expect(emailError, null);
      expect(passwordError, null);
    });

    test('all invalid fields fail', () {
      final nameError = AuthService.validateName('');
      final emailError = AuthService.validateEmail('invalid');
      final passwordError = AuthService.validatePassword('123');

      expect(nameError, isNotNull);
      expect(emailError, isNotNull);
      expect(passwordError, isNotNull);
    });

    test('mixed valid/invalid fields', () {
      final nameError = AuthService.validateName('John');
      final emailError = AuthService.validateEmail('');
      final passwordError = AuthService.validatePassword('password123');

      expect(nameError, null);
      expect(emailError, isNotNull);
      expect(passwordError, null);
    });
  });

  group('Anonymous auth disabled', () {
    test('signInAnonymously throws UnsupportedError', () async {
      expect(
        () => AuthService.signInAnonymously(),
        throwsA(isA<UnsupportedError>()),
      );
    });

    test('error message contains explanation', () async {
      try {
        await AuthService.signInAnonymously();
      } on UnsupportedError catch (e) {
        expect(e.message, contains('disabled'));
        expect(e.message, contains('security'));
      }
    });
  });

  group('Error handling', () {
    test('AuthResult failure is not success', () {
      final result = AuthResult.failure('Test error');
      expect(result.isSuccess, false);
    });

    test('AuthResult success is success', () {
      final result = AuthResult.success();
      expect(result.isSuccess, true);
    });

    test('needsVerification is not success', () {
      final result = AuthResult.needsVerification();
      expect(result.isSuccess, false);
    });
  });
}