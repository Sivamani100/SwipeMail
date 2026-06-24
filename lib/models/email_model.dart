import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;

class Email {
  final String id;
  final String threadId;
  final String senderName;
  final String senderEmail;
  final String subject;
  final String snippet;
  final String body;
  final DateTime date;
  final List<String> labels;
  final bool isRead;
  final int sizeEstimate;

  Email({
    required this.id,
    required this.threadId,
    required this.senderName,
    required this.senderEmail,
    required this.subject,
    required this.snippet,
    required this.body,
    required this.date,
    required this.labels,
    required this.isRead,
    required this.sizeEstimate,
  });

  /// Factory constructor to parse a Gmail API Message object
  factory Email.fromGmailMessage(gmail.Message message) {
    final headers = message.payload?.headers ?? [];
    String fromHeader = '';
    String subjectHeader = '';

    for (var header in headers) {
      final name = header.name?.toLowerCase();
      if (name == 'from') {
        fromHeader = header.value ?? '';
      } else if (name == 'subject') {
        subjectHeader = header.value ?? '';
      }
    }

    // Parse Sender Name and Email from From Header: "Sender Name <email@domain.com>"
    String senderName = '';
    String senderEmail = '';
    if (fromHeader.contains('<')) {
      final parts = fromHeader.split('<');
      senderName = parts[0].trim();
      senderEmail = parts[1].replaceAll('>', '').trim();
    } else {
      senderName = fromHeader.trim();
      senderEmail = fromHeader.trim();
    }
    // Clean up quotes around sender name
    if (senderName.startsWith('"') && senderName.endsWith('"') && senderName.length > 1) {
      senderName = senderName.substring(1, senderName.length - 1);
    }
    if (senderName.isEmpty) {
      senderName = senderEmail.split('@').first;
    }

    // Extract body content
    final bodyContent = _extractBody(message.payload);

    // Date
    DateTime emailDate = DateTime.now();
    if (message.internalDate != null) {
      final millis = int.tryParse(message.internalDate!);
      if (millis != null) {
        emailDate = DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    final labels = message.labelIds ?? [];
    final isRead = !labels.contains('UNREAD');

    return Email(
      id: message.id ?? '',
      threadId: message.threadId ?? '',
      senderName: senderName,
      senderEmail: senderEmail,
      subject: subjectHeader.isEmpty ? '(No Subject)' : subjectHeader,
      snippet: message.snippet ?? '',
      body: bodyContent,
      date: emailDate,
      labels: labels,
      isRead: isRead,
      sizeEstimate: message.sizeEstimate ?? 0,
    );
  }

  static String _extractBody(gmail.MessagePart? part) {
    if (part == null) return '';

    // If text/plain or text/html is directly in the body
    if (part.body?.data != null) {
      return _decodeBase64Url(part.body!.data!);
    }

    // Recursively check parts
    if (part.parts != null) {
      // Prioritize plain text first, then html
      for (var subPart in part.parts!) {
        if (subPart.mimeType == 'text/plain' && subPart.body?.data != null) {
          return _decodeBase64Url(subPart.body!.data!);
        }
      }
      for (var subPart in part.parts!) {
        if (subPart.mimeType == 'text/html' && subPart.body?.data != null) {
          return _decodeBase64Url(subPart.body!.data!);
        }
      }
      for (var subPart in part.parts!) {
        final content = _extractBody(subPart);
        if (content.isNotEmpty) return content;
      }
    }

    return '';
  }

  static String _decodeBase64Url(String input) {
    try {
      // Normalize base64 string
      String normalized = input.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final bytes = base64.decode(normalized);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'threadId': threadId,
      'senderName': senderName,
      'senderEmail': senderEmail,
      'subject': subject,
      'snippet': snippet,
      'body': body,
      'date': date.toIso8601String(),
      'labels': labels,
      'isRead': isRead,
      'sizeEstimate': sizeEstimate,
    };
  }

  factory Email.fromJson(Map<String, dynamic> json) {
    return Email(
      id: json['id'] as String,
      threadId: json['threadId'] as String,
      senderName: json['senderName'] as String,
      senderEmail: json['senderEmail'] as String,
      subject: json['subject'] as String,
      snippet: json['snippet'] as String,
      body: json['body'] as String,
      date: DateTime.parse(json['date'] as String),
      labels: List<String>.from(json['labels'] as List),
      isRead: json['isRead'] as bool,
      sizeEstimate: json['sizeEstimate'] as int,
    );
  }
}
