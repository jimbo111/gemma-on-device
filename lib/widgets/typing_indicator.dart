import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Three-dot typing indicator styled to match the AI bubble.
///
/// One controller drives all three dots through staggered [Interval]s so the
/// pulse reads as a wave.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _dotCount = 3;

  /// Fraction of the cycle each dot's pulse spans.
  static const _windowSize = 0.45;

  /// Offset between consecutive dots' pulse start.
  static const _stepSize = 0.22;

  late final List<Animation<double>> _dotAnimations;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
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
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsetsDirectional.only(end: 48, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadiusDirectional.only(
            topStart: Radius.circular(AppTheme.radiusBubble),
            topEnd: Radius.circular(AppTheme.radiusBubble),
            bottomStart: Radius.circular(AppTheme.radiusBubbleTail),
            bottomEnd: Radius.circular(AppTheme.radiusBubble),
          ),
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

/// A dot that grows and brightens as [animation] goes from 0 to 1.
class _AnimatedDot extends StatelessWidget {
  final Animation<double> animation;
  final bool isLast;

  const _AnimatedDot({required this.animation, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final scale = 0.7 + (animation.value * 0.3);

    final opacity = (0.35 + animation.value * 0.65).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsetsDirectional.only(end: isLast ? 0.0 : 6.0),
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppTheme.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
