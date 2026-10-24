import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/bundle_model.dart';
import '../../services/app_state.dart';

class BundlesScreen extends StatefulWidget {
  final AppState appState;

  const BundlesScreen({super.key, required this.appState});

  @override
  State<BundlesScreen> createState() => _BundlesScreenState();
}

class _BundlesScreenState extends State<BundlesScreen> {
  String? _selectedBundleIdForHistory;
  List<BundleObservationModel> _observations = [];

  void _loadObservations(String bundleId) async {
    final obs = await widget.appState.bundleRepo.getObservationsForBundle(bundleId);
    setState(() {
      _selectedBundleIdForHistory = bundleId;
      _observations = obs;
    });
  }

  void _showSimulateDialog() {
    final telecomPresets = [
      {
        'title': 'Ethio telecom 10GB Monthly Purchase',
        'sender': '994',
        'sms': 'Dear customer, you have successfully purchased 10GB Monthly Data bundle for ETB 300.00. Valid until 2026-11-24 18:30:00.',
      },
      {
        'title': 'Ethio telecom *804# Balance Update (7.2 GB)',
        'sender': 'Ethio telecom',
        'sms': 'Dear Customer, your remaining package balance is 7.20 GB Data valid until 2026-11-24.',
      },
      {
        'title': 'Ethio telecom Further Consumption (5.5 GB)',
        'sender': 'Ethio telecom',
        'sms': 'Dear Customer, your remaining package balance is 5.50 GB Data valid until 2026-11-24.',
      },
      {
        'title': 'Safaricom 5GB Weekly Purchase (ETB 150)',
        'sender': 'Safaricom',
        'sms': 'Dear customer, you have successfully purchased 5GB Weekly Data bundle for ETB 150.00. Valid until 2026-11-01 23:59:59.',
      },
      {
        'title': 'Safaricom *704# Balance Check (3.85 GB)',
        'sender': '704',
        'sms': 'Your Safaricom balance: Data: 3.85 GB valid until 2026-11-01 23:59:59. Voice: 42 Minutes. SMS: 15.',
      },
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simulate Telecom Bundle SMS',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Test package purchase, remaining balance tracking, and consumption calculation.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ...telecomPresets.map((preset) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(preset['title']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(preset['sms']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.send, color: AppColors.forestGreen, size: 20),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final res = await widget.appState.ingestSms(
                        preset['sms']!,
                        sender: preset['sender'],
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res.message),
                            backgroundColor: AppColors.forestGreen,
                          ),
                        );
                      }
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = widget.appState.telecomSummary;
    final bundles = widget.appState.bundles;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
      appBar: AppBar(
        title: const Text('Bundles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_to_photos_outlined),
            tooltip: 'Simulate Telecom SMS',
            onPressed: _showSimulateDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // Subtitle
          const Text(
            'Telecom data, voice & SMS packages.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 20),

          // Total Remaining Data Hero Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.forestGreenHero,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Remaining Internet Data',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.forestGreenSubtext,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(Icons.wifi_tethering, color: AppColors.forestGreenSubtext, size: 18),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      (summary.ethioDataRemainingGb + summary.safaricomDataRemainingGb).toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'GB Total',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestGreenSubtext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF2D533E), height: 1),
                const SizedBox(height: 14),

                // Providers row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ethio telecom',
                            style: TextStyle(color: AppColors.forestGreenSubtext, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${summary.ethioDataRemainingGb.toStringAsFixed(2)} GB',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 32, width: 1, color: const Color(0xFF2D533E)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Safaricom Ethiopia',
                            style: TextStyle(color: AppColors.forestGreenSubtext, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${summary.safaricomDataRemainingGb.toStringAsFixed(2)} GB',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Active Bundles Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Packages',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
              Text(
                '${bundles.length} tracked',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (bundles.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.cell_tower, size: 48, color: AppColors.textMuted),
                  SizedBox(height: 12),
                  Text('No telecom bundles tracked yet.', style: TextStyle(color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text(
                    'Forward an Ethio telecom or Safaricom SMS alert to see your balance.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...bundles.map((bundle) => _buildBundleCard(context, bundle, isDark)),

          // Selected Observation History Section
          if (_selectedBundleIdForHistory != null && _observations.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usage Observations & History',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedBundleIdForHistory = null),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.cardWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
              ),
              child: Column(
                children: _observations.map((obs) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      '${obs.remainingAllowance} ${obs.unit} remaining',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    subtitle: Text(
                      obs.estimatedUsageSincePrevious != null && obs.estimatedUsageSincePrevious! > 0
                          ? 'Consumed ${obs.estimatedUsageSincePrevious} ${obs.unit} since previous report'
                          : 'Balance reported: ${DateFormat("MMM d, h:mm a").format(obs.timestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: obs.estimatedUsageSincePrevious != null && obs.estimatedUsageSincePrevious! > 0
                            ? AppColors.expenseClay
                            : AppColors.textSecondary,
                      ),
                    ),
                    trailing: Text(
                      DateFormat('MMM d').format(obs.timestamp),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBundleCard(BuildContext context, TelecomBundleModel bundle, bool isDark) {
    final progress = bundle.originalAllowance > 0
        ? (bundle.remainingAllowance / bundle.originalAllowance).clamp(0.0, 1.0)
        : 1.0;

    final isEthio = bundle.provider.toLowerCase().contains('ethio');
    final expiryStr = bundle.expiryTime != null
        ? DateFormat('MMM d, yyyy').format(bundle.expiryTime!)
        : 'No expiry';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isEthio ? const Color(0xFFE8F3EC) : const Color(0xFFFBECEB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      bundle.provider,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isEthio ? AppColors.forestGreen : const Color(0xFFC0392B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    bundle.category.toUpperCase(),
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: bundle.isExhausted ? AppColors.clayLight : AppColors.greenAccentPill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  bundle.status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: bundle.isExhausted ? AppColors.clayPrimary : AppColors.greenAccentText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Bundle Name
          Text(
            bundle.bundleName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),

          // Remaining vs Original
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${bundle.remainingAllowance} ${bundle.unit} remaining',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forestGreen,
                ),
              ),
              Text(
                'of ${bundle.originalAllowance} ${bundle.unit}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF2C332D) : const Color(0xFFEBEAE4),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress > 0.25 ? AppColors.forestGreen : AppColors.expenseClay,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Expiry and Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 5),
                  Text(
                    'Valid until $expiryStr',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _loadObservations(bundle.id),
                child: const Row(
                  children: [
                    Text(
                      'Usage history',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.forestGreen,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, size: 14, color: AppColors.forestGreen),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
