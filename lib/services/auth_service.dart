import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../core/constants.dart';
import 'storage_service.dart';

class AuthService {
  final StorageService _storageService;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: OAuthConstants.scopes,
  );

  AuthService(this._storageService);

  /// Exposes the current signed in Google account.
  GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

  /// Checks if the user is already authenticated and restores the session.
  /// Uses native silent sign-in.
  Future<bool> tryRestoreSession() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        final auth = await account.authentication;
        if (auth.accessToken != null) {
          // Cache access token locally in StorageService
          await _storageService.saveTokens(
            accessToken: auth.accessToken!,
            expiry: DateTime.now().add(const Duration(hours: 1)),
          );
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Initiates the native Google Sign-In flow.
  /// Returns the access token if successful.
  Future<String> signInWithGmail() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('Sign in canceled by user');
      }
      
      final auth = await account.authentication;
      final token = auth.accessToken;
      if (token == null) {
        throw Exception('Failed to retrieve access token');
      }

      await _storageService.saveTokens(
        accessToken: token,
        expiry: DateTime.now().add(const Duration(hours: 1)),
      );

      return token;
    } catch (e) {
      throw Exception('Google Sign-In failed: $e');
    }
  }

  /// Dynamically retrieves the current access token.
  Future<String?> getAccessToken() async {
    final account = _googleSignIn.currentUser;
    if (account != null) {
      final auth = await account.authentication;
      return auth.accessToken;
    }
    return await _storageService.getAccessToken();
  }

  /// Retrieves the authenticated headers from the native Google Sign-In instance.
  /// This automatically handles token refreshes transparently.
  Future<Map<String, String>> getAuthHeaders() async {
    final account = _googleSignIn.currentUser;
    if (account == null) {
      // Fallback to cached token in secure storage if native instance is not active
      final cachedToken = await _storageService.getAccessToken();
      if (cachedToken != null) {
        return {'Authorization': 'Bearer $cachedToken'};
      }
      throw Exception('User is not signed in');
    }
    return await account.authHeaders;
  }

  /// Logs out the user natively and clears storage credentials.
  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _storageService.clearTokens();
  }
}
