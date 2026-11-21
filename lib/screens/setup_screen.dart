import 'package:flutter/material.dart';

import '../services/gemma_service.dart';
import '../theme/app_theme.dart';

/// Downloads the 2.6 GB model on first launch, then loads it. Later launches
/// skip straight to loading.
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
  // True while _startSetup is running. The service state lingers as `error`
  // for a tick after a retry tap; this keeps the spinner from blinking off.
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
    final service = widget.gemmaService;
    try {
      // Initialized here rather than in main() so a failure lands on the
      // retry UI instead of a black screen.
      await service.initFramework();

      if (!await service.isModelDownloaded()) {
        if (!mounted) return;
        setState(
          () => _statusMessage =
              'Downloading model...\nThis is a one-time setup.',
        );
      }
      await service.installModel();

      if (!mounted) return;
      setState(() => _statusMessage = 'Loading model...');
      await service.loadModel();

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
      backgroundColor: AppTheme.background,
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
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.18),
              blurRadius: 32,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Icon(
          Icons.psychology_rounded,
          size: 52,
          color: AppTheme.accent,
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
            color: AppTheme.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Powered by Gemma 4 E2B',
          style: TextStyle(
            color: AppTheme.textSecondary,
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
    if (isWorking) return true;
    // Listed explicitly so new enum values don't start showing a spinner.
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
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
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
              color: hasError ? AppTheme.error : AppTheme.textSecondary,
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
    // flutter_gemma reports only a percentage, not bytes.
    const sizeText = 'One-time download · 2.6 GB';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
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
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                percentText,
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: clampedProgress,
                backgroundColor: AppTheme.track,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            sizeText,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
          backgroundColor: AppTheme.error,
          foregroundColor: AppTheme.textPrimary,
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: AppTheme.success,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Text(
              '100% offline after setup\nNo internet connection required.',
              style: TextStyle(
                color: AppTheme.textSecondary,
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
