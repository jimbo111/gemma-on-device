import 'package:flutter/material.dart';

// ─── Design tokens (hardcoded until theme agent ships) ───────────────────────
const _kUserBubbleColor = Color(0xFF47A1E6);
const _kAiBubbleColor = Color(0xFF181818);
const _kUserTextColor = Color(0xFFFFFFFF);
const _kAiTextColor = Color(0xE6FFFFFF); // rgba(255,255,255,0.9)
const _kAiLabelColor = Color(0xFF47A1E6);
const _kBubbleRadius = 20.0;
const _kTailRadius = 4.0;

/// A chat message bubble with a slide-in entrance animation and optional
/// streaming cursor. User messages slide in from the right; AI from the left.
///
/// Public API is intentionally minimal so call sites need no changes:
///   ChatBubble(text: ..., isUser: ..., isStreaming: ...)
class ChatBubble extends StatefulWidget {
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
    );

    // User slides from right (+x), AI slides from left (-x).
    final beginOffset =
        widget.isUser ? const Offset(0.18, 0) : const Offset(-0.18, 0);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        // Fade completes in the first 60 % of the slide duration.
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Align(
          alignment: widget.isUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            margin: EdgeInsetsDirectional.only(
              start: widget.isUser ? 48 : 0,
              end: widget.isUser ? 0 : 48,
              bottom: 8,
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.isUser ? _kUserBubbleColor : _kAiBubbleColor,
              // Directional so the "tail" (small corner) sits on the user's
              // side in both LTR and RTL locales.
              borderRadius: BorderRadiusDirectional.only(
                topStart: const Radius.circular(_kBubbleRadius),
                topEnd: const Radius.circular(_kBubbleRadius),
                bottomStart: Radius.circular(
                    widget.isUser ? _kBubbleRadius : _kTailRadius),
                bottomEnd: Radius.circular(
                    widget.isUser ? _kTailRadius : _kBubbleRadius),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000), // rgba(0,0,0,0.08)
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!widget.isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'Gemma',
                      style: const TextStyle(
                        color: _kAiLabelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                _BubbleText(
                  text: widget.text,
                  isUser: widget.isUser,
                  isStreaming: widget.isStreaming,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Bubble body text with optional streaming cursor ─────────────────────────

/// Renders the message text. While [isStreaming] is true a blinking `|`
/// cursor is appended inline using a [TextSpan], keeping layout stable.
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

  @override
  void initState() {
    super.initState();
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    if (widget.isStreaming) _cursorController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_BubbleText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && !_cursorController.isAnimating) {
      _cursorController.repeat(reverse: true);
    } else if (!widget.isStreaming && _cursorController.isAnimating) {
      _cursorController.stop();
      // Ensure cursor is invisible after streaming ends.
      _cursorController.value = 0;
    }
  }

  @override
  void dispose() {
    _cursorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor =
        widget.isUser ? _kUserTextColor : _kAiTextColor;

    if (!widget.isStreaming) {
      return Text(
        widget.text,
        style: TextStyle(
          color: baseColor,
          fontSize: 15,
          height: 1.45,
        ),
      );
    }

    // Inline blinking cursor via AnimatedBuilder so only the RichText
    // redraws — the parent bubble layout is unaffected.
    return AnimatedBuilder(
      animation: _cursorController,
      builder: (context, _) {
        // Ease in/out so the blink feels smooth, not mechanical.
        final opacity =
            Curves.easeInOut.transform(_cursorController.value);
        return RichText(
          text: TextSpan(
            style: TextStyle(
              color: baseColor,
              fontSize: 15,
              height: 1.45,
            ),
            children: [
              TextSpan(text: widget.text),
              TextSpan(
                text: ' |',
                style: TextStyle(
                  color: _kAiLabelColor.withValues(alpha: opacity),
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
