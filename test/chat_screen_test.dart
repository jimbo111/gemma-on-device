import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_device_ai/screens/chat_screen.dart';
import 'package:on_device_ai/services/gemma_service.dart';
import 'package:on_device_ai/services/performance_monitor.dart';
import 'package:on_device_ai/widgets/typing_indicator.dart';

import 'fake_chat.dart';

void main() {
  late FakeChat chat;
  late GemmaService service;
  late PerformanceMonitor monitor;

  Future<void> pumpChat(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(gemmaService: service, performanceMonitor: monitor),
      ),
    );
  }

  Future<void> send(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
  }

  /// Let the monitor's post-generation idle timer run out.
  Future<void> settleTimers(WidgetTester tester) =>
      tester.pump(monitor.cooldown);

  setUp(() {
    chat = FakeChat();
    service = GemmaService.withChat(chat);
    monitor = PerformanceMonitor(
      maxSustained: const Duration(seconds: 5),
      cooldown: const Duration(seconds: 2),
    );
  });

  tearDown(() => monitor.dispose());

  testWidgets('streams a reply into a bubble', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Hello');

    expect(find.text('Hello'), findsOneWidget);
    expect(find.byType(TypingIndicator), findsOneWidget);

    chat.tokens.add(const TextResponse('Hi '));
    chat.tokens.add(const TextResponse('there'));
    await tester.pump();
    expect(find.textContaining('Hi there'), findsOneWidget);
    expect(find.byType(TypingIndicator), findsNothing);

    await chat.tokens.close();
    await tester.pumpAndSettle();
    expect(find.text('Hi there'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    expect(chat.stopCalls, 0);
    await settleTimers(tester);
  });

  testWidgets('Stop halts native generation and keeps the partial reply', (
    tester,
  ) async {
    await pumpChat(tester);
    await send(tester, 'Tell me a story');
    chat.tokens.add(const TextResponse('Once upon'));
    await tester.pump();

    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();

    expect(chat.stopCalls, 1);
    expect(service.isGenerating, isFalse);
    expect(find.text('Once upon'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);
    await settleTimers(tester);
  });

  testWidgets('Stop before the first token removes the typing indicator', (
    tester,
  ) async {
    await pumpChat(tester);
    await send(tester, 'Hi');

    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();

    expect(chat.stopCalls, 1);
    expect(find.byType(TypingIndicator), findsNothing);
    expect(find.byTooltip('Send'), findsOneWidget);
    await settleTimers(tester);
  });

  testWidgets('cooldown interrupts a long generation', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Write an essay');
    chat.tokens.add(const TextResponse('Para one.'));
    await tester.pump();

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(chat.stopCalls, 1);
    expect(find.text('Paused to let the device cool down.'), findsOneWidget);
    expect(find.text('Para one.'), findsOneWidget);
    await settleTimers(tester);
  });

  testWidgets('a native error with no output shows an error bubble', (
    tester,
  ) async {
    await pumpChat(tester);
    await send(tester, 'Hi');
    chat.tokens.addError(Exception('context full'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(service.isGenerating, isFalse);
    await settleTimers(tester);
  });

  testWidgets('clear chat empties the transcript', (tester) async {
    await pumpChat(tester);
    await send(tester, 'Hi');
    chat.tokens.add(const TextResponse('Hey'));
    await chat.tokens.close();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Clear chat'));
    await tester.pumpAndSettle();

    expect(chat.clearCalls, 1);
    expect(find.text('Ask me anything'), findsOneWidget);
    await settleTimers(tester);
  });
}
