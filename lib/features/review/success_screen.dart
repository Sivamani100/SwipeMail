import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../swipe/swipe_provider.dart';
import '../dashboard/dashboard_provider.dart';
import '../../widgets/common_widgets.dart';

class SuccessScreen extends ConsumerStatefulWidget {
  const SuccessScreen({super.key});

  @override
  ConsumerState<SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends ConsumerState<SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Note: swipeProvider will be cleared, so copy details now before clearing
    final swipeState = ref.watch(swipeProvider);
    final reviewed = swipeState.keepQueue.length + swipeState.deleteQueue.length;
    final kept = swipeState.keepQueue.length;
    final trashed = swipeState.deleteQueue.length;

    // Estimate storage saved: average 75KB per email
    final savedMb = (trashed * 75.0) / 1024.0;
    
    // Fun scorecard score
    final score = reviewed > 0 ? ((trashed / reviewed) * 100).toInt() : 100;

    final primaryColor = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            children: [
              const Spacer(),
              // Celebratory Circle Icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 3),
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 80,
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Inbox De-cluttered!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Great job! You\'ve successfully processed your email cleanup session.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                ),
              ),
              const Spacer(),

              // Scorecard Table
              GlassContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text(
                      'Session Scorecard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                    ),
                    const SizedBox(height: 20),
                    _buildScoreRow(context, 'Emails Reviewed', '$reviewed'),
                    const Divider(color: Color(0xFF2C274C)),
                    _buildScoreRow(context, 'Emails Kept', '$kept', color: const Color(0xFF00B894)),
                    const Divider(color: Color(0xFF2C274C)),
                    _buildScoreRow(context, 'Moved to Trash', '$trashed', color: const Color(0xFFD63031)),
                    const Divider(color: Color(0xFF2C274C)),
                    _buildScoreRow(context, 'Space Reclaimed', '${savedMb.toStringAsFixed(1)} MB'),
                    const Divider(color: Color(0xFF2C274C)),
                    _buildScoreRow(
                      context, 
                      'Cleanup Efficiency', 
                      '$score%',
                      color: score > 75 ? Colors.green : (score > 40 ? Colors.orange : Colors.red)
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Finish Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // 1. Reset Swipe stack state
                    ref.read(swipeProvider.notifier).reset();
                    // 2. Refresh dashboard metrics
                    ref.read(dashboardProvider.notifier).loadDashboard();
                    // 3. Return to Dashboard
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('Back to Dashboard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreRow(BuildContext context, String title, String val, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          Text(
            val,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color ?? Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
