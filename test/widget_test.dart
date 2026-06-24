import 'package:flutter_test/flutter_test.dart';
import 'package:swipemail/models/email_model.dart';
import 'package:swipemail/models/swipe_stats.dart';

void main() {
  group('SwipeStats Tests', () {
    test('Initial stats should be zero', () {
      final stats = SwipeStats.initial();
      expect(stats.totalSessions, 0);
      expect(stats.totalSwipes, 0);
      expect(stats.totalTrashed, 0);
      expect(stats.totalKept, 0);
      expect(stats.totalSessionSeconds, 0);
    });

    test('copyWith updates stats correctly', () {
      final stats = SwipeStats.initial();
      final updated = stats.copyWith(
        totalSessions: 2,
        totalSwipes: 10,
        totalTrashed: 4,
        totalKept: 6,
        totalSessionSeconds: 120,
      );
      expect(updated.totalSessions, 2);
      expect(updated.totalSwipes, 10);
      expect(updated.totalTrashed, 4);
      expect(updated.totalKept, 6);
      expect(updated.totalSessionSeconds, 120);
      expect(updated.averageSessionDurationMinutes, 1.0);
    });
  });

  group('Email JSON Serialization Tests', () {
    test('Email to/from JSON matches', () {
      final email = Email(
        id: '123',
        threadId: '456',
        senderName: 'Test Sender',
        senderEmail: 'test@example.com',
        subject: 'Hello World',
        snippet: 'Just a test email snippet',
        body: 'Full body content of test email',
        date: DateTime.utc(2026, 6, 24, 12, 0, 0),
        labels: ['INBOX', 'UNREAD'],
        isRead: false,
        sizeEstimate: 1024,
      );

      final jsonMap = email.toJson();
      final parsed = Email.fromJson(jsonMap);

      expect(parsed.id, email.id);
      expect(parsed.threadId, email.threadId);
      expect(parsed.senderName, email.senderName);
      expect(parsed.senderEmail, email.senderEmail);
      expect(parsed.subject, email.subject);
      expect(parsed.snippet, email.snippet);
      expect(parsed.body, email.body);
      expect(parsed.date.isAtSameMomentAs(email.date), true);
      expect(parsed.labels, email.labels);
      expect(parsed.isRead, email.isRead);
      expect(parsed.sizeEstimate, email.sizeEstimate);
    });
  });
}
