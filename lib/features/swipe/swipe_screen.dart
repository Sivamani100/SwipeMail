import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'swipe_provider.dart';
import 'email_preview_modal.dart';
import '../../widgets/tinder_card.dart';
import '../../widgets/common_widgets.dart';
import '../../routing/app_router.dart';

class SwipeScreen extends ConsumerWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(swipeProvider);
    final notifier = ref.read(swipeProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(state.categoryName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            notifier.reset();
            Navigator.pop(context);
          },
        ),
        actions: [
          // Complete button in the top right to finish cleaning early if they want to review
          if (state.deleteQueue.isNotEmpty || state.keepQueue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: TextButton.icon(
                onPressed: () => AppRouter.navigateToReview(context),
                icon: const Icon(Icons.fact_check, size: 18),
                label: const Text('Review'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Mini-Queue Counter Indicator
            _buildQueueIndicator(context, state),

            // Card Stack Area
            Expanded(
              child: _buildCardStackArea(context, ref, state, notifier),
            ),

            // Bottom Buttons Bar (only show if we have cards in deck)
            if (state.status == SwipeStatus.loaded && state.cards.isNotEmpty)
              _buildBottomControls(context, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildQueueIndicator(BuildContext context, SwipeState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSwiped = state.deleteQueue.length + state.keepQueue.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: const Color(0xFF00B894), size: 16),
              const SizedBox(width: 4),
              Text(
                'Keep: ${state.keepQueue.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Text(
            'Reviewed: $totalSwiped',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
            ),
          ),
          Row(
            children: [
              Icon(Icons.delete, color: const Color(0xFFD63031), size: 16),
              const SizedBox(width: 4),
              Text(
                'Remove: ${state.deleteQueue.length}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardStackArea(
    BuildContext context,
    WidgetRef ref,
    SwipeState state,
    SwipeNotifier notifier,
  ) {
    if (state.status == SwipeStatus.loading && state.cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Scanning emails...',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    if (state.status == SwipeStatus.error && state.cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Oops! Connection issues',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'Could not fetch your emails.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => notifier.loadMoreEmails(),
              child: const Text('Retry Search'),
            ),
          ],
        ),
      );
    }

    if (state.cards.isEmpty) {
      return _buildEmptyDeckView(context, state, notifier);
    }

    // Build the visual card stack (render only top 3 to preserve memory & framerates)
    final List<Widget> cardWidgets = [];
    final renderCount = state.cards.length > 3 ? 3 : state.cards.length;

    for (int i = renderCount - 1; i >= 0; i--) {
      final card = state.cards[i];
      cardWidgets.add(
        TinderCard(
          key: ValueKey(card.id),
          card: card,
          onSwipeLeft: () => notifier.swipeDelete(),
          onSwipeRight: () => notifier.swipeKeep(),
          onTap: () {
            if (card.type == CardType.individual) {
              EmailPreviewModal.show(
                context: context,
                email: card.email!,
                onKeep: () => notifier.swipeKeep(),
                onDelete: () => notifier.swipeDelete(),
              );
            }
          },
          onReviewIndividually: card.type == CardType.bulk
              ? () => notifier.reviewGroupIndividually()
              : null,
        ),
      );
    }

    return Stack(
      children: cardWidgets,
    );
  }

  Widget _buildEmptyDeckView(BuildContext context, SwipeState state, SwipeNotifier notifier) {
    final hasSwipes = state.deleteQueue.isNotEmpty || state.keepQueue.isNotEmpty;
    final canLoadMore = state.nextPageToken != null;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: GlassContainer(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.done_all, size: 48, color: primaryColor),
              ),
              const SizedBox(height: 24),
              Text(
                'Deck Completed!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                'You have reviewed all loaded emails for this category.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (hasSwipes)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => AppRouter.navigateToReview(context),
                    child: const Text('Review and Delete Queue'),
                  ),
                ),
              if (canLoadMore) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => notifier.loadMoreEmails(),
                    child: state.status == SwipeStatus.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Load More Emails'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    notifier.reset();
                    Navigator.pop(context);
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

  Widget _buildBottomControls(
    BuildContext context,
    SwipeState state,
    SwipeNotifier notifier,
  ) {
    final canUndo = state.history.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0, top: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Undo Button
          _buildActionButton(
            context,
            icon: Icons.undo,
            color: canUndo ? Colors.amber : Colors.grey.withOpacity(0.3),
            onPressed: canUndo ? () => notifier.undo() : null,
            size: 50,
          ),
          const SizedBox(width: 24),
          // Delete Button (Swipe Left)
          _buildActionButton(
            context,
            icon: Icons.delete_outline,
            color: const Color(0xFFD63031),
            onPressed: () => notifier.swipeDelete(),
            size: 64,
          ),
          const SizedBox(width: 24),
          // Keep Button (Swipe Right)
          _buildActionButton(
            context,
            icon: Icons.check_circle_outline,
            color: const Color(0xFF00B894),
            onPressed: () => notifier.swipeKeep(),
            size: 64,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required double size,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? const Color(0xFF16122C) : Colors.white,
        border: Border.all(
          color: color.withOpacity(onPressed == null ? 0.2 : 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(onPressed == null ? 0.0 : 0.15),
            blurRadius: 8,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onPressed,
          child: Icon(
            icon,
            color: color.withOpacity(onPressed == null ? 0.3 : 1.0),
            size: size * 0.45,
          ),
        ),
      ),
    );
  }
}
