import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../widgets/common_widgets.dart';
import 'auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Listen for OAuth errors and show them
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: SwipeBrandHeader(size: 28),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildPage(
                    icon: Iconsax.arrange_square_2,
                    headline: 'Clean your inbox with simple swipes.',
                    description: 'Swipe right to keep emails. Swipe left to move them to trash. Manage your inbox at the speed of thought.',
                    ctaText: 'Get Started',
                    onCtaPressed: _nextPage,
                  ),
                  _buildPage(
                    icon: Iconsax.security_safe,
                    headline: 'Your privacy comes first.',
                    description: 'We never sell your data or read your emails on third-party servers. Everything connects directly to your Gmail API local device.',
                    ctaText: 'Continue',
                    onCtaPressed: _nextPage,
                  ),
                  _buildConnectPage(authState),
                ],
              ),
            ),
            // Page Indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (index) => _buildIndicator(index)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(int index) {
    final isSelected = _currentPage == index;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      width: isSelected ? 24.0 : 8.0,
      height: 8.0,
      decoration: BoxDecoration(
        color: isSelected ? primaryColor : primaryColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4.0),
      ),
    );
  }

  Widget _buildPage({
    required IconData icon,
    required String headline,
    required String description,
    required String ctaText,
    required VoidCallback onCtaPressed,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 80,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            headline,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              height: 1.25,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: isDark ? const Color(0xFFA0A5C0) : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onCtaPressed,
              child: Text(ctaText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPage(AuthState state) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLoading = state.status == AuthStatus.authenticating;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.sms,
              size: 80,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 48),
          Text(
            'Connect Gmail',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            'Securely connect your Gmail account to begin scanning newsletters, promotions, and unread mail.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 16,
              color: isDark ? const Color(0xFFA0A5C0) : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // Trigger Gmail login flow
                      await ref.read(authProvider.notifier).login();
                      // After login completion, complete onboarding state
                      if (ref.read(authProvider).status == AuthStatus.authenticated) {
                        await ref.read(authProvider.notifier).completeOnboarding();
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Iconsax.login),
                        SizedBox(width: 12),
                        Text('Connect Gmail'),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
