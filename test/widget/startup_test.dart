import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/main.dart';
import 'package:ledgerleaf/presentation/screens/startup_view.dart';
import 'package:ledgerleaf/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Startup & Initialization Resilience Tests', () {
    test('sanitizeErrorMessage strips sensitive data and classifies error types', () {
      // 1. MissingPluginException
      final pluginErr = Exception('MissingPluginException(No implementation found for method openDatabase on channel com.tekartik.sqflite)');
      final pluginMsg = sanitizeErrorMessage(pluginErr);
      expect(pluginMsg, contains('Native iOS plugin channel was not found'));

      // 2. DatabaseException
      final dbErr = Exception('DatabaseException(SqliteException(1): no such table: accounts)');
      final dbMsg = sanitizeErrorMessage(dbErr);
      expect(dbMsg, contains('Database schema mismatch'));

      // 3. Sensitive PII in error should NOT be leaked
      final piiErr = Exception('Failed to parse SMS: Account 100012345678 debited ETB 5,000 for John Doe');
      final piiMsg = sanitizeErrorMessage(piiErr);
      expect(piiMsg, isNot(contains('100012345678')));
      expect(piiMsg, isNot(contains('John Doe')));
      expect(piiMsg, isNot(contains('5,000')));
      expect(piiMsg, equals('Initialization failed (_Exception).'));
    });

    testWidgets('StartupLoadingView renders branded offline vault indicator', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StartupLoadingView(),
        ),
      );

      expect(find.text('LedgerLeaf'), findsOneWidget);
      expect(find.text('Opening your private offline vault...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('StartupErrorView renders visible error card and triggers retry', (WidgetTester tester) async {
      bool retried = false;
      bool resetCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StartupErrorView(
            errorMessage: 'Local SQLite database could not be opened.',
            onRetry: () => retried = true,
            onResetDatabase: () => resetCalled = true,
          ),
        ),
      );

      expect(find.text('Unable to Open Vault'), findsOneWidget);
      expect(find.text('Local SQLite database could not be opened.'), findsOneWidget);

      // Verify Try Again button
      final retryBtn = find.text('Try Again');
      expect(retryBtn, findsOneWidget);
      await tester.tap(retryBtn);
      await tester.pump();
      expect(retried, isTrue);

      // Verify Reset button opens confirmation dialog
      final resetBtn = find.text('Reset & Repair Vault');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      expect(find.text('Reset Local Vault?'), findsOneWidget);
      final confirmReset = find.text('Reset Storage');
      expect(confirmReset, findsOneWidget);
      await tester.tap(confirmReset);
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);
    });

    testWidgets('LedgerLeafApp transitions from loading to ready when initialization succeeds', (WidgetTester tester) async {
      final appState = AppState();
      final completer = Completer<StartupData>();

      await tester.pumpWidget(
        LedgerLeafApp(
          customInitializer: () => completer.future,
        ),
      );

      // First frame: must render loading view immediately (no blank white screen)
      expect(find.byType(StartupLoadingView), findsOneWidget);
      expect(find.text('Opening your private offline vault...'), findsOneWidget);

      // Complete initialization
      completer.complete(StartupData(
        appState: appState,
        onboardingCompleted: true,
      ));
      await tester.pumpAndSettle();

      // Transited to MainNavigationShell
      expect(find.byType(StartupLoadingView), findsNothing);
      expect(find.text('LedgerLeaf'), findsWidgets);
    });

    testWidgets('LedgerLeafApp renders StartupErrorView when initialization fails and recovers on retry', (WidgetTester tester) async {
      final appState = AppState();
      bool shouldFail = true;

      await tester.pumpWidget(
        LedgerLeafApp(
          customInitializer: () async {
            await Future.delayed(const Duration(milliseconds: 20));
            if (shouldFail) {
              throw Exception('DatabaseException: database is locked');
            }
            return StartupData(
              appState: appState,
              onboardingCompleted: true,
            );
          },
        ),
      );

      // Initially shows loading
      expect(find.byType(StartupLoadingView), findsOneWidget);

      // Wait for async error
      await tester.pumpAndSettle();

      // Must display visible error view instead of a blank white screen
      expect(find.byType(StartupErrorView), findsOneWidget);
      expect(find.text('Unable to Open Vault'), findsOneWidget);
      expect(find.textContaining('Local database file is busy or locked'), findsOneWidget);

      // Now tap Try Again with shouldFail = false
      shouldFail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pump();

      // Returns to loading
      expect(find.byType(StartupLoadingView), findsOneWidget);

      // Completes successfully
      await tester.pumpAndSettle();
      expect(find.byType(StartupErrorView), findsNothing);
      expect(find.byType(StartupLoadingView), findsNothing);
    });
  });
}
