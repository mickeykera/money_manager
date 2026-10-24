import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import '../../services/ingestion_service.dart';

class AutomationSetupScreen extends StatefulWidget {
  final AppState? appState;

  const AutomationSetupScreen({super.key, this.appState});

  @override
  State<AutomationSetupScreen> createState() => _AutomationSetupScreenState();
}

class _AutomationSetupScreenState extends State<AutomationSetupScreen> {
  int _currentStep = 0;
  final TextEditingController _testMessageController = TextEditingController();
  String _selectedSender = 'CBE';
  IngestionResponse? _testResult;
  bool _isTesting = false;

  final Map<String, String> _sampleMessages = {
    'CBE (Debit)':
        'Dear Customer, your Account 1000****1234 has been debited with ETB 350.00 on 24/10/2026 for Purchase at Fresh Corner. Current Balance is ETB 14,250.75. Ref: FT242981234.',
    'Telebirr (Payment)':
        'You have paid ETB 250.00 to Kaldi\'s Coffee (0911****00) on 2026-10-24 14:30:15. Transaction number is TB261024.1430.A12345. Your current balance is ETB 1,840.50.',
    'Telebirr (Received)':
        'You have received ETB 1,200.00 from Dawit Tsige (0933****22) on 2026-10-24 16:45:00. Transaction number: TB261024.1645.C11223. Your current balance is ETB 2,540.50.',
    'Bank of Abyssinia':
        'Dear Customer, your account BOA****5678 has been debited by ETB 820.50 on 24-Oct-2026 11:20:00. Txn Ref: BOA261024987. Available Bal: ETB 8,450.00. Thank you for banking with Bank of Abyssinia.',
    'Dashen Bank':
        'Dear Customer, Account 5100****4321 debited with ETB 1,450.00 on 24/10/2026. Reason: POS Purchase at Shoa Supermarket. Avail Bal: ETB 6,200.00. Txn ID: DSH261024001.',
    'Security OTP (Rejection Test)':
        'Your CBE Birr OTP is 849201. Do not share this secret verification code with anyone including bank staff.',
  };

  @override
  void initState() {
    super.initState();
    _testMessageController.text = _sampleMessages['CBE (Debit)']!;
  }

  @override
  void dispose() {
    _testMessageController.dispose();
    super.dispose();
  }

