import 'package:flutter_test/flutter_test.dart';
import 'package:on_device_ai/services/performance_monitor.dart';

void main() {
  PerformanceMonitor monitor() => PerformanceMonitor(
    maxSustained: const Duration(seconds: 10),
    cooldown: const Duration(seconds: 3),
  );

  testWidgets('a single long generation triggers the cooldown', (tester) async {
    final m = monitor();
    m.startSession();
    await tester.pump(const Duration(seconds: 9));
    expect(m.isThrottled, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(m.isThrottled, isTrue);
    await tester.pump(const Duration(seconds: 3));
    expect(m.isThrottled, isFalse);
    m.dispose();
  });

  testWidgets('back-to-back generations accumulate', (tester) async {
    final m = monitor();
    for (var i = 0; i < 2; i++) {
      m.startSession();
      await tester.pump(const Duration(seconds: 4));
      m.endSession();
      await tester.pump(const Duration(seconds: 1)); // shorter than cooldown
    }
    m.startSession();
    await tester.pump(const Duration(seconds: 2));
    expect(m.isThrottled, isTrue);
    await tester.pump(const Duration(seconds: 3));
    m.dispose();
  });

  testWidgets('an idle gap of at least the cooldown resets the count', (
    tester,
  ) async {
    final m = monitor();
    m.startSession();
    await tester.pump(const Duration(seconds: 8));
    m.endSession();
    await tester.pump(const Duration(seconds: 3));
    m.startSession();
    await tester.pump(const Duration(seconds: 8));
    expect(m.isThrottled, isFalse);
    m.endSession();
    await tester.pump(const Duration(seconds: 3));
    m.dispose();
  });

  testWidgets('notifies only when throttling changes', (tester) async {
    final m = monitor();
    var notifications = 0;
    m.addListener(() => notifications++);
    m.startSession();
    await tester.pump(const Duration(seconds: 5));
    expect(notifications, 0);
    await tester.pump(const Duration(seconds: 5));
    expect(notifications, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(notifications, 2);
    m.dispose();
  });
}
