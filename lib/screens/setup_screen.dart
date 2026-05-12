import 'package:flutter/material.dart';

import '../services/gemma_service.dart';

// Hardcoded design tokens — theme integration deferred.
const _kBgColor = Color(0xFF000000);
const _kCardColor = Color(0xFF181818);
const _kAccent = Color(0xFF47A1E6);
const _kSuccess = Color(0xFF5BC682);
const _kError = Color(0xFFCD5454);
const _kTextPrimary = Color(0xFFFFFFFF);
const _kTextMuted = Color(0x80FFFFFF); // rgba(255,255,255,0.5)

/// Onboarding screen that handles model download and initialization.
///
/// Shows download progress for the 2.58 GB Gemma 4 E2B model on first launch.
/// On subsequent launches, skips straight to model loading (GPU warm-up).
class SetupScreen extends StatefulWidget {
  final GemmaService gemmaService;
  final VoidCallback onSetupComplete;

  const SetupScreen({
    super.key,
    required this.gemmaService,
    required this.onSetupComplete,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen>
    with SingleTickerProviderStateMixin {
  String _statusMessage = 'Checking model...';
  bool _hasError = false;
  // True while _startSetup is awaiting an async step. Without this, the
  // gemmaService state lingers as `error` for a tick after a retry tap,
  // and the spinner blinks off.
  bool _isWorking = true;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startSetup();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startSetup() async {
    try {
      // Step 0: Framework init (idempotent). Done here so failures surface
      // through this retry flow rather than crashing at app launch.
      await widget.gemmaService.initFramework();

      // Step 1: Check if model is already installed
      final installed = await widget.gemmaService.isModelInstalled();

      if (!installed) {
        // Step 2a: Download model (first launch)
        if (!mounted) return;
        setState(() => _statusMessage = 'Downloading model...\nThis is a one-time setup.');
        await widget.gemmaService.downloadModel();
      }

      // Step 3: Load model into GPU memory
      if (!mounted) return;
      setState(() => _statusMessage = 'Loading model to GPU...');
      await widget.gemmaService.loadModel();

      // Done
      if (!mounted) return;
      _isWorking = false;
      widget.onSetupComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isWorking = false;
        _statusMessage = 'Setup failed: $e';
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _isWorking = true;
      _statusMessage = 'Retrying...';
    });
    await _startSetup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _AppIconArea(pulseAnimation: _pulseAnimation),
              const SizedBox(height: 28),
              _AppTitleBlock(),
              const Spacer(flex: 2),
              ListenableBuilder(
                listenable: widget.gemmaService,
                builder: (context, _) {
                  return _ProgressSection(
                    state: widget.gemmaService.state,
                    progress: widget.gemmaService.downloadProgress,
                    statusMessage: _statusMessage,
                    hasError: _hasError,
                    isWorking: _isWorking,
                  );
                },
              ),
              if (_hasError) ...[
                const SizedBox(height: 24),
                _RetryButton(onRetry: _retry),
              ],
              const Spacer(flex: 1),
              // Don't advertise "100% offline" while actively downloading —
              // the user is demonstrably online at that moment.
              ListenableBuilder(
                listenable: widget.gemmaService,
                builder: (context, _) {
                  if (widget.gemmaService.state ==
                      GemmaServiceState.downloading) {
                    return const SizedBox.shrink();
                  }
                  return const _OfflineInfoCard();
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _AppIconArea extends StatelessWidget {
  final Animation<double> pulseAnimation;

  const _AppIconArea({required this.pulseAnimation});

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: pulseAnimation,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: _kCardColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _kAccent.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _kAccent.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.psychology_rounded,
          size: 52,
          color: _kAccent,
        ),
      ),
    );
  }
}

class _AppTitleBlock extends StatelessWidget {
  const _AppTitleBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'On-Device AI',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Powered by Gemma 4 E2B',
          style: TextStyle(
            color: _kTextMuted,
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final GemmaServiceState state;
  final double progress;
  final String statusMessage;
  final bool hasError;
  final bool isWorking;

  const _ProgressSection({
    required this.state,
    required this.progress,
    required this.statusMessage,
    required this.hasError,
    required this.isWorking,
  });

  bool get _showDownloadCard => state == GemmaServiceState.downloading;

  bool get _showSpinner {
    if (hasError) return false;
    if (_showDownloadCard) return false;
    // Show a spinner whenever the screen is mid-setup, regardless of
    // whether the service state has caught up. This bridges the gap on
    // retry where state lingers as `error` for a tick.
    if (isWorking) return true;
    // Explicitly list the "working, no progress bar yet" states so future
    // enum additions don't silently start showing a spinner.
    return state == GemmaServiceState.uninitialized ||
        state == GemmaServiceState.downloaded ||
        state == GemmaServiceState.loading;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showDownloadCard) ...[
          _DownloadProgressCard(progress: progress),
          const SizedBox(height: 20),
        ] else if (_showSpinner) ...[
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(_kAccent),
            ),
          ),
          const SizedBox(height: 20),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: hasError ? _kError : _kTextMuted,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DownloadProgressCard extends StatelessWidget {
  final double progress;

  const _DownloadProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);
    final percentText = '${(clampedProgress * 100).toStringAsFixed(1)}%';
    // flutter_gemma only exposes a 0-100 percentage — actual byte totals
    // aren't available, so we don't fabricate a "X / Y GB" readout.
    const sizeText = 'One-time download • ~2-3 GB';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DOWNLOADING MODEL',
                style: TextStyle(
                  color: _kTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                percentText,
                style: const TextStyle(
                  color: _kAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Custom progress track
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: clampedProgress,
                backgroundColor: const Color(0xFF2A2A2A),
                valueColor: const AlwaysStoppedAnimation<Color>(_kAccent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sizeText,
            style: const TextStyle(
              color: _kTextMuted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryButton({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onRetry,
        style: TextButton.styleFrom(
          backgroundColor: _kError,
          foregroundColor: _kTextPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: const Text(
          'RETRY SETUP',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _OfflineInfoCard extends StatelessWidget {
  const _OfflineInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _kCardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _kSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: _kSuccess,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '100% offline after setup\nNo internet connection required.',
              style: TextStyle(
                color: _kTextMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
