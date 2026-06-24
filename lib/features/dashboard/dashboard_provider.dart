import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/swipe_stats.dart';

enum DashboardStatus {
  loading,
  loaded,
  error,
}

class DashboardState {
  final DashboardStatus status;
  final int totalInbox;
  final int unreadCount;
  final int promotionsCount;
  final int socialCount;
  final int updatesCount;
  final int trashCount;
  final double storageEstimateMb;
  final SwipeStats stats;
  final String? errorMessage;

  DashboardState({
    required this.status,
    required this.totalInbox,
    required this.unreadCount,
    required this.promotionsCount,
    required this.socialCount,
    required this.updatesCount,
    required this.trashCount,
    required this.storageEstimateMb,
    required this.stats,
    this.errorMessage,
  });

  factory DashboardState.initial() {
    return DashboardState(
      status: DashboardStatus.loading,
      totalInbox: 0,
      unreadCount: 0,
      promotionsCount: 0,
      socialCount: 0,
      updatesCount: 0,
      trashCount: 0,
      storageEstimateMb: 0.0,
      stats: SwipeStats.initial(),
    );
  }

  DashboardState copyWith({
    DashboardStatus? status,
    int? totalInbox,
    int? unreadCount,
    int? promotionsCount,
    int? socialCount,
    int? updatesCount,
    int? trashCount,
    double? storageEstimateMb,
    SwipeStats? stats,
    String? errorMessage,
  }) {
    return DashboardState(
      status: status ?? this.status,
      totalInbox: totalInbox ?? this.totalInbox,
      unreadCount: unreadCount ?? this.unreadCount,
      promotionsCount: promotionsCount ?? this.promotionsCount,
      socialCount: socialCount ?? this.socialCount,
      updatesCount: updatesCount ?? this.updatesCount,
      trashCount: trashCount ?? this.trashCount,
      storageEstimateMb: storageEstimateMb ?? this.storageEstimateMb,
      stats: stats ?? this.stats,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class DashboardNotifier extends Notifier<DashboardState> {
  @override
  DashboardState build() {
    Future.microtask(() => loadDashboard());
    return DashboardState.initial();
  }

  Future<void> loadDashboard() async {
    final gmailService = ref.read(gmailServiceProvider);
    final storageService = ref.read(storageServiceProvider);

    state = state.copyWith(status: DashboardStatus.loading, errorMessage: null);
    try {
      // 1. Get user profile (email address)
      await gmailService.getProfile();

      // 2. Fetch metrics counts in parallel using lightweight queries
      final metrics = await Future.wait([
        gmailService.getResultCount('label:UNREAD label:INBOX'),
        gmailService.getResultCount('category:promotions label:INBOX'),
        gmailService.getResultCount('category:social label:INBOX'),
        gmailService.getResultCount('category:updates label:INBOX'),
        gmailService.getResultCount('label:INBOX'),
        gmailService.getResultCount('label:TRASH'),
      ]);

      final unread = metrics[0];
      final promotions = metrics[1];
      final social = metrics[2];
      final updates = metrics[3];
      final totalInbox = metrics[4];
      final trashCount = metrics[5];

      // Estimate storage: average email size is roughly 75 KB
      // We estimate storage used by INBOX as totalInbox * 75 KB / 1024
      final storageUsed = (totalInbox * 75) / 1024.0;

      // 3. Load stats from local storage
      final stats = storageService.getStats();

      state = DashboardState(
        status: DashboardStatus.loaded,
        totalInbox: totalInbox,
        unreadCount: unread,
        promotionsCount: promotions,
        socialCount: social,
        updatesCount: updates,
        trashCount: trashCount,
        storageEstimateMb: storageUsed,
        stats: stats,
      );
    } catch (e) {
      state = state.copyWith(
        status: DashboardStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final dashboardProvider = NotifierProvider<DashboardNotifier, DashboardState>(DashboardNotifier.new);
