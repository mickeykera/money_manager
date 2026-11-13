import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/settings_repository.dart';
import 'presentation/screens/main_navigation_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/startup_view.dart';
import 'presentation/widgets/skeuomorphic.dart';
import 'services/android_sms_service.dart';
import 'services/app_state.dart';
import 'services/native_bridge.dart';

/// Keeps the system status and navigation bars legible against the app's
/// warm stone (light) or charcoal (dark) material.
Widget _wrapWithSystemChrome(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return AnnotatedRegion<SystemUiOverlayStyle>(
    value: (isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    ),
    child: child,
  );
}

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
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF121415) : const Color(0xFFE7E3DA),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.expenseOf(context),
                      size: 44,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Interface Error',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryOf(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      sanitizeErrorMessage(details.exception),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
  final onboardingDone =
      await settingsRepo.getSetting(AppConstants.keyOnboardingCompleted) ==
      'true';

  final appState = AppState();
  await appState.initialize();

  // Initialize NativeBridge and drain any background App Intent queued events
  try {
    final nativeBridge = NativeBridge(appState);
    await nativeBridge.drainNativeQueue();
  } catch (e, st) {
    debugPrint('NativeBridge queue drain warning (non-fatal): $e\n$st');
  }

  // On Android, pull new bank/telecom SMS from the inbox in the background so
  // the dashboard is up to date without blocking startup.
  if (AndroidSmsService.isSupported) {
    unawaited(_autoImportAndroidSms(appState));
  }

  return StartupData(appState: appState, onboardingCompleted: onboardingDone);
}

Future<void> _autoImportAndroidSms(AppState appState) async {
  try {
    final summary = await AndroidSmsService.instance.importRecentMessages(
      appState,
    );
    debugPrint('Android SMS auto-import: ${summary.message}');
  } catch (error, stackTrace) {
    debugPrint(
      'Android SMS auto-import warning (non-fatal): $error\n$stackTrace',
    );
  }
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
            builder: (context, child) => _wrapWithSystemChrome(
              context,
              SkeuoBackdrop(child: child ?? const SizedBox.shrink()),
            ),
            home: _onboardingCompleted
                ? MainNavigationShell(appState: _appState!)
                : OnboardingScreen(
                    onFinish: _finishOnboarding,
                    appState: _appState,
                  ),
          );
        },
      );
    }

    return MaterialApp(
      title: 'LedgerLeaf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      builder: (context, child) => _wrapWithSystemChrome(
        context,
        SkeuoBackdrop(child: child ?? const SizedBox.shrink()),
      ),
      home: _status == StartupStatus.loading
          ? const StartupLoadingView()
          : StartupErrorView(
              errorMessage:
                  _errorMessage ??
                  'An unexpected error occurred during startup.',
              onRetry: _startInitialization,
              onResetDatabase: _resetAndReinitialize,
            ),
    );
  }
}
