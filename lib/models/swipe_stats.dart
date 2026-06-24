class SwipeStats {
  final int totalSessions;
  final int totalSwipes;
  final int totalTrashed;
  final int totalKept;
  final int totalSessionSeconds;

  SwipeStats({
    required this.totalSessions,
    required this.totalSwipes,
    required this.totalTrashed,
    required this.totalKept,
    required this.totalSessionSeconds,
  });

  factory SwipeStats.initial() {
    return SwipeStats(
      totalSessions: 0,
      totalSwipes: 0,
      totalTrashed: 0,
      totalKept: 0,
      totalSessionSeconds: 0,
    );
  }

  double get averageSessionDurationMinutes {
    if (totalSessions == 0) return 0.0;
    return (totalSessionSeconds / 60.0) / totalSessions;
  }

  double get savedStorageMb {
    // Assuming average email size is about 75KB if size estimate is not accurate,
    // but we can compute this based on actual trashing size in bytes.
    // Let's assume size estimate is in bytes and 1 MB = 1024 * 1024 bytes.
    return (totalTrashed * 75 * 1024) / (1024 * 1024); // fallback average 75KB per email
  }

  SwipeStats copyWith({
    int? totalSessions,
    int? totalSwipes,
    int? totalTrashed,
    int? totalKept,
    int? totalSessionSeconds,
  }) {
    return SwipeStats(
      totalSessions: totalSessions ?? this.totalSessions,
      totalSwipes: totalSwipes ?? this.totalSwipes,
      totalTrashed: totalTrashed ?? this.totalTrashed,
      totalKept: totalKept ?? this.totalKept,
      totalSessionSeconds: totalSessionSeconds ?? this.totalSessionSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalSessions': totalSessions,
      'totalSwipes': totalSwipes,
      'totalTrashed': totalTrashed,
      'totalKept': totalKept,
      'totalSessionSeconds': totalSessionSeconds,
    };
  }

  factory SwipeStats.fromJson(Map<String, dynamic> json) {
    return SwipeStats(
      totalSessions: json['totalSessions'] as int? ?? 0,
      totalSwipes: json['totalSwipes'] as int? ?? 0,
      totalTrashed: json['totalTrashed'] as int? ?? 0,
      totalKept: json['totalKept'] as int? ?? 0,
      totalSessionSeconds: json['totalSessionSeconds'] as int? ?? 0,
    );
  }
}

class SessionHistory {
  final DateTime timestamp;
  final int reviewedCount;
  final int trashedCount;
  final int keptCount;
  final int durationSeconds;

  SessionHistory({
    required this.timestamp,
    required this.reviewedCount,
    required this.trashedCount,
    required this.keptCount,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'reviewedCount': reviewedCount,
      'trashedCount': trashedCount,
      'keptCount': keptCount,
      'durationSeconds': durationSeconds,
    };
  }

  factory SessionHistory.fromJson(Map<String, dynamic> json) {
    return SessionHistory(
      timestamp: DateTime.parse(json['timestamp'] as String),
      reviewedCount: json['reviewedCount'] as int,
      trashedCount: json['trashedCount'] as int,
      keptCount: json['keptCount'] as int,
      durationSeconds: json['durationSeconds'] as int,
    );
  }
}
