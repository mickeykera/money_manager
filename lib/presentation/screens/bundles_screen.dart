import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/models/bundle_model.dart';
import '../../services/app_state.dart';
import '../widgets/skeuomorphic.dart';

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
              Text(
                'Simulate Telecom Bundle SMS',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Test package purchase, remaining balance tracking, and consumption calculation.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
              const SizedBox(height: 16),
              ...telecomPresets.map((preset) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(preset['title']!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(preset['sms']!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Icon(
                      Icons.send,
                      color: AppColors.accentOf(context),
                      size: 20,
                    ),
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
                            backgroundColor: res.success
                                ? null
                                : AppColors.expenseOf(context),
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
    final bundles = widget.appState.bundles
        .where((bundle) => !bundle.isExpired)
        .toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
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
          Text(
            'Telecom data, voice & SMS packages.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondaryOf(context),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 20),

          // Total Remaining Data Hero Card
          SkeuoPanel(
            hero: true,
            ornament: true,
            radius: 22,
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'REMAINING INTERNET DATA',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.4,
                        color: AppColors.forestGreenSubtext,
                        fontWeight: FontWeight.w600,
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
                      summary.hasUnlimitedData
                          ? 'Unlimited'
                          : (summary.ethioDataRemainingGb +
                                    summary.safaricomDataRemainingGb)
                                .toStringAsFixed(2),
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFF6F1E7),
                        letterSpacing: -1.2,
                        shadows: [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      summary.hasUnlimitedData ? 'Data' : 'GB Total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: AppColors.forestGreenSubtext,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                const SizedBox(height: 14),

                // Providers row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ETHIO TELECOM',
                            style: TextStyle(
                              color: AppColors.forestGreenSubtext,
                              fontSize: 9.5,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            summary.ethioHasUnlimitedData
                                ? 'Unlimited'
                                : '${summary.ethioDataRemainingGb.toStringAsFixed(2)} GB',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Color(0xFFF2EDE3),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 32,
                      width: 1,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SAFARICOM ETHIOPIA',
                            style: TextStyle(
                              color: AppColors.forestGreenSubtext,
                              fontSize: 9.5,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            summary.safaricomHasUnlimitedData
                                ? 'Unlimited'
                                : '${summary.safaricomDataRemainingGb.toStringAsFixed(2)} GB',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Color(0xFFF2EDE3),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
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
              Text(
                'Active Packages',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                  color: AppColors.textPrimaryOf(context),
                ),
              ),
              Text(
                '${bundles.length} tracked',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.3,
                  color: AppColors.textSecondaryOf(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (bundles.isEmpty)
            SkeuoPanel(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  SkeuoIconWell(
                    icon: Icons.cell_tower,
                    size: 54,
                    iconSize: 26,
                    radius: 16,
                    color: AppColors.textMutedOf(context),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No telecom bundles tracked yet.',
                    style: TextStyle(color: AppColors.textSecondaryOf(context)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Forward an Ethio telecom or Safaricom SMS alert to see your balance.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMutedOf(context)),
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
            SkeuoPanel(
              padding: EdgeInsets.zero,
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
                            ? AppColors.expenseOf(context)
                            : AppColors.textSecondaryOf(context),
                      ),
                    ),
                    trailing: Text(
                      DateFormat('MMM d').format(obs.timestamp),
                      style: TextStyle(fontSize: 11, color: AppColors.textMutedOf(context)),
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
    final progress = bundle.percentageRemaining;

    final isEthio = bundle.provider.toLowerCase().contains('ethio');
    final expiryStr = bundle.expiryTime != null
        ? DateFormat('MMM d, yyyy').format(bundle.expiryTime!)
        : 'No expiry';
    final expiryLabel = bundle.isUnlimited
        ? bundle.expiryFormatted
        : 'Valid until $expiryStr';

    return SkeuoPanel(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    SkeuoBadge(
                      label: bundle.provider,
                      tone: isEthio
                          ? SkeuoBadgeTone.accent
                          : SkeuoBadgeTone.neutral,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      bundle.category.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.0,
                        color: AppColors.textMutedOf(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (bundle.id.contains('sample')) ...[
                      const SizedBox(width: 8),
                      const SkeuoBadge(label: 'Sample'),
                    ],
                  ],
                ),
              ),
              SkeuoBadge(
                label: bundle.status.toUpperCase(),
                tone: bundle.isExhausted
                    ? SkeuoBadgeTone.danger
                    : SkeuoBadgeTone.accent,
              ),
            ],
          ),
          const SizedBox(height: 13),

          // Bundle Name
          Text(
            bundle.bundleName,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 11),

          // Remaining vs Original
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bundle.isUnlimited
                    ? 'Unlimited'
                    : '${bundle.formattedRemaining} remaining',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentOf(context),
                ),
              ),
              Text(
                bundle.isUnlimited
                    ? 'Fair usage applies'
                    : 'of ${bundle.formattedAllowance}',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMutedOf(context)),
              ),
            ],
          ),
          if (!bundle.isUnlimited) ...[
            const SizedBox(height: 7),

            // Inset progress track
            SkeuoProgressBar(
              value: progress,
              color: progress > 0.25
                  ? AppColors.accentOf(context)
                  : AppColors.expenseOf(context),
            ),
          ],
          const SizedBox(height: 13),

          // Expiry and Action Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 14,
                      color: AppColors.textSecondaryOf(context),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        expiryLabel,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondaryOf(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _loadObservations(bundle.id),
                child: Row(
                  children: [
                    Text(
                      'Usage history',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.accentOf(context),
                    ),
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
