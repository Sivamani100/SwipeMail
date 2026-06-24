import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/common_widgets.dart';
import '../../core/providers.dart';
import '../authentication/auth_provider.dart';
import '../swipe/swipe_provider.dart';
import 'dashboard_provider.dart';
import '../../routing/app_router.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardProvider);
    final authState = ref.watch(authProvider);
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(dashboardProvider.notifier).loadDashboard(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Custom Beautiful Top Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SwipeBrandHeader(size: 24),
                          const SizedBox(height: 4),
                          Text(
                            authState.email ?? 'Connecting to Gmail...',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
                            onPressed: () => ref.read(themeProvider.notifier).toggleTheme(),
                          ),
                          IconButton(
                            icon: const Icon(Icons.settings),
                            onPressed: () => AppRouter.navigateToSettings(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Content Body
              if (dashboardState.status == DashboardStatus.loading)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Scanning your inbox...',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                )
              else if (dashboardState.status == DashboardStatus.error)
                SliverFillRemaining(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Connection Error',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dashboardState.errorMessage ?? 'Unknown error occurred.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => ref.read(dashboardProvider.notifier).loadDashboard(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatsBanner(context, dashboardState),
                    _buildQuickAction(context, ref),
                    _buildCategoryGridHeader(context),
                    _buildBentoGrid(context, ref, dashboardState),
                    const SizedBox(height: 32),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsBanner(BuildContext context, DashboardState state) {
    final cleanScore = state.totalInbox == 0
        ? 100
        : (100 - (state.unreadCount / state.totalInbox * 100)).clamp(0, 100).toInt();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: GlassContainer(
        borderRadius: 24,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inbox Health Score',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$cleanScore',
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: cleanScore > 80
                                    ? Colors.green
                                    : (cleanScore > 50 ? Colors.orange : Colors.red),
                              ),
                        ),
                        Text(
                          '/100',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                // Circular mini-indicator
                SizedBox(
                  height: 64,
                  width: 64,
                  child: CircularProgressIndicator(
                    value: cleanScore / 100.0,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    color: cleanScore > 80
                        ? Colors.green
                        : (cleanScore > 50 ? Colors.orange : Colors.red),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF2C274C)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMiniStat(context, 'Total Mail', '${state.totalInbox}'),
                _buildMiniStat(context, 'Cleaned', '${state.stats.totalTrashed}'),
                _buildMiniStat(context, 'Estimated Space', '${state.storageEstimateMb.toStringAsFixed(1)} MB'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(BuildContext context, String title, String val) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          val,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              primaryColor,
              primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              // Start swipe deck with Inbox query
              ref.read(swipeProvider.notifier).initQuery('Inbox', 'label:INBOX');
              AppRouter.navigateToSwipe(context);
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Full Inbox Clean',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Swipe through your primary mail',
                        style: TextStyle(
                          color: Color(0xDE000000),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.play_circle_fill,
                    size: 40,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGridHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Text(
        'Inbox Breakdown',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBentoGrid(BuildContext context, WidgetRef ref, DashboardState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  context,
                  ref,
                  title: 'Unread',
                  count: state.unreadCount,
                  icon: Icons.mark_as_unread_rounded,
                  color: Colors.redAccent,
                  description: 'All unread emails',
                  onTap: () {
                    ref.read(swipeProvider.notifier).initQuery('Unread', 'label:UNREAD label:INBOX');
                    AppRouter.navigateToSwipe(context);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoCard(
                  context,
                  ref,
                  title: 'Trash Bin',
                  count: state.trashCount,
                  icon: Icons.delete_rounded,
                  color: Colors.orangeAccent,
                  description: 'Restore/Delete permanently',
                  onTap: () {
                    AppRouter.navigateToTrashBin(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  context,
                  ref,
                  title: 'Promotions',
                  count: state.promotionsCount,
                  icon: Icons.local_offer_rounded,
                  color: Colors.amber,
                  description: 'Offers, newsletters',
                  onTap: () {
                    ref.read(swipeProvider.notifier).initQuery('Promotions', 'category:promotions label:INBOX');
                    AppRouter.navigateToSwipe(context);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoCard(
                  context,
                  ref,
                  title: 'Social',
                  count: state.socialCount,
                  icon: Icons.people_rounded,
                  color: Colors.blueAccent,
                  description: 'Alerts, updates',
                  onTap: () {
                    ref.read(swipeProvider.notifier).initQuery('Social', 'category:social label:INBOX');
                    AppRouter.navigateToSwipe(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildBentoCard(
                  context,
                  ref,
                  title: 'Updates',
                  count: state.updatesCount,
                  icon: Icons.info_rounded,
                  color: Colors.green,
                  description: 'Receipts, statements',
                  onTap: () {
                    ref.read(swipeProvider.notifier).initQuery('Updates', 'category:updates label:INBOX');
                    AppRouter.navigateToSwipe(context);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildBentoCard(
                  context,
                  ref,
                  title: 'Cleaned',
                  count: state.stats.totalTrashed,
                  icon: Icons.auto_awesome_rounded,
                  color: Colors.tealAccent,
                  description: 'Emails swiped to trash',
                  onTap: () {
                    AppRouter.navigateToTrashBin(context);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBentoCard(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            height: 135,
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    Text(
                      '$count',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFA0A5C0) : Colors.black54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
