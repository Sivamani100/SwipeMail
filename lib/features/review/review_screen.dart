import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../swipe/swipe_provider.dart';
import '../../models/email_model.dart';
import '../../routing/app_router.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(swipeProvider);
    final notifier = ref.read(swipeProvider.notifier);

    // Grouping functions
    final deleteGroups = _groupEmailsBySender(state.deleteQueue);
    final keepGroups = _groupEmailsBySender(state.keepQueue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Decisions'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: [
            Tab(text: 'Trash Queue (${state.deleteQueue.length})'),
            Tab(text: 'Keep Queue (${state.keepQueue.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Trash Queue
          _buildQueueList(
            context,
            groups: deleteGroups,
            isDeleteQueue: true,
            onAction: (email) => notifier.toggleReviewState(email, true), // Toggle to Keep
            emptyText: 'No emails in Trash Queue.',
            actionIcon: Icons.check_circle_outline,
            actionColor: const Color(0xFF00B894),
            actionTooltip: 'Keep this email',
          ),
          // Tab 2: Keep Queue
          _buildQueueList(
            context,
            groups: keepGroups,
            isDeleteQueue: false,
            onAction: (email) => notifier.toggleReviewState(email, false), // Toggle to Delete
            emptyText: 'No emails in Keep Queue.',
            actionIcon: Icons.delete_outline,
            actionColor: const Color(0xFFD63031),
            actionTooltip: 'Move to Trash Queue',
          ),
        ],
      ),
      bottomNavigationBar: state.deleteQueue.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF16122C)
                    : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  )
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Total to Trash: ${state.deleteQueue.length} emails',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD63031),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _showConfirmationDialog(context, state.deleteQueue.length),
                      child: const Text('Empty Queue'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Map<String, List<Email>> _groupEmailsBySender(List<Email> emails) {
    final Map<String, List<Email>> grouped = {};
    for (var email in emails) {
      final key = email.senderName.isNotEmpty ? email.senderName : email.senderEmail;
      grouped.putIfAbsent(key, () => []).add(email);
    }
    return grouped;
  }

  Widget _buildQueueList(
    BuildContext context, {
    required Map<String, List<Email>> groups,
    required bool isDeleteQueue,
    required Function(Email) onAction,
    required String emptyText,
    required IconData actionIcon,
    required Color actionColor,
    required String actionTooltip,
  }) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(emptyText, style: const TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    final keys = groups.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final sender = keys[index];
        final emails = groups[sender]!;

        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            title: Text(
              sender,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${emails.length} email${emails.length > 1 ? 's' : ''}',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            children: emails.map((email) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  email.subject,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  email.snippet,
                  style: const TextStyle(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: Icon(actionIcon, color: actionColor),
                  tooltip: actionTooltip,
                  onPressed: () => onAction(email),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showConfirmationDialog(BuildContext context, int count) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
          title: const Text('Move to Gmail Trash'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You are about to move $count emails to Gmail Trash.',
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Nothing will be permanently deleted. Gmail keeps trashed emails for 30 days, allowing you to restore them easily from your Gmail account if needed.',
                style: TextStyle(fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Review Again'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD63031),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                AppRouter.navigateToExecution(context); // Go to execution
              },
              child: const Text('Move to Trash'),
            ),
          ],
        );
      },
    );
  }
}
