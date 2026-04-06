import 'dart:async';

import 'package:flutter/material.dart';

import '../services/gemma_service.dart';
import '../services/performance_monitor.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/typing_indicator.dart';

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
              text: 'Error: $error',
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
          text: 'Error: $e',
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('On-Device AI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearChat,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: _PerformanceBar(
            gemmaService: widget.gemmaService,
            performanceMonitor: widget.performanceMonitor,
          ),
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? _EmptyState(theme: theme)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount:
                        _messages.length + (_isGenerating && _messages.last.text.isEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _messages.length) {
                        return const TypingIndicator();
                      }
                      final msg = _messages[index];
                      return ChatBubble(
                        text: msg.text,
                        isUser: msg.isUser,
                        isStreaming:
                            _isGenerating && index == _messages.length - 1 && !msg.isUser,
                      );
                    },
                  ),
          ),

          // Input area
          _InputBar(
            controller: _textController,
            focusNode: _focusNode,
            isGenerating: _isGenerating,
            onSend: _sendMessage,
            onStop: _stopGeneration,
          ),
        ],
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
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([gemmaService, performanceMonitor]),
      builder: (context, _) {
        final isGenerating = gemmaService.isGenerating;
        final tps = gemmaService.tokensPerSecond;
        final thermal = performanceMonitor.thermalState;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: theme.colorScheme.surfaceContainerLow,
          child: Row(
            children: [
              Icon(
                Icons.wifi_off,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                'Offline',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                gemmaService.backendInfo,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (isGenerating && tps > 0)
                Text(
                  '${tps.toStringAsFixed(1)} tok/s',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              if (thermal != ThermalState.nominal) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.thermostat,
                  size: 14,
                  color: thermal == ThermalState.critical
                      ? theme.colorScheme.error
                      : Colors.orange,
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
  final ThemeData theme;

  const _EmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.psychology,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Ask me anything',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Running Gemma 4 E2B locally on your device',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPadding),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Message...',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHigh,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (isGenerating)
            IconButton.filled(
              onPressed: onStop,
              icon: const Icon(Icons.stop),
              style: IconButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
            )
          else
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                return IconButton.filled(
                  onPressed:
                      controller.text.trim().isEmpty ? null : onSend,
                  icon: const Icon(Icons.arrow_upward),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  const _ChatMessage({required this.text, required this.isUser});
}
