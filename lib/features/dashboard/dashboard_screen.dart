import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'dashboard_overview_screen.dart';
import '../swipe/swipe_screen.dart';
import 'trash_bin_screen.dart';
import '../settings/settings_screen.dart';
import '../../core/providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final List<Widget> _screens = [
    const DashboardOverviewScreen(),
    const SwipeScreen(),
    const TrashBinScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(dashboardTabProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF16122C) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? const Color(0xFF2C274C) : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: (index) {
              ref.read(dashboardTabProvider.notifier).setTab(index);
            },
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: primaryColor,
            unselectedItemColor: Colors.grey.shade500,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Iconsax.element_4),
                activeIcon: Icon(Iconsax.element_4),
                label: 'Overview',
              ),
              BottomNavigationBarItem(
                icon: Icon(Iconsax.arrange_square_2),
                activeIcon: Icon(Iconsax.arrange_square_2),
                label: 'Clean',
              ),
              BottomNavigationBarItem(
                icon: Icon(Iconsax.trash),
                activeIcon: Icon(Iconsax.trash),
                label: 'Bin',
              ),
              BottomNavigationBarItem(
                icon: Icon(Iconsax.setting),
                activeIcon: Icon(Iconsax.setting),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

