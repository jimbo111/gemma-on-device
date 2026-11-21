import 'dart:async';

import 'package:flutter_gemma/flutter_gemma.dart';

/// Streams whatever the test pushes into [tokens] and records native calls.
class FakeChat implements InferenceChat {
  StreamController<ModelResponse> tokens = StreamController();
  int stopCalls = 0;
  int clearCalls = 0;
  final List<String> queries = [];

  @override
  Future<void> addQuery(Message message) async => queries.add(message.text);

  @override
  Stream<ModelResponse> generateChatResponseAsync() => tokens.stream;

  @override
  Future<void> stopGeneration() async => stopCalls++;

  @override
  Future<void> clearHistory({List<Message>? replayHistory}) async =>
      clearCalls++;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
