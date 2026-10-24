import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/database/database_helper.dart';
import 'data/repositories/settings_repository.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'services/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(LedgerLeafApp(
    appState: appState,
    initialOnboardingCompleted: onboardingDone,
  ));
}

class LedgerLeafApp extends StatefulWidget {
  final AppState appState;
  final bool initialOnboardingCompleted;

  const LedgerLeafApp({
    super.key,
    required this.appState,
    required this.initialOnboardingCompleted,
  });

  @override
  State<LedgerLeafApp> createState() => _LedgerLeafAppState();
}

class _LedgerLeafAppState extends State<LedgerLeafApp> {
  late bool _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _onboardingCompleted = widget.initialOnboardingCompleted;
  }

  void _finishOnboarding() {
    setState(() {
      _onboardingCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'LedgerLeaf',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: widget.appState.themeMode,
          home: _onboardingCompleted
              ? DashboardScreen(appState: widget.appState)
              : OnboardingScreen(onFinish: _finishOnboarding),
        );
      },
    );
  }
}
