import 'dart:async';

import 'package:flutter/material.dart';

import '../services/gemma_service.dart';
import '../services/performance_monitor.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

// Design token constants — will be replaced by ThemeData integration later.
const _kBgColor = Color(0xFF000000);
const _kSurfaceColor = Color(0xFF181818);
const _kElevatedColor = Color(0xFF1E1E1E);
const _kAccentColor = Color(0xFF47A1E6);
const _kErrorColor = Color(0xFFCD5454);
const _kPerfBarColor = Color(0xFF0C0C0C);
const _kDisabledColor = Color(0xFF333333);

/// Main chat interface for interacting with Gemma 4 E2B on-device.
///
/// Features:
/// - Streaming token-by-token responses
/// - Performance status bar (thermal state, tokens/sec)
/// - Stop generation button
/// - Clear chat
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
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isGenerating = false;
  StreamSubscription<String>? _generationSub;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _generationSub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isGenerating) return;

    // Check throttle
    if (widget.performanceMonitor.shouldReduceLoad) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.performanceMonitor.statusDescription),
            behavior: SnackBarBehavior.floating,
            backgroundColor: _kSurfaceColor,
          ),
        );
      }
      return;
    }

    _textController.clear();
    _focusNode.requestFocus();

    // Add user message
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isGenerating = true;
    });
    _scrollToBottom();

    // Add empty AI message for streaming
    final aiMessageIndex = _messages.length;
    setState(() {
      _messages.add(_ChatMessage(text: '', isUser: false));
    });

    widget.performanceMonitor.startSession();

    try {
      final stream = widget.gemmaService.sendMessage(text);
      _generationSub = stream.listen(
        (token) {
          setState(() {
            _messages[aiMessageIndex] = _ChatMessage(
              text: _messages[aiMessageIndex].text + token,
              isUser: false,
            );
          });
          _scrollToBottom();
        },
        onDone: () {
          setState(() => _isGenerating = false);
          widget.performanceMonitor.endSession();
        },
        onError: (error) {
          setState(() {
            _isGenerating = false;
            _messages[aiMessageIndex] = _ChatMessage(
              text: 'Something went wrong. Please try again.',
              isUser: false,
            );
          });
          widget.performanceMonitor.endSession();
        },
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _messages[aiMessageIndex] = _ChatMessage(
          text: 'Something went wrong. Please try again.',
          isUser: false,
        );
      });
      widget.performanceMonitor.endSession();
    }
  }

  Future<void> _stopGeneration() async {
    _generationSub?.cancel();
    await widget.gemmaService.stopGeneration();
    widget.performanceMonitor.endSession();
    setState(() => _isGenerating = false);
  }

  Future<void> _clearChat() async {
    _generationSub?.cancel();
    await widget.gemmaService.clearChat();
    setState(() {
      _messages.clear();
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _kBgColor,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _PerformanceBar(
              gemmaService: widget.gemmaService,
              performanceMonitor: widget.performanceMonitor,
            ),
            // Messages list
            Expanded(
              child: _messages.isEmpty
                  ? const _EmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: _messages.length +
                          (_isGenerating && _messages.last.text.isEmpty
                              ? 1
                              : 0),
                      itemBuilder: (context, index) {
                        if (index >= _messages.length) {
                          return const TypingIndicator();
                        }
                        final msg = _messages[index];
                        return ChatBubble(
                          text: msg.text,
                          isUser: msg.isUser,
                          isStreaming: _isGenerating &&
                              index == _messages.length - 1 &&
                              !msg.isUser,
                        );
                      },
                    ),
            ),

            // Floating input bar
            _InputBar(
              controller: _textController,
              focusNode: _focusNode,
              isGenerating: _isGenerating,
              onSend: _sendMessage,
              onStop: _stopGeneration,
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _kBgColor,
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
            color: _messages.isEmpty
                ? Colors.white.withValues(alpha: 0.25)
                : Colors.white70,
          ),
          tooltip: 'Clear chat',
          onPressed: _messages.isEmpty ? null : _clearChat,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Performance bar
// ---------------------------------------------------------------------------

class _PerformanceBar extends StatelessWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const _PerformanceBar({
    required this.gemmaService,
    required this.performanceMonitor,
  });

  Color _thermalColor(ThermalState state) {
    switch (state) {
      case ThermalState.nominal:
        return _kAccentColor;
      case ThermalState.fair:
        return Colors.orange;
      case ThermalState.serious:
        return Colors.deepOrange;
      case ThermalState.critical:
        return _kErrorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([gemmaService, performanceMonitor]),
      builder: (context, _) {
        final isGenerating = gemmaService.isGenerating;
        final tps = gemmaService.tokensPerSecond;
        final thermal = performanceMonitor.thermalState;
        final showThermal = thermal != ThermalState.nominal;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          color: _kPerfBarColor,
          child: Row(
            children: [
              // Offline pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _kAccentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: _kAccentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'OFFLINE',
                      style: TextStyle(
                        color: _kAccentColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Backend info
              Text(
                gemmaService.backendInfo,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),

              const Spacer(),

              // Tokens/sec — only during active generation
              if (isGenerating && tps > 0) ...[
                Text(
                  '${tps.toStringAsFixed(1)} tok/s',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Thermal indicator
              if (showThermal) ...[
                Icon(
                  Icons.thermostat_rounded,
                  size: 13,
                  color: _thermalColor(thermal),
                ),
                const SizedBox(width: 3),
                Text(
                  thermal.name.toUpperCase(),
                  style: TextStyle(
                    color: _thermalColor(thermal),
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

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

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
            decoration: BoxDecoration(
              color: _kSurfaceColor,
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
            style: TextStyle(
              color: Colors.white38,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isGenerating;
  final VoidCallback onSend;
  final VoidCallback onStop;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomPadding),
      color: _kSurfaceColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _kElevatedColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                cursorColor: _kAccentColor,
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
                      color: _kAccentColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Stop button replaces send during generation
          if (isGenerating)
            _ActionButton(
              onPressed: onStop,
              backgroundColor: _kErrorColor,
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
                return _ActionButton(
                  onPressed: hasText ? onSend : null,
                  backgroundColor: hasText ? _kAccentColor : _kDisabledColor,
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: hasText ? Colors.white : Colors.white30,
                    size: 22,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Reusable circular action button for the input bar.
class _ActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Widget child;

  const _ActionButton({
    required this.onPressed,
    required this.backgroundColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
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
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
