import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/settings_repository.dart';
import 'automation_setup_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = [
    const _OnboardingPageData(
      title: 'LedgerLeaf',
      subtitle: 'Privacy-First Expense Tracking for Ethiopia',
      description:
          'Track your daily expenses, monthly category budgets, and cash flow in Ethiopian Birr (ETB). Built strictly offline-first with zero tracking and zero cloud servers.',
      icon: Icons.eco,
      badgeText: '100% Offline & Private',
    ),
    const _OnboardingPageData(
      title: 'How iOS SMS Tracking Works',
      subtitle: 'Apple Privacy Sandbox Explained',
      description:
          'iOS does NOT allow any third-party app to read your SMS inbox directly. Instead, LedgerLeaf integrates seamlessly with Apple Shortcuts and Personal Automation to capture incoming bank alerts the instant they arrive.',
      icon: Icons.security,
      badgeText: 'Zero Inbox Access Needed',
    ),
    const _OnboardingPageData(
      title: 'Bank & Mobile Money Ready',
      subtitle: 'CBE, Telebirr, BOA, Dashen & More',
      description:
          'Deterministic parsers extract amounts, dates, and merchants instantly. Security safeguards automatically drop and ignore OTP codes and authentication passwords so your credentials stay safe.',
      icon: Icons.account_balance,
      badgeText: 'Automatic OTP Dropping',
    ),
    const _OnboardingPageData(
      title: 'You Are in Full Control',
      subtitle: 'Audit Logs & Review Queue',
      description:
          'Every parsed transaction can be reviewed, edited, or recategorized. Export your full ledger to standard CSV at any time or wipe your database with one tap.',
      icon: Icons.verified_user,
      badgeText: 'Local SQLite Storage',
    ),
  ];

  void _completeOnboarding({bool openSetup = false}) async {
    final settings = SettingsRepository();
    await settings.setSetting(AppConstants.keyOnboardingCompleted, 'true');
    if (!mounted) return;

    if (openSetup) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AutomationSetupScreen()),
      ).then((_) {
        widget.onFinish();
      });
    } else {
      widget.onFinish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'LedgerLeaf',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                    ),
                  ),
                  if (_currentPage < _pages.length - 1)
                    TextButton(
                      onPressed: () => _completeOnboarding(),
                      child: Text(
                        'Skip',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    ),
                ],
              ),
            ),

            // Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Icon Illustration
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.sageLight : AppColors.sagePrimary)
                                .withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            page.icon,
                            size: 48,
                            color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (isDark ? AppColors.darkCard : AppColors.lightCard),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            page.badgeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.sageLight : AppColors.sagePrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Subtitle
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Description
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Page Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (idx) {
                final isActive = idx == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? (isDark ? AppColors.sageLight : AppColors.sagePrimary)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),

            // Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: _currentPage == _pages.length - 1
                  ? Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => _completeOnboarding(openSetup: true),
                            child: const Text('Configure Automation Setup'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _completeOnboarding(openSetup: false),
                            child: Text(
                              'Go to Dashboard',
                              style: TextStyle(color: primaryTextColor),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: const Text('Continue'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final String badgeText;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.badgeText,
  });
}
