import 'package:flutter/foundation.dart';

/// Production logging service
/// Replace with Firebase Crashlytics in production:
/// - FirebaseCrashlytics.instance.recordError(error, stack)
/// - FirebaseAnalytics.instance.logEvent(name: eventName, parameters: data)
class AppLogger {
  AppLogger._();

  static bool get _isDebug => kDebugMode;

  /// Log info message
  static void info(String message, {Map<String, dynamic>? data}) {
    if (_isDebug) {
      print('[INFO] $message ${data != null ? '| data: $data' : ''}');
    }
    // TODO: Send to analytics in production
  }

  /// Log warning
  static void warning(String message, {Map<String, dynamic>? data}) {
    if (_isDebug) {
      print('[WARNING] $message ${data != null ? '| data: $data' : ''}');
    }
    // TODO: Send to analytics in production
  }

  /// Log error (non-critical)
  static void error(String message, {Object? error, StackTrace? stack, Map<String, dynamic>? data}) {
    if (_isDebug) {
      print('[ERROR] $message');
      if (error != null) print('  error: $error');
      if (stack != null) print('  stack: $stack');
      if (data != null) print('  data: $data');
    }
    // TODO: Send to Crashlytics in production
    // FirebaseCrashlytics.instance.recordError(error, stack);
  }

  /// Log critical error that needs immediate attention
  static void critical(String message, {Object? error, StackTrace? stack, Map<String, dynamic>? data}) {
    print('[CRITICAL] $message');
    if (error != null) print('  error: $error');
    if (stack != null) print('  stack: $stack');
    if (data != null) print('  data: $data');
    
    // TODO: Send to Crashlytics immediately in production
    // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  }

  /// Log authentication event
  static void authEvent(String event, {String? uid, bool? success, Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'uid': uid,
      'success': success,
      ...?data,
    };
    info('Auth: $event', data: logData);
  }

  /// Log firestore operation
  static void firestoreOp(String operation, String collection, {String? docId, bool? success, int? readCount, Map<String, dynamic>? data}) {
    final logData = {
      'operation': operation,
      'collection': collection,
      'docId': docId,
      'success': success,
      'readCount': readCount,
      ...?data,
    };
    info('Firestore: $operation', data: logData);
  }

  /// Log chat event
  static void chatEvent(String event, {String? chatId, String? messageId, Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'chatId': chatId,
      'messageId': messageId,
      ...?data,
    };
    info('Chat: $event', data: logData);
  }

  /// Log network event
  static void networkEvent(String event, {String? url, int? statusCode, int? latencyMs, Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'url': url,
      'statusCode': statusCode,
      'latencyMs': latencyMs,
      ...?data,
    };
    info('Network: $event', data: logData);
  }

  /// Log performance metric
  static void performance(String operation, int durationMs, {Map<String, dynamic>? data}) {
    final logData = {
      'operation': operation,
      'durationMs': durationMs,
      ...?data,
    };
    
    if (durationMs > 1000) {
      warning('Slow operation: $operation', data: logData);
    } else {
      info('Performance: $operation', data: logData);
    }
  }
}
