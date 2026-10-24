import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

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
    final bgColor = isDark ? AppColors.darkBg : AppColors.offWhiteBg;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.forestGreen;
    final subtitleColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF232A25) : AppColors.greenAccentPill,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                size: 36,
                color: AppColors.forestGreen,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'LedgerLeaf',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Opening your private offline vault...',
              style: TextStyle(
                fontSize: 14,
                color: subtitleColor,
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.forestGreen,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBg : AppColors.offWhiteBg;
    final cardBg = isDark ? AppColors.darkCard : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.expenseClay.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sync_problem_rounded,
                    size: 32,
                    color: AppColors.expenseClay,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Unable to Open Vault',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'LedgerLeaf encountered an error while starting up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2E3831) : const Color(0xFFE9E8E1),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          errorMessage,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forestGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.forestGreen,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF2E3831) : const Color(0xFFD6D4C8),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _confirmReset(context),
                    icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                    label: const Text(
                      'Reset & Repair Vault',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
