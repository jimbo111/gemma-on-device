import 'package:flutter/material.dart';

import '../services/gemma_service.dart';

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

class _SetupScreenState extends State<SetupScreen> {
  String _statusMessage = 'Checking model...';
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _startSetup();
  }

  Future<void> _startSetup() async {
    try {
      // Step 1: Check if model is already installed
      final installed = await widget.gemmaService.isModelInstalled();

      if (!installed) {
        // Step 2a: Download model (first launch)
        if (!mounted) return;
        setState(() => _statusMessage = 'Downloading Gemma 4 E2B (2.6 GB)...\nThis is a one-time download.');
        await widget.gemmaService.downloadModel();
      }

      // Step 3: Load model into GPU memory
      if (!mounted) return;
      setState(() => _statusMessage = 'Loading model to GPU...');
      await widget.gemmaService.loadModel();

      // Done
      if (!mounted) return;
      widget.onSetupComplete();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _statusMessage = 'Setup failed: $e';
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _hasError = false;
      _statusMessage = 'Retrying...';
    });
    await _startSetup();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App icon / logo area
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.psychology,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'On-Device AI',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Powered by Gemma 4 E2B',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 48),

              // Progress section
              ListenableBuilder(
                listenable: widget.gemmaService,
                builder: (context, _) {
                  final state = widget.gemmaService.state;
                  final progress = widget.gemmaService.downloadProgress;

                  return Column(
                    children: [
                      if (state == GemmaServiceState.downloading) ...[
                        // Download progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: theme.colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(progress * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progress * 2.58).toStringAsFixed(1)} / 2.6 GB',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ] else if (state == GemmaServiceState.loading) ...[
                        const CircularProgressIndicator(),
                      ] else if (!_hasError) ...[
                        const CircularProgressIndicator(),
                      ],
                      const SizedBox(height: 16),

                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: _hasError
                              ? theme.colorScheme.error
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),

              if (_hasError) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],

              const SizedBox(height: 32),

              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'After setup, the AI runs 100% offline on your device. No internet needed.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
