import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/gemma_service.dart';
import '../services/performance_monitor.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

/// Streaming chat with the on-device model.
class ChatScreen extends StatefulWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const ChatScreen({
    super.key,
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  /// Within this many logical pixels of the end, new text keeps the view
  /// pinned to the bottom; further up, the user's scroll position wins.
  static const double _autoScrollThreshold = 64.0;

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];

  /// The reply being streamed, kept out of [_messages] so each chunk rebuilds
  /// one bubble instead of the whole screen. Null when idle.
  final ValueNotifier<String?> _streamingReply = ValueNotifier(null);
  final StringBuffer _replyBuffer = StringBuffer();
  StreamSubscription<String>? _generationSub;
  _ChatMessage? _activeUserMessage;
  bool _clearing = false;
  bool _scrollScheduled = false;

  bool get _isGenerating => _generationSub != null;

  @override
  void initState() {
    super.initState();
    widget.performanceMonitor.addListener(_onThrottleChanged);
  }

  @override
  void dispose() {
    widget.performanceMonitor.removeListener(_onThrottleChanged);
    _generationSub?.cancel();
    widget.performanceMonitor.endSession();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _streamingReply.dispose();
    super.dispose();
  }

  void _onThrottleChanged() {
    if (!widget.performanceMonitor.isThrottled || !_isGenerating) return;
    _stopGeneration();
    _showSnackBar('Paused to let the device cool down.');
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels <= _autoScrollThreshold;
  }

  /// Scroll to the end after the next layout, at most once per frame.
  void _scrollToBottom({bool animate = false}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_scrollController.hasClients) return;
      final end = _scrollController.position.maxScrollExtent;
      if (animate) {
        _scrollController.animateTo(
          end,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(end);
      }
    });
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isGenerating || _clearing) return;

    // Check before mutating state so the typed message is preserved.
    if (widget.performanceMonitor.isThrottled) {
      _showSnackBar(widget.performanceMonitor.statusDescription);
      return;
    }
    if (!widget.gemmaService.canSend(text)) {
      _showSnackBar(
        'That message is too long for the model. Try shortening it.',
      );
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();

    final userMessage = _ChatMessage(text: text, isUser: true);
    _replyBuffer.clear();
    _streamingReply.value = '';
    final sub = widget.gemmaService
        .sendMessage(text)
        .listen(
          (chunk) => _onChunk(chunk, userMessage),
          onDone: () => _finishGeneration(userMessage),
          onError: (Object _) => _finishGeneration(userMessage, failed: true),
          cancelOnError: true,
        );
    setState(() {
      _messages.add(userMessage);
      _activeUserMessage = userMessage;
      _generationSub = sub;
    });
    _scrollToBottom(animate: true);
    widget.performanceMonitor.startSession();
  }

  void _onChunk(String chunk, _ChatMessage userMessage) {
    if (_replyBuffer.isEmpty) _markContextReset(userMessage);
    final stick = _isNearBottom();
    _replyBuffer.write(chunk);
    _streamingReply.value = _replyBuffer.toString();
    if (stick) _scrollToBottom();
  }

  void _markContextReset(_ChatMessage userMessage) {
    if (!widget.gemmaService.didLastMessageResetContext ||
        userMessage.startsNewContext) {
      return;
    }
    setState(() => userMessage.startsNewContext = true);
  }

  /// Move the streamed reply into the transcript. Runs once per generation:
  /// from onDone, onError, or after the cancel in [_stopGeneration].
  void _finishGeneration(_ChatMessage userMessage, {bool failed = false}) {
    _generationSub = null;
    _activeUserMessage = null;
    widget.performanceMonitor.endSession();
    if (!mounted) return;

    final reply = _replyBuffer.toString();
    _replyBuffer.clear();
    _markContextReset(userMessage);
    setState(() {
      if (reply.isNotEmpty) {
        _messages.add(
          _ChatMessage(
            text: reply,
            isUser: false,
            wasTruncated:
                !failed && widget.gemmaService.wasLastGenerationTruncated,
          )..hasAppeared = true,
        );
      } else if (failed) {
        _messages.add(
          _ChatMessage(
            text: 'Something went wrong. Please try again.',
            isUser: false,
          ),
        );
      }
    });
    _streamingReply.value = null;
    if (failed && reply.isNotEmpty) {
      _showSnackBar('Generation interrupted. Partial response shown.');
    }
  }

  Future<void> _stopGeneration() async {
    final sub = _generationSub;
    final userMessage = _activeUserMessage;
    if (sub == null || userMessage == null) return;
    // Cleared before the await so a second tap cannot finish twice.
    _generationSub = null;
    // Cancelling also stops native generation (see GemmaService.sendMessage).
    await sub.cancel();
    _finishGeneration(userMessage);
  }

  Future<void> _clearChat() async {
    // Clearing recreates the native session, so tear down the stream first.
    await _stopGeneration();
    _clearing = true;
    try {
      await widget.gemmaService.clearChat();
    } catch (_) {
      _showSnackBar('Could not clear the conversation. Please try again.');
      return;
    } finally {
      _clearing = false;
    }
    if (!mounted) return;
    setState(_messages.clear);
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = _messages.isNotEmpty || _isGenerating;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _buildAppBar(hasContent),
        body: Column(
          children: [
            _PerformanceBar(
              gemmaService: widget.gemmaService,
              performanceMonitor: widget.performanceMonitor,
            ),
            Expanded(
              child: !hasContent
                  ? const _EmptyState()
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: _messages.length + (_isGenerating ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _messages.length) {
                            return _StreamingReply(reply: _streamingReply);
                          }
                          return _buildMessage(_messages[index]);
                        },
                      ),
                    ),
            ),
            ListenableBuilder(
              listenable: widget.performanceMonitor,
              builder: (context, _) => _InputBar(
                controller: _textController,
                focusNode: _focusNode,
                maxLength: widget.gemmaService.maxPromptChars,
                isGenerating: _isGenerating,
                isThrottled: widget.performanceMonitor.isThrottled,
                onSend: _sendMessage,
                onStop: _stopGeneration,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    // ListView.builder recreates bubbles that scroll back into view; only
    // play the entrance animation the first time a message is shown.
    final animate = !msg.hasAppeared;
    msg.hasAppeared = true;
    final bubble = ChatBubble(
      text: msg.text,
      isUser: msg.isUser,
      wasTruncated: msg.wasTruncated,
      animateEntrance: animate,
    );
    if (!msg.startsNewContext) return bubble;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [const _ContextResetNotice(), bubble],
    );
  }

  AppBar _buildAppBar(bool hasContent) {
    return AppBar(
      backgroundColor: AppTheme.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      title: const Text(
        'On-Device AI',
        style: TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            // 0.38 is the Material disabled-on-dark opacity; lower fails WCAG
            // AA against the black app bar.
            color: hasContent
                ? Colors.white70
                : Colors.white.withValues(alpha: 0.38),
          ),
          tooltip: 'Clear chat',
          onPressed: hasContent ? _clearChat : null,
        ),
      ],
    );
  }
}

