import 'dart:async';

import 'package:flutter/foundation.dart';

/// Monitors device performance metrics relevant to on-device LLM inference.
///
/// Tracks:
/// - Thermal state (iOS) via ProcessInfo
/// - Memory pressure warnings
/// - Generation session duration for throttle prevention
///
/// On-device LLMs are memory-intensive (~1.5GB) and generate heat during
/// sustained inference. This monitor provides signals to degrade gracefully.
class PerformanceMonitor extends ChangeNotifier {
  static const int _maxSessionDurationSeconds = 120; // 2 min sustained gen cap
  static const int _cooldownDurationSeconds = 10;

  ThermalState _thermalState = ThermalState.nominal;
  bool _isThrottled = false;
  Timer? _sessionTimer;
  Timer? _cooldownTimer;
  int _sessionSeconds = 0;

  ThermalState get thermalState => _thermalState;
  bool get isThrottled => _isThrottled;
  bool get shouldReduceLoad =>
      _thermalState == ThermalState.serious ||
      _thermalState == ThermalState.critical ||
      _isThrottled;

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
    // If session ended before the timer triggered throttle, don't throttle
    // (cooldown timer handles reset if throttle was already triggered)
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

  /// Update thermal state from platform channel or ProcessInfo.
  /// On iOS, NSProcessInfo.thermalState maps to these values.
  void updateThermalState(ThermalState state) {
    if (_thermalState != state) {
      _thermalState = state;
      notifyListeners();

      if (state == ThermalState.critical) {
        _isThrottled = true;
        notifyListeners();
      }
    }
  }

  /// Get a user-friendly description of the current performance state.
  String get statusDescription {
    if (_isThrottled) {
      return 'Cooling down... Please wait a moment.';
    }
    switch (_thermalState) {
      case ThermalState.nominal:
        return 'Running smoothly';
      case ThermalState.fair:
        return 'Device warming up';
      case ThermalState.serious:
        return 'Device is warm - responses may be slower';
      case ThermalState.critical:
        return 'Device is hot - pausing to cool down';
    }
  }

  /// Suggested maximum token count based on thermal state.
  int get recommendedMaxTokens {
    switch (_thermalState) {
      case ThermalState.nominal:
        return 512;
      case ThermalState.fair:
        return 384;
      case ThermalState.serious:
        return 256;
      case ThermalState.critical:
        return 0; // Don't generate
    }
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}

enum ThermalState {
  nominal,
  fair,
  serious,
  critical,
}
