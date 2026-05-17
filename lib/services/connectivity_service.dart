import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'logger_service.dart';
import 'offline_queue_service.dart';

/// Simple connectivity check with auto-retry
class ConnectivityService {
  ConnectivityService._();
  
  static final ConnectivityService _instance = ConnectivityService._();
  static ConnectivityService get instance => _instance;

  bool _isOnline = true;
  bool get isOnline => _isOnline;
  
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get stream => _controller.stream;

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _wasOffline = false;

  Future<void> init() async {
    await _check();
    _subscription = Connectivity().onConnectivityChanged.listen(_onChanged);
  }
  
  Future<void> _check() async {
    final results = await Connectivity().checkConnectivity();
    _onChanged(results);
  }
  
  void _onChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);
    
    if (wasOnline != _isOnline) {
      _controller.add(_isOnline);
      
      // Auto-retry when coming back online
      if (_isOnline && _wasOffline) {
        _triggerRetry();
      }
      
      if (!_isOnline) {
        _wasOffline = true;
      }
    }
  }
  
  void _triggerRetry() {
    if (!ConnectivityService.instance.isOnline) return;
    
    // Retry pending messages
    final failed = OfflineQueueService.getFailedMessages();
    if (failed.isNotEmpty) {
      AppLogger.info('Auto-retrying ${failed.length} messages');
    }
  }
  
  Future<void> refresh() async {
    await _check();
  }
  
  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}

/// Banner widget showing offline status
class OfflineBanner extends StatelessWidget {
  final Widget child;
  
  const OfflineBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService.instance.stream,
      initialData: true,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        
        return Column(
          children: [
            if (!online)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade700,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Offline - Data may be limited',
                      style: TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        );
      }
    );
  }
}