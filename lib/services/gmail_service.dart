import 'dart:async';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import '../models/email_model.dart';
import 'auth_service.dart';

/// An HTTP Client that appends native Google Sign-in headers dynamically.
class GoogleSignInHttpClient extends http.BaseClient {
  final http.Client _inner = http.Client();
  final AuthService _authService;

  GoogleSignInHttpClient(this._authService);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final headers = await _authService.getAuthHeaders();
    request.headers.addAll(headers);
    request.headers['Accept'] = 'application/json';
    return _inner.send(request);
  }
}

class GmailService {
  final AuthService _authService;

  GmailService(this._authService);

  /// Helper to get an authenticated GmailApi instance.
  Future<gmail.GmailApi> _getGmailApi() async {
    final hasSession = await _authService.tryRestoreSession();
    if (!hasSession) {
      throw Exception('User is not authenticated');
    }

    final client = GoogleSignInHttpClient(_authService);
    return gmail.GmailApi(client);
  }

  /// Fetches basic profile info (email and total messages)
  Future<Map<String, dynamic>> getProfile() async {
    final api = await _getGmailApi();
    final profile = await api.users.getProfile('me');
    return {
      'email': profile.emailAddress ?? '',
      'messagesTotal': profile.messagesTotal ?? 0,
      'threadsTotal': profile.threadsTotal ?? 0,
    };
  }

  /// Fetches estimate of message count for a specific query.
  /// Uses a quick search with maxResults=1 to get resultSizeEstimate.
  Future<int> getResultCount(String query) async {
    try {
      final api = await _getGmailApi();
      final res = await api.users.messages.list('me', q: query, maxResults: 1);
      return res.resultSizeEstimate ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches a list of emails with full details.
  /// Supports pagination using [pageToken].
  Future<GmailFetchResult> fetchEmails({
    String query = 'label:INBOX',
    int maxResults = 25,
    String? pageToken,
  }) async {
    final api = await _getGmailApi();
    
    // 1. Get list of message summaries
    final listResponse = await api.users.messages.list(
      'me',
      q: query,
      maxResults: maxResults,
      pageToken: pageToken,
    );

    final messageSummaries = listResponse.messages ?? [];
    final nextPageToken = listResponse.nextPageToken;

    if (messageSummaries.isEmpty) {
      return GmailFetchResult(emails: [], nextPageToken: nextPageToken);
    }

    // 2. Fetch full details for each message in parallel (bounded to avoid rate limits)
    // We fetch details in chunks of 5
    final List<Email> emails = [];
    const chunkSize = 5;
    
    for (var i = 0; i < messageSummaries.length; i += chunkSize) {
      final chunk = messageSummaries.sublist(
        i, 
        i + chunkSize > messageSummaries.length ? messageSummaries.length : i + chunkSize
      );

      final chunkResults = await Future.wait(
        chunk.map((msgSummary) async {
          try {
            final fullMsg = await api.users.messages.get('me', msgSummary.id!, format: 'full');
            return Email.fromGmailMessage(fullMsg);
          } catch (e) {
            // Log or ignore failed individual email fetches
            return null;
          }
        }),
      );

      emails.addAll(chunkResults.whereType<Email>());
    }

    return GmailFetchResult(emails: emails, nextPageToken: nextPageToken);
  }

  /// Moves a batch of emails to Gmail Trash.
  /// Uses batchModify for higher efficiency.
  Future<void> trashEmailsBatch(List<String> messageIds, {Function(int processed)? onProgress}) async {
    if (messageIds.isEmpty) return;

    final api = await _getGmailApi();
    
    // Gmail limits batchModify to 1000 messages per request
    const batchSize = 100;
    int processed = 0;

    for (var i = 0; i < messageIds.length; i += batchSize) {
      final chunk = messageIds.sublist(
        i,
        i + batchSize > messageIds.length ? messageIds.length : i + batchSize,
      );

      // Perform batch modification: add TRASH label, remove INBOX label
      final request = gmail.BatchModifyMessagesRequest(
        ids: chunk,
        addLabelIds: ['TRASH'],
        removeLabelIds: ['INBOX'],
      );

      // Retry logic for robustness
      int retries = 3;
      bool success = false;
      while (retries > 0 && !success) {
        try {
          await api.users.messages.batchModify(request, 'me');
          success = true;
        } catch (e) {
          retries--;
          if (retries == 0) {
            // Throw if all retries fail
            throw Exception('Failed to trash batch of emails: $e');
          }
          // Wait before retrying (exponential backoff)
          await Future.delayed(Duration(seconds: (4 - retries) * 2));
        }
      }

      processed += chunk.length;
      if (onProgress != null) {
        onProgress(processed);
      }
    }
  }

  /// Restores an email from Trash by removing TRASH label and adding INBOX label.
  Future<void> untrashEmail(String messageId) async {
    final api = await _getGmailApi();
    final request = gmail.ModifyMessageRequest(
      addLabelIds: ['INBOX'],
      removeLabelIds: ['TRASH'],
    );
    await api.users.messages.modify(request, 'me', messageId);
  }

  /// Permanently deletes an email. This cannot be undone.
  Future<void> deleteEmailPermanently(String messageId) async {
    final api = await _getGmailApi();
    await api.users.messages.delete('me', messageId);
  }

  /// Empties the entire Gmail Trash folder. This cannot be undone.
  Future<void> emptyAllTrash() async {
    final hasSession = await _authService.tryRestoreSession();
    if (!hasSession) {
      throw Exception('User is not authenticated');
    }
    final client = GoogleSignInHttpClient(_authService);
    final response = await client.post(
      Uri.parse('https://gmail.googleapis.com/gmail/v1/users/me/trash/empty'),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to empty trash: ${response.body}');
    }
  }

  /// Permanently deletes multiple emails in parallel.
  Future<void> deleteEmailsPermanentlyBatch(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    final api = await _getGmailApi();
    const chunkSize = 10;
    for (var i = 0; i < messageIds.length; i += chunkSize) {
      final chunk = messageIds.sublist(
        i,
        i + chunkSize > messageIds.length ? messageIds.length : i + chunkSize,
      );
      await Future.wait(
        chunk.map((id) => api.users.messages.delete('me', id)),
      );
    }
  }
}

class GmailFetchResult {
  final List<Email> emails;
  final String? nextPageToken;

  GmailFetchResult({required this.emails, this.nextPageToken});
}
