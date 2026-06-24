import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/providers.dart';
import 'theme/app_theme.dart';
import 'features/authentication/auth_provider.dart';
import 'features/authentication/onboarding_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'widgets/common_widgets.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const SwipeMailApp(),
    ),
  );
}

class SwipeMailApp extends ConsumerWidget {
  const SwipeMailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(themeProvider);
    final authState = ref.watch(authProvider);

    Widget homeWidget = const OnboardingScreen();

    if (!authState.isOnboardingCompleted) {
      homeWidget = const OnboardingScreen();
    } else {
      switch (authState.status) {
        case AuthStatus.authenticated:
          homeWidget = const DashboardScreen();
        case AuthStatus.authenticating:
          homeWidget = const SplashScreenLoader();
        case AuthStatus.unauthenticated:
        case AuthStatus.error:
          homeWidget = const OnboardingScreen();
      }
    }

    return MaterialApp(
      title: 'SwipeMail',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: homeWidget,
    );
  }
}

class SplashScreenLoader extends StatelessWidget {
  const SplashScreenLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SwipeBrandHeader(size: 32),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
