import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../services/app_state.dart';
import 'accounts_screen.dart';
import 'bundles_screen.dart';
import 'dashboard_screen.dart';
import 'sms_import_screen.dart';
import 'transactions_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final AppState appState;
  final int initialIndex;

  const MainNavigationShell({
    super.key,
    required this.appState,
    this.initialIndex = 0,
  });

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screens = [
      DashboardScreen(
        appState: widget.appState,
        onNavigateToTransactions: () => _onTabSelected(1),
        onNavigateToAccounts: () => _onTabSelected(2),
        onNavigateToBundles: () => _onTabSelected(4),
      ),
      TransactionsScreen(appState: widget.appState),
      AccountsScreen(appState: widget.appState),
      SmsImportScreen(appState: widget.appState),
      BundlesScreen(appState: widget.appState),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBg : AppColors.offWhiteBg,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.darkBorder : AppColors.borderSubtle,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  index: 0,
                  isDark: isDark,
                ),
                _buildNavItem(
                  icon: Icons.swap_horiz,
                  activeIcon: Icons.swap_horiz,
                  label: 'Transactions',
                  index: 1,
                  isDark: isDark,
                ),
                _buildNavItem(
                  icon: Icons.credit_card_outlined,
                  activeIcon: Icons.credit_card,
                  label: 'Accounts',
                  index: 2,
                  isDark: isDark,
                ),
                _buildNavItem(
                  icon: Icons.chat_bubble_outline,
                  activeIcon: Icons.chat_bubble,
                  label: 'SMS import',
                  index: 3,
                  isDark: isDark,
                ),
                _buildNavItem(
                  icon: Icons.cell_tower,
                  activeIcon: Icons.cell_tower,
                  label: 'Bundles',
                  index: 4,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? const Color(0xFF75B58F) : AppColors.forestGreen;
    final inactiveColor = isDark ? AppColors.darkTextSecondary : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
