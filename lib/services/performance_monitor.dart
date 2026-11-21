import 'dart:async';

import 'package:flutter/foundation.dart';

/// Enforces a cooldown after sustained inference to limit heat.
///
/// Generation time accumulates across back-to-back replies and only resets
/// after an idle gap as long as the cooldown. Once [maxSustained] is reached,
/// [isThrottled] flips true for [cooldown]; listeners should stop any
/// in-flight generation and block new sends until it clears.
///
/// Device thermal state is not read: there is no platform channel for
/// Android's thermal APIs yet, so the timer is the only safeguard.
class PerformanceMonitor extends ChangeNotifier {
  PerformanceMonitor({
    this.maxSustained = const Duration(minutes: 2),
    this.cooldown = const Duration(seconds: 10),
  });

  final Duration maxSustained;
  final Duration cooldown;

  static const Duration _tick = Duration(seconds: 1);

  bool _isThrottled = false;
  Duration _sustained = Duration.zero;
  Timer? _tickTimer;
  Timer? _idleTimer;
  Timer? _cooldownTimer;

  bool get isThrottled => _isThrottled;

  String get statusDescription => _isThrottled
      ? 'Cooling down. Try again in a few seconds.'
      : 'Running smoothly';

  /// Call when a generation starts.
  void startSession() {
    if (_isThrottled) return;
    _idleTimer?.cancel();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(_tick, (_) {
      _sustained += _tick;
      if (_sustained >= maxSustained) _startCooldown();
    });
  }

  /// Call when a generation ends for any reason.
  void endSession() {
    if (_tickTimer == null) return;
    _tickTimer!.cancel();
    _tickTimer = null;
    _idleTimer?.cancel();
    _idleTimer = Timer(cooldown, () => _sustained = Duration.zero);
  }

  void _startCooldown() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _idleTimer?.cancel();
    _isThrottled = true;
    notifyListeners();

    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(cooldown, () {
      _isThrottled = false;
      _sustained = Duration.zero;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _idleTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }
}
