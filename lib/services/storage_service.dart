import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/swipe_stats.dart';
import '../models/email_model.dart';

class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  StorageService(this._prefs, this._secureStorage);

  static Future<StorageService> init() async {
    final prefs = await SharedPreferences.getInstance();
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return StorageService(prefs, secureStorage);
  }

  // --- Onboarding ---
  bool isOnboardingCompleted() {
    return _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    await _prefs.setBool(StorageKeys.onboardingCompleted, value);
  }

  // --- Theme Mode ---
  bool isDarkMode() {
    return _prefs.getBool(StorageKeys.isDarkMode) ?? false; // Default to light mode
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(StorageKeys.isDarkMode, value);
  }

  // --- OAuth Sensitive Storage ---
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
    required DateTime expiry,
  }) async {
    await _secureStorage.write(key: 'access_token', value: accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: 'refresh_token', value: refreshToken);
    }
    await _secureStorage.write(key: 'token_expiry', value: expiry.toIso8601String());
  }

  Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: 'access_token');
  }

  Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: 'refresh_token');
  }

  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _secureStorage.read(key: 'token_expiry');
    if (expiryStr == null) return null;
    return DateTime.tryParse(expiryStr);
  }

  Future<void> clearTokens() async {
    await _secureStorage.delete(key: 'access_token');
    await _secureStorage.delete(key: 'refresh_token');
    await _secureStorage.delete(key: 'token_expiry');
  }

  // --- Swipe Statistics ---
  SwipeStats getStats() {
    final sessions = _prefs.getInt(StorageKeys.statsSessions) ?? 0;
    final swipes = _prefs.getInt(StorageKeys.statsSwipes) ?? 0;
    final trashed = _prefs.getInt(StorageKeys.statsDeleted) ?? 0;
    final kept = _prefs.getInt(StorageKeys.statsSaved) ?? 0;
    final seconds = _prefs.getInt(StorageKeys.statsDuration) ?? 0;

    return SwipeStats(
      totalSessions: sessions,
      totalSwipes: swipes,
      totalTrashed: trashed,
      totalKept: kept,
      totalSessionSeconds: seconds,
    );
  }

  Future<void> updateStats({
    required int additionalSwipes,
    required int additionalTrashed,
    required int additionalKept,
    required int sessionSeconds,
  }) async {
    final current = getStats();
    await _prefs.setInt(StorageKeys.statsSessions, current.totalSessions + 1);
    await _prefs.setInt(StorageKeys.statsSwipes, current.totalSwipes + additionalSwipes);
    await _prefs.setInt(StorageKeys.statsDeleted, current.totalTrashed + additionalTrashed);
    await _prefs.setInt(StorageKeys.statsSaved, current.totalKept + additionalKept);
    await _prefs.setInt(StorageKeys.statsDuration, current.totalSessionSeconds + sessionSeconds);

    // Save session history
    final history = getSessionHistory();
    history.add(
      SessionHistory(
        timestamp: DateTime.now(),
        reviewedCount: additionalSwipes,
        trashedCount: additionalTrashed,
        keptCount: additionalKept,
        durationSeconds: sessionSeconds,
      ),
    );
    await saveSessionHistory(history);
  }

  List<SessionHistory> getSessionHistory() {
    final historyJson = _prefs.getString('session_history');
    if (historyJson == null) return [];
    try {
      final List decoded = json.decode(historyJson);
      return decoded.map((e) => SessionHistory.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSessionHistory(List<SessionHistory> history) async {
    final historyJson = json.encode(history.map((e) => e.toJson()).toList());
    await _prefs.setString('session_history', historyJson);
  }

  // --- Email Cache ---
  List<Email> getCachedEmails() {
    final cachedStr = _prefs.getString(StorageKeys.cachedEmails);
    if (cachedStr == null) return [];
    try {
      final List decoded = json.decode(cachedStr);
      return decoded.map((e) => Email.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheEmails(List<Email> emails) async {
    final encoded = json.encode(emails.map((e) => e.toJson()).toList());
    await _prefs.setString(StorageKeys.cachedEmails, encoded);
  }

  Future<void> clearCachedEmails() async {
    await _prefs.remove(StorageKeys.cachedEmails);
  }

  // --- Kept Email IDs Cache ---
  List<String> getKeptEmailIds() {
    return _prefs.getStringList('kept_email_ids') ?? [];
  }

  Future<void> addKeptEmailIds(List<String> ids) async {
    final current = getKeptEmailIds();
    final updated = {...current, ...ids}.toList();
    await _prefs.setStringList('kept_email_ids', updated);
  }

  Future<void> removeKeptEmailIds(List<String> ids) async {
    final current = getKeptEmailIds();
    final updated = current.where((id) => !ids.contains(id)).toList();
    await _prefs.setStringList('kept_email_ids', updated);
  }

  Future<void> clearKeptEmailIds() async {
    await _prefs.remove('kept_email_ids');
  }

  // --- Clear All Data (Reset App) ---
  Future<void> clearAllData() async {
    await clearTokens();
    await _prefs.remove(StorageKeys.onboardingCompleted);
    await _prefs.remove(StorageKeys.statsSessions);
    await _prefs.remove(StorageKeys.statsSwipes);
    await _prefs.remove(StorageKeys.statsDeleted);
    await _prefs.remove(StorageKeys.statsSaved);
    await _prefs.remove(StorageKeys.statsDuration);
    await _prefs.remove(StorageKeys.cachedEmails);
    await _prefs.remove('session_history');
    await clearKeptEmailIds();
  }
}