class _StreamingReply extends StatelessWidget {
  final ValueListenable<String?> reply;

  const _StreamingReply({required this.reply});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: reply,
      builder: (context, text, _) {
        if (text == null || text.isEmpty) return const TypingIndicator();
        return ChatBubble(text: text, isUser: false, isStreaming: true);
      },
    );
  }
}

class _ContextResetNotice extends StatelessWidget {
  const _ContextResetNotice();

  @override
  Widget build(BuildContext context) {
    return const SelectionContainer.disabled(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(child: Divider(color: AppTheme.track, height: 1)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'Earlier messages are no longer in context',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
            Expanded(child: Divider(color: AppTheme.track, height: 1)),
          ],
        ),
      ),
    );
  }
}

class _PerformanceBar extends StatelessWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const _PerformanceBar({
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gemmaService, performanceMonitor]),
      builder: (context, _) {
        final isGenerating = gemmaService.isGenerating;
        final tps = gemmaService.tokensPerSecond;
        final throttled = performanceMonitor.isThrottled;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: AppTheme.surfaceSunken,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: AppTheme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                gemmaService.backendLabel,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              const Spacer(),
              if (isGenerating && tps > 0) ...[
                Text(
                  '${tps.toStringAsFixed(1)} tok/s',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
                const SizedBox(width: 8),
              ],
              if (throttled) ...[
                const Icon(
                  Icons.pause_circle_outline,
                  size: 13,
                  color: AppTheme.error,
                ),
                const SizedBox(width: 3),
                const Text(
                  'COOLDOWN',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_outlined,
              size: 36,
              color: Colors.white24,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ask me anything',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Running Gemma 4 E2B locally on your device',
            style: TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLength;
  final bool isGenerating;
  final bool isThrottled;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.maxLength,
    required this.isGenerating,
    required this.isThrottled,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final canSend = !isGenerating && !isThrottled;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPadding),
      color: AppTheme.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                // Keeps a single prompt within the model's context window.
                maxLength: maxLength,
                buildCounter: _buildCounter,
                textInputAction: TextInputAction.send,
                // Hardware Enter must not fire while blocked: _sendMessage
                // would silently drop the typed text.
                onSubmitted: (_) {
                  if (canSend) onSend();
                },
                style: const TextStyle(color: Colors.white, fontSize: 15),
                cursorColor: AppTheme.accent,
                decoration: InputDecoration(
                  hintText: 'Message...',
                  hintStyle: const TextStyle(
                    color: Colors.white30,
                    fontSize: 15,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: AppTheme.accent,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isGenerating)
            _ActionButton(
              onPressed: onStop,
              tooltip: 'Stop',
              backgroundColor: AppTheme.error,
              child: const Icon(
                Icons.stop_rounded,
                color: Colors.white,
                size: 22,
              ),
            )
          else
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                final hasText = controller.text.trim().isNotEmpty;
                final enabled = hasText && !isThrottled;
                return _ActionButton(
                  onPressed: enabled ? onSend : null,
                  tooltip: 'Send',
                  backgroundColor: enabled
                      ? AppTheme.accent
                      : AppTheme.disabled,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: enabled ? Colors.white : Colors.white30,
                    size: 22,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// Show the character counter only near the limit.
  static Widget? _buildCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) {
    if (maxLength == null || currentLength < maxLength * 0.9) return null;
    return Padding(
      padding: const EdgeInsets.only(right: 16, bottom: 6),
      child: Text(
        '$currentLength / $maxLength',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String tooltip;
  final Color backgroundColor;
  final Widget child;

  const _ActionButton({
    required this.onPressed,
    required this.tooltip,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool wasTruncated;

  /// Set on the user message whose send started a fresh model context.
  bool startsNewContext = false;

  /// Whether the bubble has been built once, so its entrance animation is not
  /// replayed when it scrolls back into view.
  bool hasAppeared = false;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.wasTruncated = false,
  });
}
