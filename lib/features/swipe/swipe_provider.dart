import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../models/email_model.dart';
import '../../services/gmail_service.dart';
import '../../services/storage_service.dart';

enum SwipeStatus {
  loading,
  loaded,
  empty,
  error,
  trashing,
  success,
}

enum CardType {
  individual,
  bulk,
}

class SwipeCard {
  final String id;
  final CardType type;
  final Email? email; // Null if bulk
  final String? senderName; // Null if individual
  final String? senderEmail; // Null if individual
  final int? emailCount; // Null if individual
  final List<Email>? associatedEmails; // Null if individual

  SwipeCard.individual(Email this.email)
      : id = email.id,
        type = CardType.individual,
        senderName = null,
        senderEmail = null,
        emailCount = null,
        associatedEmails = null;

  SwipeCard.bulk({
    required this.senderName,
    required this.senderEmail,
    required List<Email> emails,
  })  : id = senderEmail!,
        type = CardType.bulk,
        emailCount = emails.length,
        associatedEmails = emails,
        email = null;
}

class SwipeHistoryAction {
  final SwipeCard card;
  final bool wasDeleted;
  final bool wasBulkAction;
  final bool wasExpanded;
  final List<Email>? itemsRestored; // Items that were moved to queue and are restored on undo

  SwipeHistoryAction({
    required this.card,
    required this.wasDeleted,
    required this.wasBulkAction,
    required this.wasExpanded,
    this.itemsRestored,
  });
}

class SwipeState {
  final SwipeStatus status;
  final List<SwipeCard> cards;
  final List<Email> deleteQueue;
  final List<Email> keepQueue;
  final List<SwipeHistoryAction> history;
  final String categoryName;
  final String query;
  final String? nextPageToken;
  final String? errorMessage;
  final int batchProgress;
  final int batchTotal;

  SwipeState({
    required this.status,
    required this.cards,
    required this.deleteQueue,
    required this.keepQueue,
    required this.history,
    required this.categoryName,
    required this.query,
    this.nextPageToken,
    this.errorMessage,
    this.batchProgress = 0,
    this.batchTotal = 0,
  });

  factory SwipeState.initial() {
    return SwipeState(
      status: SwipeStatus.loading,
      cards: [],
      deleteQueue: [],
      keepQueue: [],
      history: [],
      categoryName: 'Inbox',
      query: 'label:INBOX',
    );
  }

  SwipeState copyWith({
    SwipeStatus? status,
    List<SwipeCard>? cards,
    List<Email>? deleteQueue,
    List<Email>? keepQueue,
    List<SwipeHistoryAction>? history,
    String? categoryName,
    String? query,
    String? nextPageToken,
    String? errorMessage,
    int? batchProgress,
    int? batchTotal,
  }) {
    return SwipeState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      deleteQueue: deleteQueue ?? this.deleteQueue,
      keepQueue: keepQueue ?? this.keepQueue,
      history: history ?? this.history,
      categoryName: categoryName ?? this.categoryName,
      query: query ?? this.query,
      nextPageToken: nextPageToken ?? this.nextPageToken,
      errorMessage: errorMessage ?? this.errorMessage,
      batchProgress: batchProgress ?? this.batchProgress,
      batchTotal: batchTotal ?? this.batchTotal,
    );
  }
}

class SwipeNotifier extends Notifier<SwipeState> {
  DateTime? _sessionStartTime;

  @override
  SwipeState build() {
    Future.microtask(() => initQuery('Inbox', 'label:INBOX'));
    return SwipeState.initial();
  }

  void startSession() {
    _sessionStartTime = DateTime.now();
  }

  String? getNextCategory(String currentCategory) {
    switch (currentCategory) {
      case 'Inbox':
        return 'Promotions';
      case 'Promotions':
        return 'Social';
      case 'Social':
        return 'Updates';
      default:
        return null;
    }
  }

  String getQueryForCategory(String category) {
    switch (category) {
      case 'Promotions':
        return 'category:promotions label:INBOX';
      case 'Social':
        return 'category:social label:INBOX';
      case 'Updates':
        return 'category:updates label:INBOX';
      default:
        return 'label:INBOX';
    }
  }

  void _checkAndAdvanceCategory() {
    if (state.cards.isEmpty && state.nextPageToken == null) {
      final nextCat = getNextCategory(state.categoryName);
      if (nextCat != null) {
        state = state.copyWith(
          categoryName: nextCat,
          query: getQueryForCategory(nextCat),
          nextPageToken: null,
          status: SwipeStatus.loading,
        );
        loadMoreEmails();
      } else {
        state = state.copyWith(status: SwipeStatus.empty);
      }
    } else if (state.cards.isEmpty && state.nextPageToken != null) {
      loadMoreEmails();
    }
  }

  /// Initialize swipe stack with a query.
  void initQuery(String categoryName, String query) {
    state = SwipeState(
      status: SwipeStatus.loading,
      cards: [],
      deleteQueue: [],
      keepQueue: [],
      history: [],
      categoryName: categoryName,
      query: query,
    );
    startSession();
    loadMoreEmails();
  }

