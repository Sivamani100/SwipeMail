import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dashboard_provider.dart';
import '../swipe/swipe_provider.dart';
import '../../core/providers.dart';
import '../../features/authentication/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class DashboardOverviewScreen extends ConsumerStatefulWidget {
  const DashboardOverviewScreen({super.key});

  @override
  ConsumerState<DashboardOverviewScreen> createState() => _DashboardOverviewScreenState();
}

class _DashboardOverviewScreenState extends ConsumerState<DashboardOverviewScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // Start entrance animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startSwipeSession(String category, String query) {
    ref.read(swipeProvider.notifier).initQuery(category, query);
    // Switch to Swiper tab (index 1)
    ref.read(dashboardTabProvider.notifier).setTab(1);
  }

  @override
  Widget build(BuildContext context) {
    final dashboardState = ref.watch(dashboardProvider);
    final authState = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: Theme.of(context).colorScheme.primary,
          onRefresh: () => ref.read(dashboardProvider.notifier).loadDashboard(),
          child: Builder(
            builder: (context) {
              if (dashboardState.status == DashboardStatus.loading && dashboardState.totalInbox == 0) {
                return _buildLoadingSkeleton();
              }

              if (dashboardState.status == DashboardStatus.error) {
                return _buildErrorState(dashboardState.errorMessage ?? 'Connection error');
              }

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Logo & Greeting Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SwipeBrandHeader(size: 24),
                        IconButton(
                          icon: Icon(isDark ? Iconsax.sun_1 : Iconsax.moon),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white.withOpacity(0.1) : Colors.grey.shade100,
                          ),
                          onPressed: () {
                            ref.read(themeProvider.notifier).toggleTheme();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Greeting card (Full width)
                    _animateWidget(
                      index: 0,
                      child: _buildWelcomeCard(authState, dashboardState),
                    ),
                    const SizedBox(height: 20),

                    // Section: Category grid (Bento cards)
                    Text(
                      'Select Category to Clean',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Bento Grid Layout for Categories
                    _buildCategoryGrid(dashboardState),
                    const SizedBox(height: 20),

                    // Section: Statistics & Storage (Bento row)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Storage Saved & Trash Bin)
                        Expanded(
                          child: Column(
                            children: [
                              _animateWidget(
                                index: 5,
                                child: _buildStorageCard(dashboardState),
                              ),
                              const SizedBox(height: 16),
                              _animateWidget(
                                index: 6,
                                child: _buildTrashCard(dashboardState),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Right Column (Lifetime Stats Card - taller)
                        Expanded(
                          child: _animateWidget(
                            index: 7,
                            child: _buildStatsCard(dashboardState),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _animateWidget({required int index, required Widget child}) {
    final double start = index * 0.08;
    final double end = start + 0.4;
    final curve = CurvedAnimation(
      parent: _animationController,
      curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0), curve: Curves.easeOutBack),
    );

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, animChild) {
        return Opacity(
          opacity: curve.value,
          child: Transform.translate(
            offset: Offset(0.0, (1.0 - curve.value) * 30),
            child: animChild,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildWelcomeCard(AuthState authState, DashboardState dashboardState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailName = authState.email?.split('@').first ?? 'User';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF2C1B4D), const Color(0xFF16122C)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDark ? const Color(0xFF4338CA).withOpacity(0.3) : const Color(0xFFC7D2FE).withOpacity(0.4),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.3) : const Color(0xFF6366F1).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.magicpen,
                  color: Color(0xFF6366F1),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Gmail Connected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFA5B4FC) : const Color(0xFF4F46E5),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Hello, $emailName!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  fontSize: 26,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'You have ${dashboardState.unreadCount} unread emails in your inbox. Let\'s clean it up!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _startSwipeSession('Inbox', 'label:INBOX'),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.arrange_square_2, size: 20),
                  SizedBox(width: 8),
                  Text('Start Cleaning Inbox', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 200) {
      return '200+';
    }
    return count.toString();
  }

  Widget _buildCategoryGrid(DashboardState state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _animateWidget(
                index: 1,
                child: _buildBentoCategoryCard(
                  title: 'Primary',
                  count: _formatCount(state.unreadCount),
                  icon: Iconsax.direct_inbox,
                  color: const Color(0xFF818CF8),
                  bgColor: const Color(0xFFEEF2FF),
                  darkBgColor: const Color(0xFF1E1B4B),
                  onTap: () => _startSwipeSession('Inbox', 'label:UNREAD label:INBOX'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _animateWidget(
                index: 2,
                child: _buildBentoCategoryCard(
                  title: 'Promotions',
                  count: _formatCount(state.promotionsCount),
                  icon: Iconsax.tag,
                  color: const Color(0xFFFBBF24),
                  bgColor: const Color(0xFFFEF3C7),
                  darkBgColor: const Color(0xFF451A03),
                  onTap: () => _startSwipeSession('Promotions', 'category:promotions label:INBOX'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _animateWidget(
                index: 3,
                child: _buildBentoCategoryCard(
                  title: 'Socials',
                  count: _formatCount(state.socialCount),
                  icon: Iconsax.profile_2user,
                  color: const Color(0xFF34D399),
                  bgColor: const Color(0xFFD1FAE5),
                  darkBgColor: const Color(0xFF064E3B),
                  onTap: () => _startSwipeSession('Social', 'category:social label:INBOX'),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _animateWidget(
                index: 4,
                child: _buildBentoCategoryCard(
                  title: 'Updates',
                  count: _formatCount(state.updatesCount),
                  icon: Iconsax.info_circle,
                  color: const Color(0xFF60A5FA),
                  bgColor: const Color(0xFFDBEAFE),
                  darkBgColor: const Color(0xFF1E3A8A),
                  onTap: () => _startSwipeSession('Updates', 'category:updates label:INBOX'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBentoCategoryCard({
    required String title,
    required String count,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required Color darkBgColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? darkBgColor.withOpacity(0.5) : bgColor.withOpacity(0.7),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? color.withOpacity(0.2) : color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const Icon(Iconsax.arrow_right_3, size: 16, color: Colors.grey),
                ],
              ),
              const Spacer(),
              Text(
                count,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -0.5,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageCard(DashboardState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final savedMb = state.stats.savedStorageMb;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF271C19) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFFF97316).withOpacity(0.2) : const Color(0xFFFFEDD5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.save_2, color: Color(0xFFF97316), size: 20),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Storage Saved',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${savedMb.toStringAsFixed(1)} MB',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  color: const Color(0xFFF97316),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Saved from trashing old mail',
            style: TextStyle(
              fontSize: 10,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashCard(DashboardState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF2D161B) : const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () {
          // Switch to Trash Bin tab (index 2)
          ref.read(dashboardTabProvider.notifier).setTab(2);
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFFEF4444).withOpacity(0.2) : const Color(0xFFFEE2E2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.trash_copy, color: Color(0xFFEF4444), size: 20),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Trash Bin',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                state.trashCount.toString(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      color: const Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap to view and empty',
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  const Icon(Iconsax.arrow_right_3, size: 12, color: Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard(DashboardState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSwipes = state.stats.totalSwipes;
    final totalTrashed = state.stats.totalTrashed;
    final totalKept = state.stats.totalKept;
    final double efficiency = totalSwipes > 0 ? (totalTrashed / totalSwipes) * 100.0 : 0.0;

    return Container(
      height: 254, // Match double height of storage + trash cards
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1B4B).withOpacity(0.4) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF2C274C).withOpacity(0.5) : Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.grey.shade200.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Iconsax.chart, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Cleaning Stats',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            totalSwipes.toString(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  letterSpacing: -1,
                ),
          ),
          const Text(
            'Total Swipes Made',
            style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          const Divider(height: 1, color: Colors.black12),
          const Spacer(),
          _buildStatRow('Kept', totalKept.toString(), const Color(0xFF34D399)),
          const SizedBox(height: 8),
          _buildStatRow('Trashed', totalTrashed.toString(), const Color(0xFFF87171)),
          const SizedBox(height: 8),
          _buildStatRow('Clean Rate', '${efficiency.toStringAsFixed(0)}%', const Color(0xFF60A5FA)),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ShimmerLoader(width: 140, height: 28, borderRadius: 14),
              ShimmerLoader(width: 40, height: 40, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 24),
          const ShimmerLoader(width: double.infinity, height: 180, borderRadius: 28),
          const SizedBox(height: 28),
          const ShimmerLoader(width: 180, height: 20, borderRadius: 10),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerLoader(width: double.infinity, height: 140, borderRadius: 24)),
              const SizedBox(width: 16),
              Expanded(child: ShimmerLoader(width: double.infinity, height: 140, borderRadius: 24)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: ShimmerLoader(width: double.infinity, height: 140, borderRadius: 24)),
              const SizedBox(width: 16),
              Expanded(child: ShimmerLoader(width: double.infinity, height: 140, borderRadius: 24)),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.cloud_cross, size: 64, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              'Couldn\'t load your dashboard',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: () => ref.read(dashboardProvider.notifier).loadDashboard(),
              icon: const Icon(Iconsax.refresh_2),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      ),
    );
  }
}
