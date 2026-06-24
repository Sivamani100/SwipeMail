import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/email_model.dart';
import '../../widgets/common_widgets.dart';
import 'dashboard_provider.dart';

class TrashBinState {
  final List<Email> emails;
  final bool isLoading;
  final bool isLoadingMore;
  final String? nextPageToken;
  final String? errorMessage;
  final bool isActionInProgress;

  TrashBinState({
    required this.emails,
    required this.isLoading,
    required this.isLoadingMore,
    this.nextPageToken,
    this.errorMessage,
    required this.isActionInProgress,
  });

  factory TrashBinState.initial() {
    return TrashBinState(
      emails: [],
      isLoading: true,
      isLoadingMore: false,
      isActionInProgress: false,
    );
  }

  TrashBinState copyWith({
    List<Email>? emails,
    bool? isLoading,
    bool? isLoadingMore,
    String? nextPageToken,
    String? errorMessage,
    bool? isActionInProgress,
  }) {
    return TrashBinState(
      emails: emails ?? this.emails,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextPageToken: nextPageToken, // Can be null
      errorMessage: errorMessage,
      isActionInProgress: isActionInProgress ?? this.isActionInProgress,
    );
  }
}

class TrashBinNotifier extends Notifier<TrashBinState> {
  @override
  TrashBinState build() {
    Future.microtask(() => fetchTrashEmails());
    return TrashBinState.initial();
  }