  /// Loads emails from Gmail API and aggregates duplicate senders into bulk cards.
  Future<void> loadMoreEmails() async {
    state = state.copyWith(status: SwipeStatus.loading, errorMessage: null);
    try {
      final GmailService gmailService = ref.read(gmailServiceProvider);
      final result = await gmailService.fetchEmails(
        query: state.query,
        maxResults: 40,
        pageToken: state.nextPageToken,
      );

      final keptIds = ref.read(storageServiceProvider).getKeptEmailIds().toSet();
      final inMemoryQueueIds = {
        ...state.keepQueue.map((e) => e.id),
        ...state.deleteQueue.map((e) => e.id),
      };

      final filteredEmails = result.emails.where((e) {
        return !keptIds.contains(e.id) && !inMemoryQueueIds.contains(e.id);
      }).toList();

      final List<SwipeCard> newCards = _groupAndBuildCards(filteredEmails);

      state = state.copyWith(
        cards: [...state.cards, ...newCards],
        nextPageToken: result.nextPageToken,
        status: SwipeStatus.loaded,
      );

      if (state.cards.isEmpty) {
        _checkAndAdvanceCategory();
      }
    } catch (e) {
      state = state.copyWith(
        status: SwipeStatus.error,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  List<SwipeCard> _groupAndBuildCards(List<Email> emails) {
    if (emails.isEmpty) return [];

    // Group emails by sender email
    final Map<String, List<Email>> grouped = {};
    for (var email in emails) {
      final senderKey = email.senderEmail.toLowerCase().trim();
      grouped.putIfAbsent(senderKey, () => []).add(email);
    }

    final List<SwipeCard> built = [];
    grouped.forEach((senderEmail, senderEmails) {
      if (senderEmails.length >= 5) {
        built.add(SwipeCard.bulk(
          senderName: senderEmails.first.senderName,
          senderEmail: senderEmails.first.senderEmail,
          emails: senderEmails,
        ));
      } else {
        for (var email in senderEmails) {
          built.add(SwipeCard.individual(email));
        }
      }
    });

    // Sort cards by date (newest first)
    built.sort((a, b) {
      final dateA = a.type == CardType.individual ? a.email!.date : a.associatedEmails!.first.date;
      final dateB = b.type == CardType.individual ? b.email!.date : b.associatedEmails!.first.date;
      return dateB.compareTo(dateA);
    });

    return built;
  }

  /// Swipe right to keep
  void swipeKeep() {
    if (state.cards.isEmpty) return;
    final card = state.cards.first;
    final remaining = List<SwipeCard>.from(state.cards)..removeAt(0);

    if (card.type == CardType.individual) {
      final email = card.email!;
      ref.read(storageServiceProvider).addKeptEmailIds([email.id]);
      state = state.copyWith(
        cards: remaining,
        keepQueue: [...state.keepQueue, email],
        history: [
          ...state.history,
          SwipeHistoryAction(
            card: card,
            wasDeleted: false,
            wasBulkAction: false,
            wasExpanded: false,
            itemsRestored: [email],
          )
        ],
        status: remaining.isEmpty ? SwipeStatus.empty : SwipeStatus.loaded,
      );
    } else {
      // Bulk keep
      final emails = card.associatedEmails!;
      ref.read(storageServiceProvider).addKeptEmailIds(emails.map((e) => e.id).toList());
      state = state.copyWith(
        cards: remaining,
        keepQueue: [...state.keepQueue, ...emails],
        history: [
          ...state.history,
          SwipeHistoryAction(
            card: card,
            wasDeleted: false,
            wasBulkAction: true,
            wasExpanded: false,
            itemsRestored: emails,
          )
        ],
        status: remaining.isEmpty ? SwipeStatus.empty : SwipeStatus.loaded,
      );
    }

    if (remaining.isEmpty) {
      _checkAndAdvanceCategory();
    }
  }

  /// Swipe left to delete
  void swipeDelete() {
    if (state.cards.isEmpty) return;
    final card = state.cards.first;
    final remaining = List<SwipeCard>.from(state.cards)..removeAt(0);

    if (card.type == CardType.individual) {
      final email = card.email!;
      state = state.copyWith(
        cards: remaining,
        deleteQueue: [...state.deleteQueue, email],
        history: [
          ...state.history,
          SwipeHistoryAction(
            card: card,
            wasDeleted: true,
            wasBulkAction: false,
            wasExpanded: false,
            itemsRestored: [email],
          )
        ],
        status: remaining.isEmpty ? SwipeStatus.empty : SwipeStatus.loaded,
      );
    } else {
      // Bulk delete
      final emails = card.associatedEmails!;
      state = state.copyWith(
        cards: remaining,
        deleteQueue: [...state.deleteQueue, ...emails],
        history: [
          ...state.history,
          SwipeHistoryAction(
            card: card,
            wasDeleted: true,
            wasBulkAction: true,
            wasExpanded: false,
            itemsRestored: emails,
          )
        ],
        status: remaining.isEmpty ? SwipeStatus.empty : SwipeStatus.loaded,
      );
    }

    if (remaining.isEmpty) {
      _checkAndAdvanceCategory();
    }
  }

  /// Expand bulk card to review individually
  void reviewGroupIndividually() {
    if (state.cards.isEmpty) return;
    final card = state.cards.first;
    if (card.type != CardType.bulk) return;

    final remaining = List<SwipeCard>.from(state.cards)..removeAt(0);
    final expandedCards = card.associatedEmails!.map((e) => SwipeCard.individual(e)).toList();

    state = state.copyWith(
      cards: [...expandedCards, ...remaining],
      history: [
        ...state.history,
        SwipeHistoryAction(
          card: card,
          wasDeleted: false,
          wasBulkAction: false,
          wasExpanded: true,
        )
      ],
    );
  }

  /// Undo the last swiped card action
  void undo() {
    if (state.history.isEmpty) return;

    final lastAction = state.history.last;
    final updatedHistory = List<SwipeHistoryAction>.from(state.history)..removeLast();

    if (lastAction.wasExpanded) {
      // Re-collapse individual cards back into the bulk card
      final countToCollapse = lastAction.card.associatedEmails!.length;
      final remainingCards = List<SwipeCard>.from(state.cards)..removeRange(0, countToCollapse);
      
      state = state.copyWith(
        cards: [lastAction.card, ...remainingCards],
        history: updatedHistory,
        status: SwipeStatus.loaded,
      );
    } else {
      // Restore individual/bulk items from keep/delete queues
      final restoredEmails = lastAction.itemsRestored ?? [];
      final restoredIds = restoredEmails.map((e) => e.id).toSet();

      final updatedDelete = List<Email>.from(state.deleteQueue)
        ..removeWhere((e) => restoredIds.contains(e.id));
      final updatedKeep = List<Email>.from(state.keepQueue)
        ..removeWhere((e) => restoredIds.contains(e.id));

      if (!lastAction.wasDeleted) {
        ref.read(storageServiceProvider).removeKeptEmailIds(restoredIds.toList());
      }

      state = state.copyWith(
        cards: [lastAction.card, ...state.cards],
        deleteQueue: updatedDelete,
        keepQueue: updatedKeep,
        history: updatedHistory,
        status: SwipeStatus.loaded,
      );
    }
  }

  /// Directly moves an email from delete queue to keep queue or vice versa in review screen
  void toggleReviewState(Email email, bool keep) {
    if (keep) {
      final updatedDelete = List<Email>.from(state.deleteQueue)..removeWhere((e) => e.id == email.id);
      final updatedKeep = List<Email>.from(state.keepQueue);
      if (!updatedKeep.any((e) => e.id == email.id)) {
        updatedKeep.add(email);
        ref.read(storageServiceProvider).addKeptEmailIds([email.id]);
      }
      state = state.copyWith(deleteQueue: updatedDelete, keepQueue: updatedKeep);
    } else {
      final updatedKeep = List<Email>.from(state.keepQueue)..removeWhere((e) => e.id == email.id);
      final updatedDelete = List<Email>.from(state.deleteQueue);
      if (!updatedDelete.any((e) => e.id == email.id)) {
        updatedDelete.add(email);
        ref.read(storageServiceProvider).removeKeptEmailIds([email.id]);
      }
      state = state.copyWith(deleteQueue: updatedDelete, keepQueue: updatedKeep);
    }
  }

  /// Executes trashing emails in Gmail
  Future<void> executeTrashing() async {
    if (state.deleteQueue.isEmpty) {
      state = state.copyWith(status: SwipeStatus.success);
      return;
    }

    state = state.copyWith(
      status: SwipeStatus.trashing,
      batchProgress: 0,
      batchTotal: state.deleteQueue.length,
    );

    final deleteIds = state.deleteQueue.map((e) => e.id).toList();

    final GmailService gmailService = ref.read(gmailServiceProvider);
    final StorageService storageService = ref.read(storageServiceProvider);

    try {
      await gmailService.trashEmailsBatch(
        deleteIds,
        onProgress: (processed) {
          state = state.copyWith(batchProgress: processed);
        },
      );

      // Save statistics in local storage
      final sessionSeconds = _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inSeconds
          : 60;

      await storageService.updateStats(
        additionalSwipes: state.keepQueue.length + state.deleteQueue.length,
        additionalTrashed: state.deleteQueue.length,
        additionalKept: state.keepQueue.length,
        sessionSeconds: sessionSeconds,
      );

      state = state.copyWith(status: SwipeStatus.success);
      await storageService.clearKeptEmailIds();
    } catch (e) {
      state = state.copyWith(
        status: SwipeStatus.error,
        errorMessage: 'Failed to trash emails: $e',
      );
    }
  }

  void reset() {
    state = SwipeState.initial();
    Future.microtask(() => initQuery('Inbox', 'label:INBOX'));
  }
}

final swipeProvider = NotifierProvider<SwipeNotifier, SwipeState>(SwipeNotifier.new);
