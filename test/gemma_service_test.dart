import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_device_ai/services/gemma_service.dart';

import 'fake_chat.dart';

void main() {
  late FakeChat chat;
  late GemmaService service;

  setUp(() {
    chat = FakeChat();
    service = GemmaService.withChat(chat);
  });

  test('a natural end does not call native stop', () async {
    final reply = service.sendMessage('hi').join();
    await pumpEventQueue();
    chat.tokens
      ..add(const TextResponse('Hel'))
      ..add(const TextResponse('lo'));
    await chat.tokens.close();
    expect(await reply, 'Hello');
    expect(chat.stopCalls, 0);
    expect(service.isGenerating, isFalse);
  });

  test('cancelling the stream stops native generation', () async {
    final sub = service.sendMessage('hi').listen((_) {});
    await pumpEventQueue();
    chat.tokens.add(const TextResponse('partial'));
    await pumpEventQueue();

    await sub.cancel();

    expect(chat.stopCalls, 1);
    expect(service.isGenerating, isFalse);
  });

  test('stops native generation at the reply cap', () async {
    final received = <String>[];
    final done = Completer<void>();
    service.sendMessage('hi').listen(received.add, onDone: done.complete);
    await pumpEventQueue();
    for (var i = 0; i < GemmaService.maxResponseTokens + 5; i++) {
      chat.tokens.add(const TextResponse('x'));
    }
    await done.future;

    expect(received, hasLength(GemmaService.maxResponseTokens));
    expect(chat.stopCalls, 1);
    expect(service.wasLastGenerationTruncated, isTrue);
  });

  test('errors stop native generation and reset state', () async {
    final error = Completer<Object>();
    service.sendMessage('hi').listen((_) {}, onError: error.complete);
    await pumpEventQueue();
    chat.tokens.addError(Exception('boom'));

    await error.future;
    await pumpEventQueue();
    expect(chat.stopCalls, 1);
    expect(service.isGenerating, isFalse);
  });

  test('resets the conversation before the context window overflows', () async {
    Future<void> exchange(String prompt, int replyChars) async {
      final reply = service.sendMessage(prompt).join();
      await pumpEventQueue();
      chat.tokens.add(TextResponse('r' * replyChars));
      await chat.tokens.close();
      await reply;
      chat.tokens = StreamController();
    }

    // 258 tokens per prompt and per reply; 576 stay free for the next reply
    // in a 2048 window, so the 4th prompt (1548 + 258 + 576) no longer fits.
    for (var i = 0; i < 3; i++) {
      await exchange('a' * 1000, 1000);
      expect(service.didLastMessageResetContext, isFalse);
    }
    await exchange('a' * 1000, 1000);
    expect(service.didLastMessageResetContext, isTrue);
    expect(chat.clearCalls, 1);
  });

  test('stopped partial replies still count toward the context', () async {
    // 9-token prompt + 408-token partial reply per round: the 5th prompt
    // (1668 + 9 + 576) no longer fits.
    for (var i = 0; i < 5; i++) {
      expect(service.didLastMessageResetContext, isFalse);
      final sub = service.sendMessage('q').listen((_) {});
      await pumpEventQueue();
      chat.tokens.add(TextResponse('r' * 1600)); // ~408 tokens, then Stop
      await pumpEventQueue();
      await sub.cancel();
      chat.tokens = StreamController();
    }
    expect(service.didLastMessageResetContext, isTrue);
    expect(chat.stopCalls, 5);
  });

  test('cancelling before the first token still stops native', () async {
    final sub = service.sendMessage('hi').listen((_) {});
    await pumpEventQueue();
    await sub.cancel(); // no token ever arrives
    expect(chat.stopCalls, 1);
    expect(service.isGenerating, isFalse);
  });

  test('a native error makes the next send start fresh', () async {
    final error = Completer<void>();
    service.sendMessage('hi').listen((_) {}, onError: (_) => error.complete());
    await pumpEventQueue();
    chat.tokens.addError(Exception('context full'));
    await error.future;
    await pumpEventQueue();
    chat.tokens = StreamController();

    service.sendMessage('again').listen((_) {});
    await pumpEventQueue();
    expect(chat.clearCalls, 1);
    expect(service.didLastMessageResetContext, isTrue);
  });

  test(
    'cancelling while the prompt is queued waits, then starts fresh',
    () async {
      final gate = Completer<void>();
      chat.addQueryGate = gate.future;
      final sub = service.sendMessage('one').listen((_) {});
      await pumpEventQueue();

      final cancel = sub.cancel();
      await pumpEventQueue();
      expect(service.isGenerating, isTrue); // still waiting on addQuery
      gate.complete();
      await cancel;
      expect(service.isGenerating, isFalse);
      expect(chat.generateCalls, 0);

      chat.addQueryGate = null;
      service.sendMessage('two').listen((_) {});
      await pumpEventQueue();
      expect(chat.clearCalls, 1);
    },
  );

  test('clearChat is rejected while generating', () async {
    service.sendMessage('hi').listen((_) {});
    await pumpEventQueue();
    expect(service.clearChat(), throwsStateError);
  });

  test('rejects a second send while generating', () async {
    service.sendMessage('one').listen((_) {});
    await pumpEventQueue();
    expect(service.sendMessage('two').first, throwsStateError);
  });
}
