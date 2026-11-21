import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A chat message bubble with an optional slide-in entrance and a blinking
/// cursor while streaming. User messages slide in from the right, AI from the
/// left.
class ChatBubble extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;
  final bool wasTruncated;

  /// Play the entrance animation. Read once, when the bubble is first built.
  final bool animateEntrance;

  const ChatBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.isStreaming = false,
    this.wasTruncated = false,
    this.animateEntrance = true,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.animateEntrance ? 0.0 : 1.0,
    );

    _slideAnimation =
        Tween<Offset>(
          begin: Offset(widget.isUser ? 0.18 : -0.18, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    if (widget.animateEntrance) _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.isUser;
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.78,
            ),
            margin: EdgeInsetsDirectional.only(
              start: isUser ? 48 : 0,
              end: isUser ? 0 : 48,
              bottom: 8,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.accent : AppTheme.surface,
              // Directional so the tail corner sits on the sender's side in
              // both LTR and RTL locales.
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(AppTheme.radiusBubble),
                topEnd: const Radius.circular(AppTheme.radiusBubble),
                bottomStart: Radius.circular(
                  isUser ? AppTheme.radiusBubble : AppTheme.radiusBubbleTail,
                ),
                bottomEnd: Radius.circular(
                  isUser ? AppTheme.radiusBubbleTail : AppTheme.radiusBubble,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isUser)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Gemma',
                      style: TextStyle(
                        color: AppTheme.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                _BubbleText(
                  text: widget.text,
                  isUser: isUser,
                  isStreaming: widget.isStreaming,
                ),
                if (widget.wasTruncated && !isUser) const _TruncationNote(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TruncationNote extends StatelessWidget {
  const _TruncationNote();

  @override
  Widget build(BuildContext context) {
    // Excluded from selection so copying a reply gives just the body.
    return const SelectionContainer.disabled(
      child: Padding(
        padding: EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: AppTheme.accent,
              ),
            ),
            SizedBox(width: 4),
            // Flexible so the note wraps under large system font scales.
            Flexible(
              child: Text(
                'Response cut off at the length limit',
                style: TextStyle(
                  color: AppTheme.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message body. While [isStreaming], a blinking cursor follows the text.
class _BubbleText extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool isStreaming;

  const _BubbleText({
    required this.text,
    required this.isUser,
    required this.isStreaming,
  });

  @override
  State<_BubbleText> createState() => _BubbleTextState();
}

class _BubbleTextState extends State<_BubbleText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cursorController;
  late final Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    _cursorOpacity = CurvedAnimation(
      parent: _cursorController,
      curve: Curves.easeInOut,
    );
    _syncCursor();
  }

  @override
  void didUpdateWidget(_BubbleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStreaming != widget.isStreaming) _syncCursor();
  }

  void _syncCursor() {
    if (widget.isStreaming) {
      _cursorController.repeat(reverse: true);
    } else {
      _cursorController.stop();
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: widget.isUser ? AppTheme.textPrimary : AppTheme.textBody,
      fontSize: 15,
      height: 1.45,
    );

    if (!widget.isStreaming) return Text(widget.text, style: style);

    // The cursor sits in a WidgetSpan behind a FadeTransition, so blinking
    // repaints only its own layer instead of re-laying-out the paragraph.
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: widget.text),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: FadeTransition(
              opacity: _cursorOpacity,
              child: Text(
                ' |',
                style: style.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
      style: style,
    );
  }
}
