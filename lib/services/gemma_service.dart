import 'dart:async';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'context_budget.dart';

/// Owns the Gemma 4 E2B lifecycle: download, load, streaming chat.
///
/// Android only. `.litertlm` needs LiteRT-LM, and flutter_gemma's iOS plugin
/// is MediaPipe-only.
class GemmaService extends ChangeNotifier {
  static const String _modelFileName = 'gemma-4-E2B-it.litertlm';
  static const String _modelUrl =
      'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/$_modelFileName';

  /// Context window the engine is created with: history, prompt and reply.
  /// Matches the configuration the model card's speed and memory figures
  /// were measured with; the model supports up to 32k at a higher KV-cache
  /// cost.
  static const int maxContextTokens = 2048;

  /// Per-reply cap that keeps single generations short to limit heat.
  static const int maxResponseTokens = 512;

  static const Duration _statsInterval = Duration(milliseconds: 500);

  InferenceModel? _model;
  InferenceChat? _chat;
  PreferredBackend? _backend;

  final ContextBudget _context = ContextBudget(
    maxTokens: maxContextTokens,
    // Streamed chunks are counted as tokens, so leave slack for the estimate.
    reservedForReply: maxResponseTokens + 64,
  );

  GemmaServiceState _state = GemmaServiceState.uninitialized;
  double _downloadProgress = 0.0;
  bool _frameworkInitialized = false;

  int _tokensGenerated = 0;
  final Stopwatch _generationStopwatch = Stopwatch();
  Duration _lastStatsNotify = Duration.zero;
  bool _lastGenerationTruncated = false;
  bool _lastMessageResetContext = false;

  /// The native conversation may hold state the budget doesn't know about
  /// (a prompt queued without a reply, or an engine error such as overflow);
  /// the next send starts fresh.
  bool _needsContextReset = false;
  bool _clearing = false;

  GemmaService();

  /// A service with [chat] already loaded, bypassing download and model init.
  @visibleForTesting
  GemmaService.withChat(InferenceChat chat)
    : _chat = chat,
      _state = GemmaServiceState.ready;

  GemmaServiceState get state => _state;
  double get downloadProgress => _downloadProgress;
  bool get isGenerating => _state == GemmaServiceState.generating;

  /// True if the most recent reply hit [maxResponseTokens] before EOS.
  bool get wasLastGenerationTruncated => _lastGenerationTruncated;

  /// True if the most recent [sendMessage] had to start a fresh conversation,
  /// usually because the prompt would not fit alongside the history.
  bool get didLastMessageResetContext => _lastMessageResetContext;

  /// Upper bound on prompt length for the text field.
  int get maxPromptChars => _context.maxPromptChars;

  /// Whether [prompt] can be sent at all; non-ASCII text costs more tokens
  /// per character than [maxPromptChars] assumes.
  bool canSend(String prompt) => _context.fitsAlone(prompt);

  /// Model plus the backend it actually loaded on.
  String get backendLabel => switch (_backend) {
    PreferredBackend.gpu => 'Gemma 4 E2B · GPU',
    PreferredBackend.cpu => 'Gemma 4 E2B · CPU',
    _ => 'Gemma 4 E2B',
  };

  /// Streamed chunks per second for the current or last reply.
  double get tokensPerSecond {
    final ms = _generationStopwatch.elapsedMilliseconds;
    return ms == 0 ? 0 : _tokensGenerated / (ms / 1000);
  }

  /// Initialize flutter_gemma. Idempotent, so the setup retry path can call it.
  Future<void> initFramework() async {
    if (_frameworkInitialized) return;
    await FlutterGemma.initialize(maxDownloadRetries: 10);
    _frameworkInitialized = true;
  }

  /// Whether the model file was downloaded on a previous run.
  Future<bool> _isModelDownloaded() =>
      FlutterGemma.isModelInstalled(_modelFileName);

