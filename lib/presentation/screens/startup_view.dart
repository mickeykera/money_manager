import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../widgets/skeuomorphic.dart';

/// Sanitizes an initialization error into a safe, user-presentable message
/// that never leaks PII, account numbers, or raw transaction text.
String sanitizeErrorMessage(Object? error) {
  if (error == null) return 'An unknown startup error occurred.';
  final msg = error.toString();

  if (msg.contains('MissingPluginException')) {
    return 'Native iOS plugin channel was not found. Please ensure the app was built with Flutter plugin support.';
  }
  if (msg.contains('DatabaseException') || msg.contains('SqliteException')) {
    if (msg.contains('no such table')) {
      return 'Database schema mismatch. Storage reset is recommended.';
    }
    if (msg.contains('locked') || msg.contains('busy')) {
      return 'Local database file is busy or locked by another process.';
    }
    return 'Local SQLite database could not be opened or migrated.';
  }
  if (msg.contains('FileSystemException')) {
    return 'Unable to access device file storage. Please check app sandbox permissions.';
  }
  if (msg.contains('TimeoutException')) {
    return 'Startup timed out while opening local storage.';
  }

  // Safe generic description showing only runtime error type
  return 'Initialization failed (${error.runtimeType}).';
}

/// A branded, warm off-white loading view displayed on frame 1
/// while local SQLite tables and settings are opened.
class StartupLoadingView extends StatelessWidget {
  const StartupLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = AppColors.textPrimaryOf(context);
    final subtitleColor = AppColors.textSecondaryOf(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF262A2D), const Color(0xFF0E1011)]
                      : [const Color(0xFFF9F5ED), const Color(0xFFD9D3C6)],
                ),
                border: Border.all(color: AppColors.borderOf(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: isDark ? 0.05 : 0.65,
                    ),
                    blurRadius: 1,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Center(
                child: SkeuoInset(
                  width: 66,
                  height: 66,
                  radius: 33,
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 31,
                    color: AppColors.accentOf(context),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            Text(
              'LedgerLeaf',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Opening your private offline vault...',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.accentOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A user-friendly, visible startup error screen displayed instead of a blank white screen
/// if local database or plugin initialization fails.
class StartupErrorView extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onResetDatabase;

  const StartupErrorView({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    required this.onResetDatabase,
  });

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Local Vault?'),
        content: const Text(
          'This will delete the local SQLite database file and recreate default accounts and categories.\n\n'
          'Use this if an older database version is corrupted or incompatible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expenseClay,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onResetDatabase();
            },
            child: const Text('Reset Storage'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeuoInset(
                  width: 76,
                  height: 76,
                  radius: 38,
                  child: Icon(
                    Icons.sync_problem_rounded,
                    size: 34,
                    color: AppColors.expenseOf(context),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'Unable to Open Vault',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'LedgerLeaf encountered an error while starting up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
                const SizedBox(height: 24),
                SkeuoPanel(
                  inset: true,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.textMutedOf(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SkeuoButton(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry,
                ),
                const SizedBox(height: 12),
                SkeuoButton(
                  label: 'Reset & Repair Vault',
                  icon: Icons.cleaning_services_outlined,
                  secondary: true,
                  onPressed: () => _confirmReset(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
