import 'package:flutter/material.dart';

import 'services/gemma_service.dart';
import 'services/performance_monitor.dart';
import 'screens/setup_screen.dart';
import 'screens/chat_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Framework init is deferred to SetupScreen so any failure surfaces through
  // the normal retry UI rather than crashing to a black screen pre-runApp.
  runApp(OnDeviceAIApp(
    gemmaService: GemmaService(),
    performanceMonitor: PerformanceMonitor(),
  ));
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

/// Root shell that handles the setup -> chat flow.
///
/// On first launch: shows SetupScreen (downloads 2.58 GB model, loads to GPU).
/// On subsequent launches: loads model from local storage, then shows chat.
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