  /// Register the model with flutter_gemma, downloading it first if needed.
  /// Must run on every launch: the active-model selection is not persisted.
  Future<void> installModel() async {
    if (_state == GemmaServiceState.downloading ||
        _state == GemmaServiceState.loading ||
        _state == GemmaServiceState.generating) {
      throw StateError('Cannot install while ${_state.name}.');
    }
    try {
      if (!await _isModelDownloaded()) await _startDownload();
      await _install();

      // flutter_gemma skips the download whenever its saved record exists,
      // even if the file is gone (storage cleaned, partial copy). Model init
      // would then fail and stay failed until restart, because the plugin
      // caches the failed init. Catch it here, drop the record, re-download.
      if (!await _activeModelFileIsValid()) {
        debugPrint('Model record exists but file is missing; re-downloading');
        await FlutterGemma.uninstallModel(_modelFileName);
        await _startDownload();
        await _install();
      }

      _state = GemmaServiceState.downloaded;
      notifyListeners();
    } catch (_) {
      _state = GemmaServiceState.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _startDownload() async {
    _state = GemmaServiceState.downloading;
    _downloadProgress = 0.0;
    notifyListeners();
    await _enableForegroundDownload();
  }

  Future<void> _install() =>
      FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(_modelUrl).withProgress((progress) {
        _downloadProgress = progress / 100.0;
        notifyListeners();
      }).install();

  Future<bool> _activeModelFileIsValid() async {
    final manager = FlutterGemmaPlugin.instance.modelManager;
    final spec = manager.activeInferenceModel;
    return spec != null && await manager.isModelInstalled(spec);
  }

  /// Android kills background work after 9 minutes unless it runs as a
  /// foreground service, which requires a visible notification (and on
  /// Android 13+ the notification permission). Without it, a 2.6 GB download
  /// on a slower connection restarts from zero until retries run out:
  /// flutter_gemma disables resume for HuggingFace URLs.
  Future<void> _enableForegroundDownload() async {
    final downloader = FileDownloader();
    downloader.configureNotification(
      running: const TaskNotification(
        'Downloading Gemma 4 E2B',
        '{progress} · one-time setup',
      ),
      progressBar: true,
    );
    try {
      await downloader.permissions.request(PermissionType.notifications);
    } catch (e) {
      // A denied or failed request only loses the foreground guarantee; the
      // download itself still runs.
      debugPrint('Notification permission request failed: $e');
    }
  }

  /// Load the model and open a chat session. Falls back to CPU when the GPU
  /// delegate fails to initialize (e.g. no usable OpenCL driver).
  Future<void> loadModel() async {
    if (_state == GemmaServiceState.loading ||
        _state == GemmaServiceState.generating) {
      throw StateError('Cannot load while ${_state.name}.');
    }
    _state = GemmaServiceState.loading;
    notifyListeners();

    try {
      try {
        _model = await _createModel(PreferredBackend.gpu);
      } catch (e) {
        debugPrint('GPU init failed, falling back to CPU: $e');
        _model = await _createModel(PreferredBackend.cpu);
      }

      _chat = await _model!.createChat(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        // ContextBudget resets the conversation before it fills, so keep the
        // plugin's own trimming (which corrupts LiteRT-LM history) out of it.
        tokenBuffer: 0,
        modelType: ModelType.gemmaIt,
      );
      _context.reset();

      _state = GemmaServiceState.ready;
      notifyListeners();
    } catch (_) {
      _state = GemmaServiceState.error;
      notifyListeners();
      rethrow;
    }
  }

  Future<InferenceModel> _createModel(PreferredBackend backend) async {
    final model = await FlutterGemma.getActiveModel(
      maxTokens: maxContextTokens,
      preferredBackend: backend,
    );
    _backend = backend;
    return model;
  }

  /// Send [text] and stream the reply chunk by chunk.
  ///
  /// Cancelling the subscription stops native generation; the returned
  /// future from `cancel()` completes once it has stopped.
  Stream<String> sendMessage(String text) {
    final chat = _chat;
    if (chat == null) {
      return Stream.error(
        StateError('Model not loaded. Call loadModel() first.'),
      );
    }
    if (_state == GemmaServiceState.generating || _clearing) {
      return Stream.error(StateError('Busy: generating or clearing.'));
    }

    _state = GemmaServiceState.generating;
    _tokensGenerated = 0;
    _lastGenerationTruncated = false;
    _lastMessageResetContext = false;
    _lastStatsNotify = Duration.zero;
    _generationStopwatch
      ..reset()
      ..start();
    notifyListeners();

    final reply = StringBuffer();
    final out = StreamController<String>();
    StreamSubscription<ModelResponse>? native;
    Future<void>? queued;
    var cancelled = false;
    var finished = false;

    // Runs exactly once, however the generation ends.
    Future<void> finish({required bool stopNative}) async {
      if (finished) return;
      finished = true;
      // Cancelling a Dart subscription does not stop LiteRT-LM. Without an
      // explicit stop the model keeps generating and its leftover tokens
      // leak into the next reply.
      if (stopNative) await _stopNative(chat);
      // Partial replies still occupy the native context.
      _context.addReply(reply.toString(), _tokensGenerated);
      _generationStopwatch.stop();
      _state = GemmaServiceState.ready;
      notifyListeners();
    }

    void onResponse(ModelResponse response) {
      if (finished || response is! TextResponse) return;
      _tokensGenerated++;
      reply.write(response.token);
      out.add(response.token);
      _notifyStatsThrottled();
      if (_tokensGenerated >= maxResponseTokens) {
        _lastGenerationTruncated = true;
        unawaited(native?.cancel());
        finish(stopNative: true).whenComplete(out.close);
      }
    }

    Future<void> queuePrompt() async {
      if (_needsContextReset || !_context.fits(text)) {
        await chat.clearHistory();
        _context.reset();
        _needsContextReset = false;
        _lastMessageResetContext = true;
      }
      _context.addPrompt(text);
      await chat.addQuery(Message.text(text: text, isUser: true));
    }

    Future<void> start() async {
      try {
        await (queued = queuePrompt());
      } catch (e, st) {
        _needsContextReset = true;
        await finish(stopNative: false);
        out.addError(e, st);
        await out.close();
        return;
      }
      if (cancelled) return;

      native = chat.generateChatResponseAsync().listen(
        onResponse,
        onError: (Object e, StackTrace st) async {
          if (finished) return;
          _needsContextReset = true;
          await finish(stopNative: true);
          out.addError(e, st);
          await out.close();
        },
        onDone: () async {
          if (finished) return;
          await finish(stopNative: false);
          await out.close();
        },
      );
    }

    out
      ..onListen = start
      ..onCancel = () async {
        cancelled = true;
        if (native == null) {
          // Cancelled while the prompt was being queued. Wait for that to
          // settle so the next send can't interleave with it; the queued
          // prompt has no reply, so the next send starts fresh.
          try {
            await queued;
          } catch (_) {}
          _needsContextReset = true;
          return finish(stopNative: false);
        }
        // Not awaited: flutter_gemma's async* stream only observes a cancel
        // at its next yield, which may never come if native is mid-prefill.
        // Stopping native makes it emit done, which unwinds it.
        unawaited(native!.cancel());
        return finish(stopNative: true);
      };
    return out.stream;
  }

  Future<void> _stopNative(InferenceChat chat) async {
    try {
      await chat.stopGeneration();
    } catch (e) {
      debugPrint('stopGeneration failed: $e');
    }
  }

  void _notifyStatsThrottled() {
    final elapsed = _generationStopwatch.elapsed;
    if (elapsed - _lastStatsNotify < _statsInterval) return;
    _lastStatsNotify = elapsed;
    notifyListeners();
  }

  /// Start a fresh conversation. Cancel any in-flight [sendMessage] first:
  /// clearing recreates the native session, and sends are rejected until it
  /// completes.
  Future<void> clearChat() async {
    final chat = _chat;
    if (chat == null) return;
    if (_state == GemmaServiceState.generating) {
      throw StateError('Cancel the in-flight reply before clearing.');
    }
    _clearing = true;
    try {
      await chat.clearHistory();
      _context.reset();
      _needsContextReset = false;
    } finally {
      _clearing = false;
    }
    _tokensGenerated = 0;
    _generationStopwatch.reset();
    notifyListeners();
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
