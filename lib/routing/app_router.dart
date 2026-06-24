import 'package:flutter/material.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/swipe/swipe_screen.dart';
import '../features/review/review_screen.dart';
import '../features/review/execution_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/dashboard/trash_bin_screen.dart';

class AppRouter {
  static void navigateToDashboard(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
      (route) => false,
    );
  }

  static void navigateToSwipe(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SwipeScreen()),
    );
  }

  static void navigateToReview(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ReviewScreen()),
    );
  }

  static void navigateToExecution(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ExecutionScreen()),
    );
  }

  static void navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  static void navigateToTrashBin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TrashBinScreen()),
    );
  }
}
