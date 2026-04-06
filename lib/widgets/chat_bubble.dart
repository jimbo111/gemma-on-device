import 'package:flutter/material.dart';

/// A chat message bubble that supports user and AI messages.
class ChatBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: EdgeInsets.only(
          left: isUser ? 48 : 0,
          right: isUser ? 0 : 48,
          bottom: 8,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Gemma 4 E2B',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isUser
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            if (isStreaming) ...[
              const SizedBox(height: 4),
              _CursorIndicator(color: theme.colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

/// Blinking cursor shown at the end of a streaming AI response.
class _CursorIndicator extends StatefulWidget {
  final Color color;

  const _CursorIndicator({required this.color});

  @override
  State<_CursorIndicator> createState() => _CursorIndicatorState();
}

class _CursorIndicatorState extends State<_CursorIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _controller.value,
          child: Container(
            width: 8,
            height: 16,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      },
    );
  }
}
