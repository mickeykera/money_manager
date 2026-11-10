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
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1B1E20), const Color(0xFF0A0B0C)]
                : [const Color(0xFFF8F4EC), const Color(0xFFDAD4C7)],
          ),
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : Colors.white.withValues(alpha: 0.85),
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.18),
              blurRadius: 18,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
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
    final activeColor = AppColors.accentOf(context);
    final inactiveColor = AppColors.textMutedOf(context);

    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: isSelected ? 46 : 38,
              height: 29,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          activeColor.withValues(alpha: isDark ? 0.20 : 0.16),
                          activeColor.withValues(alpha: isDark ? 0.05 : 0.03),
                        ],
                      )
                    : null,
                border: isSelected
                    ? Border.all(
                        color: activeColor.withValues(alpha: 0.35),
                        width: 0.8,
                      )
                    : null,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.35 : 0.08,
                          ),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.white.withValues(
                            alpha: isDark ? 0.05 : 0.65,
                          ),
                          blurRadius: 1,
                          offset: const Offset(0, -1),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                size: 21,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10.2,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.25,
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