  Future<void> fetchTrashEmails() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final gmailService = ref.read(gmailServiceProvider);
      final result = await gmailService.fetchEmails(
        query: 'label:TRASH',
        maxResults: 25,
      );
      state = state.copyWith(
        emails: result.emails,
        isLoading: false,
        nextPageToken: result.nextPageToken,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextPageToken == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final gmailService = ref.read(gmailServiceProvider);
      final result = await gmailService.fetchEmails(
        query: 'label:TRASH',
        maxResults: 25,
        pageToken: state.nextPageToken,
      );
      state = state.copyWith(
        emails: [...state.emails, ...result.emails],
        isLoadingMore: false,
        nextPageToken: result.nextPageToken,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<bool> restoreEmail(String messageId) async {
    state = state.copyWith(isActionInProgress: true);
    try {
      final gmailService = ref.read(gmailServiceProvider);
      await gmailService.untrashEmail(messageId);
      
      // Update UI state
      state = state.copyWith(
        emails: state.emails.where((e) => e.id != messageId).toList(),
        isActionInProgress: false,
      );
      
      // Refresh dashboard counts
      ref.read(dashboardProvider.notifier).loadDashboard();
      return true;
    } catch (e) {
      state = state.copyWith(isActionInProgress: false);
      return false;
    }
  }

  Future<bool> deleteEmailPermanently(String messageId) async {
    state = state.copyWith(isActionInProgress: true);
    try {
      final gmailService = ref.read(gmailServiceProvider);
      await gmailService.deleteEmailPermanently(messageId);
      
      // Update UI state
      state = state.copyWith(
        emails: state.emails.where((e) => e.id != messageId).toList(),
        isActionInProgress: false,
      );
      
      // Refresh dashboard counts
      ref.read(dashboardProvider.notifier).loadDashboard();
      return true;
    } catch (e) {
      state = state.copyWith(isActionInProgress: false);
      return false;
    }
  }

  Future<bool> emptyTrashPermanently() async {
    if (state.emails.isEmpty) return false;
    state = state.copyWith(isActionInProgress: true);
    try {
      final gmailService = ref.read(gmailServiceProvider);
      final ids = state.emails.map((e) => e.id).toList();
      await gmailService.deleteEmailsPermanentlyBatch(ids);
      
      state = state.copyWith(
        emails: [],
        isActionInProgress: false,
        nextPageToken: null,
      );
      
      // Refresh dashboard counts
      ref.read(dashboardProvider.notifier).loadDashboard();
      return true;
    } catch (e) {
      state = state.copyWith(isActionInProgress: false);
      return false;
    }
  }
}

final trashBinNotifierProvider =
    NotifierProvider<TrashBinNotifier, TrashBinState>(TrashBinNotifier.new);

class TrashBinScreen extends ConsumerStatefulWidget {
  const TrashBinScreen({super.key});

  @override
  ConsumerState<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends ConsumerState<TrashBinScreen> {
  final ScrollController _scrollController = ScrollController();
  String? _expandedEmailId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(trashBinNotifierProvider.notifier).loadMore();
    }
  }

  void _confirmDeleteAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash Bin?'),
        content: const Text(
          'This will permanently delete all the listed emails in your Trash. This action cannot be undone on Gmail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await ref.read(trashBinNotifierProvider.notifier).emptyTrashPermanently();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Trash Bin emptied successfully.'
                          : 'Failed to empty Trash Bin.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete All Permanently'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePermanently(BuildContext context, Email email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Permanently?'),
        content: Text(
          'Are you sure you want to permanently delete "${email.subject}"? This action cannot be undone on Gmail.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                  .read(trashBinNotifierProvider.notifier)
                  .deleteEmailPermanently(email.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Email deleted permanently.'
                          : 'Failed to delete email.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trashState = ref.watch(trashBinNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Trash Bin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (trashState.emails.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              tooltip: 'Empty Trash',
              onPressed: () => _confirmDeleteAll(context),
            ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Info Banner Card
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GlassContainer(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(16),
                    color: isDark
                        ? const Color(0xFF1E193C).withOpacity(0.4)
                        : Colors.blue.shade50.withOpacity(0.5),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'These emails have been moved to your Gmail Trash. You can restore them back to your Inbox, or permanently delete them.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                  height: 1.4,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (trashState.isLoading) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (trashState.errorMessage != null) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                                const SizedBox(height: 16),
                                Text(
                                  trashState.errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () => ref
                                      .read(trashBinNotifierProvider.notifier)
                                      .fetchTrashEmails(),
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (trashState.emails.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 80,
                                color: isDark ? Colors.white30 : Colors.black26,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your trash is clean!',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No emails in label:TRASH.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        onRefresh: () => ref
                            .read(trashBinNotifierProvider.notifier)
                            .fetchTrashEmails(),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: trashState.emails.length +
                              (trashState.isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == trashState.emails.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }

                            final email = trashState.emails[index];
                            final isExpanded = _expandedEmailId == email.id;

                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.only(bottom: 12),
                              child: GlassContainer(
                                borderRadius: 24,
                                padding: EdgeInsets.zero,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () {
                                    setState(() {
                                      _expandedEmailId = isExpanded ? null : email.id;
                                    });
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Sender Initial Circle
                                            CircleAvatar(
                                              radius: 20,
                                              backgroundColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.1),
                                              child: Text(
                                                email.senderName.isNotEmpty
                                                    ? email.senderName[0].toUpperCase()
                                                    : 'M',
                                                style: TextStyle(
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          email.senderName,
                                                          style: Theme.of(context)
                                                              .textTheme
                                                              .titleMedium
                                                              ?.copyWith(
                                                                fontWeight:
                                                                    FontWeight.bold,
                                                              ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow.ellipsis,
                                                        ),
                                                      ),
                                                      Text(
                                                        _formatDate(email.date),
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: isDark
                                                                  ? Colors.white30
                                                                  : Colors.black38,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    email.subject,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black87,
                                                        ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (!isExpanded) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      email.snippet,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodySmall,
                                                      maxLines: 2,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Expanded email details and actions
                                      if (isExpanded) ...[
                                        const Divider(height: 1, color: Colors.white12),
                                        Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'From: ${email.senderEmail}',
                                                style: Theme.of(context).textTheme.bodySmall,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                email.body.isNotEmpty
                                                    ? email.body
                                                    : email.snippet,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      height: 1.5,
                                                    ),
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  // Restore button
                                                  OutlinedButton.icon(
                                                    style: OutlinedButton.styleFrom(
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                      ),
                                                      side: BorderSide(
                                                        color: Theme.of(context)
                                                            .colorScheme
                                                            .primary,
                                                      ),
                                                    ),
                                                    onPressed: () async {
                                                      final success = await ref
                                                          .read(trashBinNotifierProvider
                                                              .notifier)
                                                          .restoreEmail(email.id);
                                                      if (mounted) {
                                                        ScaffoldMessenger.of(context)
                                                            .showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              success
                                                                  ? 'Email restored to Inbox.'
                                                                  : 'Failed to restore email.',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                                    icon: const Icon(Icons.restore_page_rounded),
                                                    label: const Text('Restore to Inbox'),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Delete permanently button
                                                  ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    onPressed: () =>
                                                        _confirmDeletePermanently(
                                                            context, email),
                                                    icon: const Icon(
                                                      Icons.delete_forever_rounded,
                                                      color: Colors.white,
                                                    ),
                                                    label: const Text('Delete Permanently'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            if (trashState.isActionInProgress)
              Container(
                color: Colors.black45,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays < 7) {
      final weekday = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
      return weekday;
    } else {
      return '${date.day}/${date.month}';
    }
  }
}
