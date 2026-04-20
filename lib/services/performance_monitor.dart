import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks generation-session duration and enforces a cooldown after
/// sustained inference to prevent thermal throttling.
///
/// Device-level thermal state is not queried: there is no platform channel
/// wired to `NSProcessInfo.thermalState` / Android thermal APIs, so relying
/// on that signal would be misleading. Add one here when the native bridge
/// is implemented — until then the session timer is the only safeguard.
class PerformanceMonitor extends ChangeNotifier {
  static const int _maxSessionDurationSeconds = 120; // 2 min sustained gen cap
  static const int _cooldownDurationSeconds = 10;

  bool _isThrottled = false;
  Timer? _sessionTimer;
  Timer? _cooldownTimer;
  int _sessionSeconds = 0;

  bool get isThrottled => _isThrottled;
  bool get shouldReduceLoad => _isThrottled;

  int get sessionSeconds => _sessionSeconds;
  int get maxSessionSeconds => _maxSessionDurationSeconds;

  /// Start monitoring a generation session.
  void startSession() {
    _sessionSeconds = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
      if (_sessionSeconds >= _maxSessionDurationSeconds) {
        _sessionTimer?.cancel();
        startCooldown();
      }
      notifyListeners();
    });
  }

  /// End the current generation session.
  void endSession() {
    _sessionTimer?.cancel();
    _sessionSeconds = 0;
    notifyListeners();
  }

  /// Start a cooldown period after sustained generation.
  void startCooldown() {
    _isThrottled = true;
    notifyListeners();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(
      Duration(seconds: _cooldownDurationSeconds),
      () {
        _isThrottled = false;
        notifyListeners();
      },
    );
  }

  /// Get a user-friendly description of the current performance state.
  String get statusDescription => _isThrottled
      ? 'Cooling down... Please wait a moment.'
      : 'Running smoothly';

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
