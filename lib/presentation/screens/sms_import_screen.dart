import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../services/android_sms_service.dart';
import '../../services/app_state.dart';
import '../widgets/skeuomorphic.dart';
import 'transaction_detail_screen.dart';

class SmsImportScreen extends StatefulWidget {
  final AppState appState;

  const SmsImportScreen({super.key, required this.appState});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  final TextEditingController _customSmsController = TextEditingController();
  bool _androidPermissionGranted = false;
  bool _isImporting = false;
  SmsImportSummary? _lastAndroidImport;

  @override
  void initState() {
    super.initState();
    if (AndroidSmsService.isSupported) {
      _refreshAndroidPermission();
    }
  }

  @override
  void dispose() {
    _customSmsController.dispose();
    super.dispose();
  }

  Future<void> _refreshAndroidPermission() async {
    final granted = await AndroidSmsService.instance.hasPermission();
    if (mounted) {
      setState(() => _androidPermissionGranted = granted);
    }
  }

  Future<void> _importAndroidSms() async {
    if (_isImporting) return;
    setState(() => _isImporting = true);

    try {
      var granted = _androidPermissionGranted;
      if (!granted) {
        granted = await AndroidSmsService.instance.requestPermission();
      }
      if (mounted) {
        setState(() => _androidPermissionGranted = granted);
      }

      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'SMS permission was not granted. Enable it in Settings > Apps > LedgerLeaf > Permissions.',
              ),
              backgroundColor: AppColors.expenseClay,
            ),
          );
        }
        return;
      }

      final summary = await AndroidSmsService.instance.importRecentMessages(
        widget.appState,
        includeAlreadySynced: true,
      );
      if (mounted) {
        setState(() => _lastAndroidImport = summary);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(summary.message),
            backgroundColor: summary.isSuccess
                ? AppColors.forestGreen
                : AppColors.expenseClay,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _openAppleShortcuts() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_mosaic, color: AppColors.forestGreen),
            SizedBox(width: 8),
            Text('Apple Shortcuts'),
          ],
        ),
        content: const Text(
          'On your iPhone:\n\n'
          '1. Swipe down on your Home Screen and search for "Shortcuts".\n'
          '2. Switch to the Automation tab at the bottom.\n'
          '3. Tap "+" and select Message.\n'
          '4. Connect it to LedgerLeaf App Intent.\n\n'
          'Once configured, iOS forwards matching bank SMS automatically!',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showTestSmsDialog() {
    final sampleMessages = [
      {
        'title': 'CBE Debit (Fresh Corner)',
        'sender': '127',
        'sms': 'Dear Customer, ETB 64.80 has been debited from your account 1000***4821 for Purchase at Fresh Corner. Balance: ETB 4,280.50.',
      },
      {
        'title': 'Telebirr Payment (Kaldi\'s Coffee)',
        'sender': 'Telebirr',
        'sms': 'Your payment of ETB 180.00 to Kaldis Coffee (0911234567) completed. Trans ID: R5678GH. Bal: ETB 3,450.00.',
      },
      {
        'title': 'Safaricom M-PESA (Paid Merchant)',
        'sender': '700',
        'sms': 'TD94RNM67E Confirmed. ETB 450.00 paid to Safaricom Supermarket 0712345678 on 24/10/26 at 10:30 AM. New M-PESA balance is ETB 1,820.00.',
      },
      {
        'title': 'Bank of Abyssinia Salary Credit',
        'sender': 'Abyssinia',
        'sms': 'Your account 123***456 has been credited with ETB 15,000.00 from Acme Studio. Ref: TX99812. Available bal: ETB 28,500.00.',
      },
      {
        'title': 'Ethio telecom 10GB Data Purchase',
        'sender': '994',
        'sms': 'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.',
      },
      {
        'title': 'Ethio telecom *804# Balance Check',
        'sender': 'Ethio telecom',
        'sms': 'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.',
      },
      {
        'title': 'Safaricom 5GB Weekly Purchase',
        'sender': 'Safaricom',
        'sms': 'Dear customer, you have successfully purchased 5GB Weekly Data bundle for ETB 150.00. Valid until 2026-11-01 23:59:59.',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Test Ingestion with Sample SMS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a realistic Ethiopian bank or telecom message to test local parsing and automatic capture.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...sampleMessages.map(
                (sample) => SkeuoPanel(
                  margin: const EdgeInsets.only(bottom: 12),
                  radius: 14,
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    title: Text(
                      sample['title']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        sample['sms']!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryOf(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: Icon(
                      Icons.play_circle_outline,
                      color: AppColors.accentOf(context),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final res = await widget.appState.ingestSms(
                        sample['sms']!,
                        sender: sample['sender'],
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: res.success
                                ? null
                                : AppColors.expenseOf(context),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              const Divider(height: 28),
              const Text(
                'Or Paste Custom SMS:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customSmsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Paste any SMS message here...',
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  if (_customSmsController.text.trim().isNotEmpty) {
                    final text = _customSmsController.text.trim();
                    _customSmsController.clear();
                    Navigator.pop(ctx);
                    final res = await widget.appState.ingestSms(text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(res.message),
                          backgroundColor: res.success
                              ? AppColors.forestGreen
                              : AppColors.expenseClay,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Simulate Ingestion'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appState = widget.appState;
    final pendingCount = appState.pendingReviewTransactions.length;
    final isAndroid = AndroidSmsService.isSupported;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('SMS import'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: isAndroid
                ? 'SMS import help'
                : 'Shortcuts Automation Guide',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Subtitle
          Text(
            'Your messages. Your control.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondaryOf(context),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 20),

          // Privacy Card
          SkeuoPanel(
            radius: 17,
            padding: const EdgeInsets.all(17),
            color: isDark
                ? const Color(0xFF201D15)
                : const Color(0xFFF1EADA),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeuoIconWell(
                  icon: Icons.verified_user_outlined,
                  size: 40,
                  iconSize: 20,
                  radius: 11,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAndroid
                            ? 'Private by design'
                            : 'Only what you choose to share',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        isAndroid
                            ? 'After you grant SMS access, LedgerLeaf reads recent bank and telecom alerts on this phone. Messages are parsed on-device and never uploaded.'
                            : 'LedgerLeaf can\'t read your SMS inbox. Your personal automation forwards only matching messages.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Import status card
          if (isAndroid)
            _buildAndroidStatusCard(isDark, appState)
          else
            SkeuoPanel(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeuoIconWell(
                        icon: Icons.auto_awesome_mosaic,
                        size: 32,
                        iconSize: 16,
                        radius: 9,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Apple Shortcuts',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                          color: AppColors.textPrimaryOf(context),
                        ),
                      ),
                      const Spacer(),
                      Builder(
                        builder: (context) {
                          final smsTransactions = appState.transactions
                              .where(
                                (tx) => tx.source == AppConstants.sourceSms,
                              )
                              .toList();
                          final hasImportedSms = smsTransactions.isNotEmpty;
                          return SkeuoBadge(
                            label: hasImportedSms
                                ? 'Active Automation'
                                : 'Ready to Connect',
                            icon: Icons.circle,
                            tone: hasImportedSms
                                ? SkeuoBadgeTone.accent
                                : SkeuoBadgeTone.neutral,
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final smsTransactions = appState.transactions
                          .where((tx) => tx.source == AppConstants.sourceSms)
                          .toList();
                      final hasImportedSms = smsTransactions.isNotEmpty;
                      if (hasImportedSms) {
                        final lastTime = DateFormat('MMM d, h:mm a')
                            .format(smsTransactions.first.timestamp);
                        return Text(
                          'Last automated alert: $lastTime\nProcessed on-device with zero cloud telemetry',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.textSecondaryOf(context),
                          ),
                        );
                      }
                      return Text(
                        'Awaiting personal automation configuration in Shortcuts app.\nUse "Test with sample SMS" below to simulate local parsing.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),

          // Set up automatic import / personal automation section
          Text(
            isAndroid
                ? 'Set up automatic SMS import'
                : 'Set up a personal automation',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 14),

          if (isAndroid) ...[
            _buildStepRow(
              number: '1',
              title: 'Allow SMS access',
              body: 'Tap "Allow SMS access & import" below. Android asks once; LedgerLeaf only reads messages after you approve.',
              isDark: isDark,
            ),
            _buildStepRow(
              number: '2',
              title: 'Existing alerts are imported',
              body: 'The last 12 months of bank and telecom SMS are scanned on-device and parsed into transactions.',
              isDark: isDark,
            ),
            _buildStepRow(
              number: '3',
              title: 'New messages keep flowing',
              body: 'Incoming SMS are queued in the background and imported the next time you open LedgerLeaf. No cloud services are used.',
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            SkeuoButton(
              label: _isImporting
                  ? 'Importing SMS...'
                  : _androidPermissionGranted
                  ? 'Import SMS now'
                  : 'Allow SMS access & import',
              icon: Icons.sms_outlined,
              height: 54,
              onPressed: _isImporting ? null : _importAndroidSms,
              trailing: _isImporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE0C892),
                      ),
                    )
                  : null,
            ),
            if (_lastAndroidImport != null) ...[
              const SizedBox(height: 10),
              Text(
                _lastAndroidImport!.message,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: _lastAndroidImport!.isSuccess
                      ? AppColors.incomeOf(context)
                      : AppColors.expenseOf(context),
                ),
              ),
            ],
          ] else ...[
            _buildStepRow(
              number: '1',
              title: 'Open Shortcuts → Automation',
              body: 'Tap + to create a personal automation, then choose the Message trigger.',
              isDark: isDark,
            ),
            _buildStepRow(
              number: '2',
              title: 'Choose which messages to share',
              body: 'For this account, select sender 127/CBE, Telebirr, or Safaricom and Message Contains keywords.',
              isDark: isDark,
            ),
            _buildStepRow(
              number: '3',
              title: 'Send the message to LedgerLeaf',
              body: 'Choose New Blank Automation. Add Get Text from Shortcut Input, then LedgerLeaf → Import message.',
              isDark: isDark,
            ),
            _buildStepRow(
              number: '4',
              title: 'Save and allow it to run',
              body: 'Choose Run Immediately if available; otherwise confirm each run. Save, then check alerts here.',
              isDark: isDark,
            ),

            // Link: Open Shortcuts ↗
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openAppleShortcuts,
                icon: Text(
                  'Open Shortcuts',
                  style: TextStyle(
                    color: AppColors.accentOf(context),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                label: Icon(
                  Icons.north_east,
                  size: 14,
                  color: AppColors.accentOf(context),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Test ingestion action
          SkeuoButton(
            label: 'Test with sample SMS',
            icon: Icons.play_arrow,
            height: 54,
            secondary: true,
            onPressed: _showTestSmsDialog,
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Preview only. Won\'t duplicate your transactions.',
              style: TextStyle(
                fontSize: 11.5,
                color: AppColors.textMutedOf(context),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Pending Review Queue (if any)
          if (pendingCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Review Queue',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                SkeuoBadge(
                  label: '$pendingCount needs review',
                  tone: SkeuoBadgeTone.danger,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...appState.pendingReviewTransactions.take(3).map((tx) {
              final cat = appState.categories.firstWhere(
                (c) => c.id == tx.categoryId,
                orElse: () => appState.categories.first,
              );
              final acc = appState.accounts.firstWhere(
                (a) => a.id == tx.accountId,
                orElse: () => appState.accounts.first,
              );
              return SkeuoPanel(
                margin: const EdgeInsets.only(bottom: 10),
                radius: 14,
                padding: EdgeInsets.zero,
                child: ListTile(
                  leading: const SkeuoInset(
                    width: 38,
                    height: 38,
                    radius: 19,
                    child: Icon(
                      Icons.priority_high,
                      color: AppColors.expenseClay,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    tx.merchant,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text('${tx.money.format()} · ${acc.name}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(
                          transaction: tx,
                          category: cat,
                          account: acc,
                          appState: appState,
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  Widget _buildAndroidStatusCard(bool isDark, AppState appState) {
    final smsTransactions = appState.transactions
        .where((tx) => tx.source == AppConstants.sourceSms)
        .toList();
    final hasImportedSms = smsTransactions.isNotEmpty;
    final connected = _androidPermissionGranted;

    return SkeuoPanel(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeuoIconWell(
                icon: Icons.sms_outlined,
                size: 32,
                iconSize: 16,
                radius: 9,
              ),
              const SizedBox(width: 10),
              Text(
                'Android SMS import',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const Spacer(),
              SkeuoBadge(
                label: connected ? 'Permission granted' : 'Permission needed',
                icon: Icons.circle,
                tone: connected
                    ? SkeuoBadgeTone.accent
                    : SkeuoBadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            !connected
                ? 'Allow SMS access to import bank and telecom alerts from this phone. Nothing leaves the device.'
                : hasImportedSms
                ? 'Last automated alert: ${DateFormat('MMM d, h:mm a').format(smsTransactions.first.timestamp)}\nProcessed on-device with zero cloud telemetry'
                : 'No SMS alerts imported yet. Tap "Import SMS now" below to scan the last 12 months.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow({
    required String number,
    required String title,
    required String body,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeuoInset(
            width: 27,
            height: 27,
            radius: 14,
            child: Text(
              number,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accentOf(context),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    final isAndroid = AndroidSmsService.isSupported;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isAndroid ? 'Android SMS import' : 'Apple Shortcuts Automation',
        ),
        content: SingleChildScrollView(
          child: Text(
            isAndroid
                ? 'Android lets LedgerLeaf read bank and telecom SMS after you grant the SMS permission.\n\n'
                      'On the first import the app scans the last 12 months. New messages are captured in the background and imported the next time you open LedgerLeaf.\n\n'
                      'Everything is parsed and stored locally on this phone. There is no cloud service and no network permission.'
                : 'iOS restricts background SMS inbox reading for privacy.\n\n'
                      'LedgerLeaf works through Apple\'s built-in Shortcuts personal automation: '
                      'when your bank sends an SMS alert, iOS matches the sender and forwards the text directly to LedgerLeaf\'s local App Intent.\n\n'
                      'Your messages are processed 100% on-device with zero cloud telemetry.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
