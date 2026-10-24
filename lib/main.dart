import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/settings_repository.dart';
import 'presentation/screens/main_navigation_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/startup_view.dart';
import 'services/app_state.dart';
import 'services/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Global Flutter framework error listener
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('LedgerLeaf FlutterError: ${details.exceptionAsString()}');
  };

  // 2. Global platform dispatcher asynchronous error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('LedgerLeaf Uncaught Async Error: $error\n$stack');
    return true; // Prevents process crash
  };

  // 3. Fallback error widget builder for runtime render crashes
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F6),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.expenseClay,
                  size: 44,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Interface Error',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forestGreen,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  sanitizeErrorMessage(details.exception),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  };

  // 4. Render app root immediately on frame 1 (eliminates white screen)
  runApp(const LedgerLeafApp());
}

enum StartupStatus { loading, ready, error }

class StartupData {
  final AppState appState;
  final bool onboardingCompleted;

  const StartupData({
    required this.appState,
    required this.onboardingCompleted,
  });
}

/// Default asynchronous initialization sequence
Future<StartupData> defaultInitializer() async {
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Preload settings & app state
  final dbHelper = DatabaseHelper();
  await dbHelper.database; // Ensure database tables are created & seeded

  final settingsRepo = SettingsRepository();
  final onboardingDone = await settingsRepo.getSetting(AppConstants.keyOnboardingCompleted) == 'true';

  final appState = AppState();
  await appState.initialize();

  // Initialize NativeBridge and drain any background App Intent queued events
  try {
    final nativeBridge = NativeBridge(appState);
    await nativeBridge.drainNativeQueue();
  } catch (e, st) {
    debugPrint('NativeBridge queue drain warning (non-fatal): $e\n$st');
  }

  return StartupData(
    appState: appState,
    onboardingCompleted: onboardingDone,
  );
}

class LedgerLeafApp extends StatefulWidget {
  final AppState? appState;
  final bool? initialOnboardingCompleted;
  final Future<StartupData> Function()? customInitializer;

  const LedgerLeafApp({
    super.key,
    this.appState,
    this.initialOnboardingCompleted,
    this.customInitializer,
  });

  @override
  State<LedgerLeafApp> createState() => _LedgerLeafAppState();
}

class _LedgerLeafAppState extends State<LedgerLeafApp> {
  late StartupStatus _status;
  AppState? _appState;
  bool _onboardingCompleted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.appState != null) {
      _appState = widget.appState;
      _onboardingCompleted = widget.initialOnboardingCompleted ?? false;
      _status = StartupStatus.ready;
    } else {
      _status = StartupStatus.loading;
      _startInitialization();
    }
  }

  Future<void> _startInitialization() async {
    setState(() {
      _status = StartupStatus.loading;
      _errorMessage = null;
    });

    try {
      final StartupData data;
      if (widget.customInitializer != null) {
        data = await widget.customInitializer!();
      } else {
        data = await defaultInitializer();
      }

      if (mounted) {
        setState(() {
          _appState = data.appState;
          _onboardingCompleted = data.onboardingCompleted;
          _status = StartupStatus.ready;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('LedgerLeaf startup failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _status = StartupStatus.error;
          _errorMessage = sanitizeErrorMessage(error);
        });
      }
    }
  }

  Future<void> _resetAndReinitialize() async {
    setState(() {
      _status = StartupStatus.loading;
      _errorMessage = null;
    });

    try {
      final dbHelper = DatabaseHelper();
      await dbHelper.wipeAndRecreateDatabase();
      await _startInitialization();
    } catch (error, stackTrace) {
      debugPrint('LedgerLeaf vault reset failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _status = StartupStatus.error;
          _errorMessage = sanitizeErrorMessage(error);
        });
      }
    }
  }

  void _finishOnboarding() {
    setState(() {
      _onboardingCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_status == StartupStatus.ready && _appState != null) {
      return ListenableBuilder(
        listenable: _appState!,
        builder: (context, _) {
          return MaterialApp(
            title: 'LedgerLeaf',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: _appState!.themeMode,
            home: _onboardingCompleted
                ? MainNavigationShell(appState: _appState!)
                : OnboardingScreen(onFinish: _finishOnboarding),
          );
        },
      );
    }

    return MaterialApp(
      title: 'LedgerLeaf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _status == StartupStatus.loading
          ? const StartupLoadingView()
          : StartupErrorView(
              errorMessage: _errorMessage ?? 'An unexpected error occurred during startup.',
              onRetry: _startInitialization,
              onResetDatabase: _resetAndReinitialize,
            ),
    );
  }
}
