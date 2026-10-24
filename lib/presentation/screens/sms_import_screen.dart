import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import 'transaction_detail_screen.dart';

class SmsImportScreen extends StatefulWidget {
  final AppState appState;

  const SmsImportScreen({super.key, required this.appState});

  @override
  State<SmsImportScreen> createState() => _SmsImportScreenState();
}

class _SmsImportScreenState extends State<SmsImportScreen> {
  final TextEditingController _customSmsController = TextEditingController();

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
              ...sampleMessages.map((sample) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.offWhiteBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: ListTile(
                      title: Text(
                        sample['title']!,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          sample['sms']!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(Icons.play_circle_outline, color: AppColors.forestGreen),
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
                              backgroundColor: res.success ? AppColors.forestGreen : AppColors.expenseClay,
                            ),
                          );
                        }
                      },
                    ),
                  )),
              const Divider(height: 28),
              const Text(
                'Or Paste Custom SMS:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _customSmsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Paste any SMS message here...',
                  filled: true,
                  fillColor: Colors.grey.shade50,
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
                          backgroundColor: res.success ? AppColors.forestGreen : AppColors.expenseClay,
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
      appBar: AppBar(
        title: const Text('SMS import'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Shortcuts Automation Guide',
            onPressed: () => _showHelpDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Subtitle
          const Text(
            'Your messages. Your control.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),

          // Privacy Card: Green Shield
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF19281E) : const Color(0xFFEFF7F1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2E4E39) : const Color(0xFFC7E3D0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 22,
                  color: AppColors.forestGreen,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Only what you choose to share',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFBCE3C8) : AppColors.forestGreen,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'LedgerLeaf can\'t read your SMS inbox. Your personal automation forwards only matching messages.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: isDark ? const Color(0xFFA2C2B0) : const Color(0xFF2F543C),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Apple Shortcuts Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.cardWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222F26) : const Color(0xFFE8F3EC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_mosaic,
                        size: 16,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Apple Shortcuts',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.greenAccentPill,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.forestGreen),
                          SizedBox(width: 5),
                          Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forestGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'CBE · Telebirr · Safaricom M-PESA\nLatest message processed securely on-device',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Set up a personal automation section
          const Text(
            'Set up a personal automation',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),

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
              icon: const Text(
                'Open Shortcuts',
                style: TextStyle(
                  color: AppColors.forestGreen,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              label: const Icon(Icons.north_east, size: 14, color: AppColors.forestGreen),
            ),
          ),
          const SizedBox(height: 20),

          // Big Dark Forest Green Action Button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text(
                'Test with sample SMS',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              onPressed: _showTestSmsDialog,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Preview only. Won\'t duplicate your transactions.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Pending Review Queue (if any)
          if (pendingCount > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Review Queue',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.clayLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$pendingCount needs review',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.clayPrimary,
                    ),
                  ),
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
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.clayPrimary.withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.clayLight,
                    child: Icon(Icons.priority_high, color: AppColors.clayPrimary, size: 18),
                  ),
                  title: Text(tx.merchant, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222B25) : const Color(0xFFE9E8E2),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apple Shortcuts Automation'),
        content: const SingleChildScrollView(
          child: Text(
            'iOS restricts background SMS inbox reading for privacy.\n\n'
            'LedgerLeaf works through Apple\'s built-in Shortcuts personal automation: '
            'when your bank sends an SMS alert, iOS matches the sender and forwards the text directly to LedgerLeaf\'s local App Intent.\n\n'
            'Your messages are processed 100% on-device with zero cloud telemetry.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }
}
