import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../services/gmail_service.dart';

/// Provider for SharedPreferences (initialized synchronously in main.dart)
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences has not been initialized');
});

/// Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return StorageService(prefs, secureStorage);
});

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthService(storage);
});

/// Provider for GmailService
final gmailServiceProvider = Provider<GmailService>((ref) {
  final auth = ref.watch(authServiceProvider);
  return GmailService(auth);
});

/// Provider to manage dark mode theme state
class ThemeNotifier extends Notifier<bool> {
  @override
  bool build() {
    final storage = ref.watch(storageServiceProvider);
    return storage.isDarkMode();
  }

  void toggleTheme() {
    state = !state;
    ref.read(storageServiceProvider).setDarkMode(state);
  }
}

final themeProvider = NotifierProvider<ThemeNotifier, bool>(ThemeNotifier.new);

class DashboardTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int index) {
    state = index;
  }
}

/// Provider to manage the active dashboard tab index (0 = Overview, 1 = Swipe, 2 = Bin, 3 = Settings)
final dashboardTabProvider = NotifierProvider<DashboardTabNotifier, int>(DashboardTabNotifier.new);


