import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'services/gemma_service.dart';
import 'services/performance_monitor.dart';
import 'screens/setup_screen.dart';
import 'screens/chat_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // flutter_gemma logs every streamed token and the full prompt history via
  // debugPrint, which also runs in release. Silence it there: it costs work
  // per token and writes the user's conversation to the system log.
  if (kReleaseMode) debugPrint = (String? message, {int? wrapWidth}) {};

  runApp(
    OnDeviceAIApp(
      gemmaService: GemmaService(),
      performanceMonitor: PerformanceMonitor(),
    ),
  );
}

class OnDeviceAIApp extends StatelessWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const OnDeviceAIApp({
    super.key,
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'On-Device AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: AppShell(
        gemmaService: gemmaService,
        performanceMonitor: performanceMonitor,
      ),
    );
  }
}

/// Shows [SetupScreen] until the model is loaded, then [ChatScreen].
class AppShell extends StatefulWidget {
  final GemmaService gemmaService;
  final PerformanceMonitor performanceMonitor;

  const AppShell({
    super.key,
    required this.gemmaService,
    required this.performanceMonitor,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _setupComplete = false;

  void _onSetupComplete() {
    setState(() => _setupComplete = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_setupComplete) {
      return ChatScreen(
        gemmaService: widget.gemmaService,
        performanceMonitor: widget.performanceMonitor,
      );
    }

    return SetupScreen(
      gemmaService: widget.gemmaService,
      onSetupComplete: _onSetupComplete,
    );
  }
}