  void _runSimulation() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final text = _testMessageController.text.trim();
    if (widget.appState != null) {
      final res = await widget.appState!.ingestSms(text, sender: _selectedSender);
      setState(() {
        _isTesting = false;
        _testResult = res;
      });
    } else {
      final service = IngestionService();
      final res = await service.processIncomingSms(rawMessage: text, sender: _selectedSender);
      setState(() {
        _isTesting = false;
        _testResult = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Automatic Tracking Setup'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 3) {
            setState(() => _currentStep++);
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep--);
          }
        },
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (_currentStep < 3)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('Next Step'),
                  ),
                if (_currentStep == 3)
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Finish Setup'),
                  ),
                const SizedBox(width: 12),
                if (_currentStep > 0)
                  OutlinedButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Back'),
                  ),
              ],
            ),
          );
        },
        steps: [
          // Step 1: iOS Sandbox & Capabilities
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            title: const Text('iOS Sandbox & Feasibility'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.sagePrimary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'iOS does not permit any app to passively read your SMS messages in the background. Instead, Apple Shortcuts Personal Automation gives you 100% control.',
                          style: TextStyle(fontSize: 12, height: 1.4, color: secondaryTextColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'What Works on iOS 17+:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor),
                ),
                const SizedBox(height: 6),
                _buildBullet(
                    'Automatic Headless Execution: Transactions log without opening the app when "Run Immediately" is enabled.'),
                _buildBullet(
                    'Works While Locked: As long as the phone has been unlocked once since boot, transactions save silently in your pocket.'),
                _buildBullet('100% Offline: No internet connection is needed to parse or store transactions.'),
              ],
            ),
          ),

          // Step 2: Configure Personal Automation in Shortcuts
          Step(
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            title: const Text('Create Personal Automation'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Follow these exact steps inside Apple\'s native Shortcuts app:',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
                const SizedBox(height: 12),
                _buildNumberedStep(1, 'Open the Shortcuts app on your iPhone.'),
                _buildNumberedStep(2, 'Tap the Automation tab at the bottom, then tap + (New Automation).'),
                _buildNumberedStep(3, 'Scroll down and select Message.'),
                _buildNumberedStep(
                    4, 'Tap Sender and enter your bank shortcode or name (e.g. CBE, Telebirr, 127).'),
                _buildNumberedStep(
                    5, 'Crucial: Under Run, select "Run Immediately" and turn OFF "Notify When Run".'),
                _buildNumberedStep(
                    6, 'Tap Next, search for "LedgerLeaf", and choose "Log Transaction from SMS".'),
                _buildNumberedStep(7, 'Set Message Text to "Shortcut Input" and tap Done.'),
              ],
            ),
          ),

          // Step 3: Test Parser & Persistence Simulator
          Step(
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            title: const Text('Test Simulation Bench'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select a sample bank alert to test how LedgerLeaf parses, categorizes, and saves the transaction:',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
                const SizedBox(height: 10),

                // Sample Message Selector
                DropdownButtonFormField<String>(
                  initialValue: _sampleMessages.keys.first,
                  decoration: const InputDecoration(
                    labelText: 'Sample Bank Message',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _sampleMessages.keys.map((k) {
                    return DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(fontSize: 13)));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _testMessageController.text = _sampleMessages[val]!;
                        if (val.contains('Telebirr')) {
                          _selectedSender = 'Telebirr';
                        } else if (val.contains('Abyssinia')) {
                          _selectedSender = 'Abyssinia';
                        } else if (val.contains('Dashen')) {
                          _selectedSender = 'Dashen';
                        } else {
                          _selectedSender = 'CBE';
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 10),

                // Editable SMS Body
                TextField(
                  controller: _testMessageController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    labelText: 'SMS Content to Ingest',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),

                // Ingest Test Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Test Ingestion Pipeline'),
                    onPressed: _isTesting ? null : _runSimulation,
                  ),
                ),

                // Test Output Card
                if (_testResult != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _testResult!.success
                          ? (isDark ? AppColors.sagePrimary.withOpacity(0.2) : AppColors.sageContainer)
                          : (isDark ? AppColors.clayPrimary.withOpacity(0.2) : AppColors.clayContainer),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _testResult!.success ? AppColors.sagePrimary : AppColors.clayPrimary,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _testResult!.success ? Icons.check_circle : Icons.error,
                              size: 18,
                              color: _testResult!.success ? AppColors.sagePrimary : AppColors.clayPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _testResult!.success ? 'Ingestion Successful' : 'Ingestion Dropped',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _testResult!.success ? AppColors.sagePrimary : AppColors.clayPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _testResult!.message,
                          style: TextStyle(fontSize: 12, color: primaryTextColor),
                        ),
                        if (_testResult!.transaction != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Parsed Merchant: ${_testResult!.transaction!.merchant}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'Amount: ${_testResult!.transaction!.money.format()}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (_testResult!.transaction!.reference != null)
                            Text(
                              'Reference: ${_testResult!.transaction!.reference}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Step 4: Verification & Readiness
          Step(
            isActive: _currentStep >= 3,
            state: StepState.complete,
            title: const Text('Ready for Live Tracking'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your LedgerLeaf instance is configured!',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Next time your bank or mobile money sends you an SMS, iOS Shortcuts will invoke LedgerLeaf in the background. The transaction will appear on your Dashboard immediately with zero manual input required.',
                  style: TextStyle(fontSize: 13, height: 1.4, color: secondaryTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.3))),
        ],
      ),
    );
  }

  Widget _buildNumberedStep(int stepNum, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.sagePrimary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNum',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }
}
