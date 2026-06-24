import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../swipe/swipe_provider.dart';
import 'success_screen.dart';

class ExecutionScreen extends ConsumerStatefulWidget {
  const ExecutionScreen({super.key});

  @override
  ConsumerState<ExecutionScreen> createState() => _ExecutionScreenState();
}

class _ExecutionScreenState extends ConsumerState<ExecutionScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        ref.read(swipeProvider.notifier).executeTrashing();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(swipeProvider);

    // Watch status to navigate to success
    ref.listen<SwipeState>(swipeProvider, (previous, next) {
      if (next.status == SwipeStatus.success) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuccessScreen()),
        );
      }
    });

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = state.batchTotal;
    final progress = state.batchProgress;
    final percent = total > 0 ? (progress / total) : 0.0;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (state.status == SwipeStatus.error) ...[
                  const Icon(Iconsax.warning_2, size: 72, color: Color(0xFFD63031)),
                  const SizedBox(height: 24),
                  Text(
                    'Trashing Failed',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    state.errorMessage ?? 'An error occurred during API execution.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => ref.read(swipeProvider.notifier).executeTrashing(),
                      child: const Text('Retry Execution'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Back to Review'),
                  ),
                ] else ...[
                  // Circular Progress Indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 160,
                        width: 160,
                        child: CircularProgressIndicator(
                          value: percent,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(percent * 100).toInt()}%',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 36,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$progress / $total',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Moving Emails to Trash...',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Processing batch modifications on Google Servers. Please do not close the application.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
