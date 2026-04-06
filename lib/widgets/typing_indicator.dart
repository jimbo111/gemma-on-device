import 'package:flutter/material.dart';

// ─── Design tokens (hardcoded until theme agent ships) ───────────────────────
const _kAiBubbleColor = Color(0xFF181818);
const _kDotColor = Color(0xFF47A1E6);
const _kBubbleRadius = 20.0;
const _kTailRadius = 4.0;

/// Three-dot typing indicator styled to match the AI bubble.
///
/// Each dot pulses with a staggered, spring-like ease so the animation reads
/// as a wave rather than a simultaneous flash. A single [AnimationController]
/// drives all three dots via [Interval]-bounded [CurvedAnimation]s.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Each dot gets its own animation occupying a staggered window of the
  // total cycle. Using Curves.easeInOut inside each Interval produces the
  // spring-like feel without requiring external physics libraries.
  static const _dotCount = 3;

  // How much of the 1.0 cycle each dot's active window spans.
  static const _windowSize = 0.45;

  // Gap between consecutive dot start points.
  static const _stepSize = 0.22;

  late final List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      // Total cycle long enough that the last dot finishes with a comfortable
      // pause before the wave loops.
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _dotAnimations = List.generate(_dotCount, (i) {
      final start = i * _stepSize;
      final end = (start + _windowSize).clamp(0.0, 1.0);
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeInOut),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(right: 48, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: _kAiBubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(_kBubbleRadius),
            topRight: Radius.circular(_kBubbleRadius),
            bottomLeft: Radius.circular(_kTailRadius),
            bottomRight: Radius.circular(_kBubbleRadius),
          ),
          boxShadow: [
            BoxShadow(
              color: Color(0x14000000), // rgba(0,0,0,0.08)
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_dotCount, (i) {
                return _AnimatedDot(
                  animation: _dotAnimations[i],
                  isLast: i == _dotCount - 1,
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// ─── Single animated dot ─────────────────────────────────────────────────────

/// A single dot that scales and fades based on [animation] value [0..1].
/// Scale and opacity are driven by the same curve so the dot "pops" upward
/// and fades simultaneously, giving a pulse rather than a flat blink.
class _AnimatedDot extends StatelessWidget {
  final Animation<double> animation;
  final bool isLast;

  const _AnimatedDot({required this.animation, required this.isLast});

  @override
  Widget build(BuildContext context) {
    // Map animation value → scale: rest at 0.7, peak at 1.0.
    final scale = 0.7 + (animation.value * 0.3);

    // Map animation value → opacity: min 0.35, max 1.0.
    final opacity = (0.35 + animation.value * 0.65).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0.0 : 6.0),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: _kDotColor,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
