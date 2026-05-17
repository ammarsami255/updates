import 'dart:async';

/// Rate limiter for preventing abuse
/// Implements client-side cooldown and limits
class RateLimiter {
  RateLimiter._();

  // Track last action time per action type
  static final Map<String, DateTime> _lastActionTime = {};
  
  // Track action counts per time window
  static final Map<String, _ActionCounter> _actionCounts = {};

  /// Check if action is allowed based on cooldown
  /// Returns true if action can proceed, false if cooldown active
  static bool canPerformAction(String action, {Duration cooldown = const Duration(seconds: 1)}) {
    final now = DateTime.now();
    final lastTime = _lastActionTime[action];
    
    if (lastTime == null) {
      _lastActionTime[action] = now;
      return true;
    }
    
    if (now.difference(lastTime) > cooldown) {
      _lastActionTime[action] = now;
      return true;
    }
    
    return false;
  }

  /// Check if action within rate limit window
  /// Returns true if under limit, false if exceeded
  static bool isRateLimited(String action, {int maxActions = 10, Duration window = const Duration(minutes: 1)}) {
    final now = DateTime.now();
    final counter = _actionCounts[action];
    
    if (counter == null) {
      _actionCounts[action] = _ActionCounter(count: 1, windowStart: now);
      return false; // Under limit
    }
    
    // Reset if window expired
    if (now.difference(counter.windowStart) > window) {
      _actionCounts[action] = _ActionCounter(count: 1, windowStart: now);
      return false; // Under limit
    }
    
    // Check count
    if (counter.count >= maxActions) {
      return true; // Rate limited
    }
    
    // Increment count
    counter.count++;
    return false; // Under limit
  }

  /// Get remaining cooldown time for action
  static Duration getRemainingCooldown(String action, {Duration cooldown = const Duration(seconds: 1)}) {
    final lastTime = _lastActionTime[action];
    if (lastTime == null) return Duration.zero;
    
    final elapsed = DateTime.now().difference(lastTime);
    final remaining = cooldown - elapsed;
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// Get remaining actions allowed in current window
  static int getRemainingActions(String action, {int maxActions = 10, Duration window = const Duration(minutes: 1)}) {
    final counter = _actionCounts[action];
    if (counter == null) return maxActions;
    
    final now = DateTime.now();
    if (now.difference(counter.windowStart) > window) {
      return maxActions;
    }
    
    return (maxActions - counter.count).clamp(0, maxActions);
  }

  /// Reset rate limit for action (admin use)
  static void resetLimit(String action) {
    _actionCounts.remove(action);
    _lastActionTime.remove(action);
  }

  /// Reset all rate limits
  static void resetAll() {
    _actionCounts.clear();
    _lastActionTime.clear();
  }

  // ==================== PREDEFINED LIMITERS ====================
  
  /// Check if can send message (cooldown: 1 second)
  static bool get canSendMessage => canPerformAction('send_message', cooldown: const Duration(seconds: 1));
  
  /// Check if can send message rapidly (rate limit: 30 per minute)
  static bool get isMessageRateLimited => isRateLimited('send_message_rapid', maxActions: 30, window: const Duration(minutes: 1));
  
  /// Check if can create listing (cooldown: 30 seconds)
  static bool get canCreateListing => canPerformAction('create_listing', cooldown: const Duration(seconds: 30));
  
  /// Check if can refresh data (cooldown: 5 seconds)
  static bool get canRefreshData => canPerformAction('refresh_data', cooldown: const Duration(seconds: 5));

  /// Check if can increment view count (debounced)
  static bool get canIncrementViewCount => canPerformAction('view_count', cooldown: const Duration(minutes: 5));
  
  /// Check view count rate limit (max 100 per hour per listing)
  static bool get isViewCountRateLimited => isRateLimited('view_count_rapid', maxActions: 100, window: const Duration(hours: 1));
}

class _ActionCounter {
  int count;
  DateTime windowStart;
  
  _ActionCounter({required this.count, required this.windowStart});
}
