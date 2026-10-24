import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerleaf/main.dart';
import 'package:ledgerleaf/services/app_state.dart';

void main() {
  testWidgets('App smoke test - renders Onboarding or Dashboard', (WidgetTester tester) async {
    final appState = AppState();

    // Pump app with initial onboarding completed as false
    await tester.pumpWidget(LedgerLeafApp(
      appState: appState,
      initialOnboardingCompleted: false,
    ));

    expect(find.text('LedgerLeaf'), findsWidgets);
    expect(find.text('How iOS SMS Tracking Works'), findsNothing); // On 2nd carousel slide
  });
}
