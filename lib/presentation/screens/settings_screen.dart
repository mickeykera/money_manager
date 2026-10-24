import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/app_state.dart';
import 'automation_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  final AppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _settingsRepo = SettingsRepository();

  bool _retainSms = true;
  String _retentionDays = '30';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final retain = await _settingsRepo.getSetting(AppConstants.keyRetainOriginalSms);
    final retention = await _settingsRepo.getSetting(AppConstants.keySmsRetentionDays);

    setState(() {
      _retainSms = retain != 'false';
      _retentionDays = retention ?? '30';
    });
  }

  void _exportCsv() async {
    final csv = await widget.appState.exportCsv();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exported CSV Data'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your transaction ledger in RFC-4180 CSV format:'),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _importCsv() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Transactions from CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste CSV text formatted with header columns: Date, Type, Merchant, Amount...'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(
                hintText: 'Paste CSV here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                final count = await widget.appState.importCsv(text);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Successfully imported $count transactions.')),
                  );
                }
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  void _confirmWipeData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wipe All Financial Data?'),
        content: const Text(
          'This will permanently delete all transactions, budgets, and logs from this device. Default accounts and categories will be restored. This action CANNOT be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.clayPrimary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Wipe All Data'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.appState.wipeAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data wiped and ledger reset.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // General Section
          _buildSectionHeader('General & Display', primaryTextColor),
          ListTile(
            title: const Text('Default Currency'),
            subtitle: const Text('Ethiopian Birr (ETB)'),
            leading: const Icon(Icons.currency_exchange),
            trailing: const Text('ETB', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            title: const Text('Theme Mode'),
            leading: const Icon(Icons.palette_outlined),
            trailing: DropdownButton<ThemeMode>(
              value: widget.appState.themeMode,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
              onChanged: (mode) {
                if (mode != null) widget.appState.setThemeMode(mode);
              },
            ),
          ),
          SwitchListTile(
            title: const Text('Privacy Mode'),
            subtitle: const Text('Mask balances and figures on dashboard'),
            secondary: const Icon(Icons.visibility_off_outlined),
            value: widget.appState.isPrivacyMode,
            onChanged: (_) => widget.appState.togglePrivacyMode(),
          ),

          const Divider(height: 24),

          // Privacy & Security Section
          _buildSectionHeader('Privacy & Data Retention', primaryTextColor),
          SwitchListTile(
            title: const Text('Retain Original SMS'),
            subtitle: const Text('Store raw bank SMS text locally with transaction metadata'),
            secondary: const Icon(Icons.sms_outlined),
            value: _retainSms,
            onChanged: (val) async {
              setState(() => _retainSms = val);
              await _settingsRepo.setSetting(AppConstants.keyRetainOriginalSms, val ? 'true' : 'false');
            },
          ),
          ListTile(
            title: const Text('SMS Retention Period'),
            subtitle: Text('Purge raw SMS text after $_retentionDays days (keeps transaction metadata)'),
            leading: const Icon(Icons.timer_outlined),
            trailing: DropdownButton<String>(
              value: _retentionDays,
              underline: const SizedBox(),
              items: const [
                DropdownMenuItem(value: '7', child: Text('7 Days')),
                DropdownMenuItem(value: '30', child: Text('30 Days')),
                DropdownMenuItem(value: '90', child: Text('90 Days')),
                DropdownMenuItem(value: '365', child: Text('1 Year')),
              ],
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _retentionDays = val);
                  await _settingsRepo.setSetting(AppConstants.keySmsRetentionDays, val);
                }
              },
            ),
          ),

          const Divider(height: 24),

          // iOS Shortcuts Automation Section
          _buildSectionHeader('iOS Automation', primaryTextColor),
          ListTile(
            title: const Text('Shortcuts Automation Setup'),
            subtitle: const Text('Configure personal automation for CBE, Telebirr, etc.'),
            leading: const Icon(Icons.bolt, color: AppColors.sagePrimary),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AutomationSetupScreen(appState: widget.appState)),
              );
            },
          ),

          const Divider(height: 24),

          // Data Portability Section
          _buildSectionHeader('Data Portability & Backup', primaryTextColor),
          ListTile(
            title: const Text('Export to CSV'),
            subtitle: const Text('Export complete transaction ledger to standard CSV'),
            leading: const Icon(Icons.file_download_outlined),
            onTap: _exportCsv,
          ),
          ListTile(
            title: const Text('Import from CSV'),
            subtitle: const Text('Import transactions from CSV text'),
            leading: const Icon(Icons.file_upload_outlined),
            onTap: _importCsv,
          ),

          const Divider(height: 24),

          // Dangerous Zone
          _buildSectionHeader('Danger Zone', AppColors.clayPrimary),
          ListTile(
            title: const Text('Wipe All Financial Data', style: TextStyle(color: AppColors.clayPrimary, fontWeight: FontWeight.bold)),
            subtitle: const Text('Drop all transactions, custom categories, and logs'),
            leading: const Icon(Icons.delete_forever, color: AppColors.clayPrimary),
            onTap: _confirmWipeData,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
