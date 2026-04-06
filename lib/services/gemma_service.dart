import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

/// Manages Gemma 4 E2B model lifecycle: download, initialization, inference.
///
/// Uses flutter_gemma's Modern API with LiteRT-LM (.litertlm) format.
/// Model is downloaded from HuggingFace on first launch, then cached locally.
class GemmaService extends ChangeNotifier {
  static const String _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

  static const int _maxTokens = 2048;
  static const int _maxGenerationTokens = 512;

  InferenceModel? _model;
  InferenceChat? _chat;

  GemmaServiceState _state = GemmaServiceState.uninitialized;
  double _downloadProgress = 0.0;
  String? _error;

  // Performance tracking
  int _tokensGenerated = 0;
  final Stopwatch _generationStopwatch = Stopwatch();

  GemmaServiceState get state => _state;
  double get downloadProgress => _downloadProgress;
  String? get error => _error;
  bool get isReady => _state == GemmaServiceState.ready;
  bool get isGenerating => _state == GemmaServiceState.generating;
  int get tokensGenerated => _tokensGenerated;

  /// Initialize the FlutterGemma framework. Call once at app startup.
  Future<void> initFramework({String? huggingFaceToken}) async {
    await FlutterGemma.initialize(
      huggingFaceToken: huggingFaceToken,
      maxDownloadRetries: 10,
    );
  }

  /// Check if the model is already installed locally.
  Future<bool> isModelInstalled() async {
    return FlutterGemma.hasActiveModel();
  }

  /// Download and install the Gemma 4 E2B model from HuggingFace.
  Future<void> downloadModel() async {
    _state = GemmaServiceState.downloading;
    _downloadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      )
          .fromNetwork(_modelUrl)
          .withProgress((progress) {
        _downloadProgress = progress / 100.0;
        notifyListeners();
      }).install();

      _state = GemmaServiceState.downloaded;
      notifyListeners();
    } catch (e) {
      _state = GemmaServiceState.error;
      _error = 'Download failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Load the model into memory and create a chat session.
  /// Call during splash screen for background warm-up.
  Future<void> loadModel() async {
    _state = GemmaServiceState.loading;
    _error = null;
    notifyListeners();

    try {
      _model = await FlutterGemma.getActiveModel(
        maxTokens: _maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );

      _chat = await _model!.createChat(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        tokenBuffer: 256,
        modelType: ModelType.gemmaIt,
      );

      _state = GemmaServiceState.ready;
      notifyListeners();
    } catch (e) {
      _state = GemmaServiceState.error;
      _error = 'Model loading failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Send a message and stream back the response token by token.
  ///
  /// Enforces [_maxGenerationTokens] limit to prevent thermal throttling.
  /// Returns a stream of text tokens.
  Stream<String> sendMessage(String text) async* {
    if (_chat == null) {
      throw StateError('Model not loaded. Call loadModel() first.');
    }
    if (_state == GemmaServiceState.generating) {
      throw StateError('Already generating. Stop current generation first.');
    }

    _state = GemmaServiceState.generating;
    _tokensGenerated = 0;
    _generationStopwatch.reset();
    _generationStopwatch.start();
    notifyListeners();

    try {
      final message = Message.text(text: text, isUser: true);
      await _chat!.addQuery(message);

      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          _tokensGenerated++;

          // Enforce generation token limit to prevent thermal throttling
          if (_tokensGenerated >= _maxGenerationTokens) {
            await _chat!.stopGeneration();
            yield response.token;
            break;
          }

          yield response.token;
        }
        // ThinkingResponse and FunctionCallResponse are ignored for basic chat
      }
    } catch (e) {
      _error = 'Generation failed: $e';
      notifyListeners();
      rethrow;
    } finally {
      _generationStopwatch.stop();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }
  }

  /// Stop any in-progress generation.
  Future<void> stopGeneration() async {
    if (_chat != null && _state == GemmaServiceState.generating) {
      await _chat!.stopGeneration();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }
  }

  /// Clear chat history and start fresh.
  Future<void> clearChat() async {
    if (_chat != null) {
      await _chat!.clearHistory();
    }
  }

  /// Get the preferred backend description for the current platform.
  String get backendInfo {
    if (Platform.isIOS) {
      return 'Metal GPU (iOS)';
    } else if (Platform.isAndroid) {
      return 'GPU/NPU (Android)';
    }
    return 'Unknown';
  }

  /// Tokens per second from the last generation.
  double get tokensPerSecond {
    if (_generationStopwatch.elapsedMilliseconds == 0) return 0;
    return _tokensGenerated / (_generationStopwatch.elapsedMilliseconds / 1000);
  }

  @override
  void dispose() {
    _chat?.close();
    _model?.close();
    super.dispose();
  }
}

enum GemmaServiceState {
  uninitialized,
  downloading,
  downloaded,
  loading,
  ready,
  generating,
  error,
}
