import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers.dart';
import '../authentication/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        // Ignore failure or log it
      }
    } catch (_) {
      // Ignore failure
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider);
    final authNotifier = ref.read(authProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),
          // General Header
          _buildSectionHeader(context, 'Preferences'),

          // Dark Mode Toggle
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: Theme.of(context).colorScheme.primary),
            title: const Text('Theme Mode'),
            subtitle: Text(isDark ? 'Dark Theme' : 'Light Theme'),
            trailing: Switch(
              value: isDark,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (_) {
                ref.read(themeProvider.notifier).toggleTheme();
              },
            ),
          ),

          const Divider(color: Color(0xFF2C274C)),
          _buildSectionHeader(context, 'Data Management'),

          // Clear cache
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.amber),
            title: const Text('Clear Local Cache'),
            subtitle: const Text('Resets local dashboard statistics and temporary email queues.'),
            onTap: () => _confirmReset(context, ref),
          ),

          const Divider(color: Color(0xFF2C274C)),
          _buildSectionHeader(context, 'Legal & About'),

          // Privacy Policy
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _launchUrl('https://swipemail.app/privacy'),
          ),

          // Terms
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            onTap: () => _launchUrl('https://swipemail.app/terms'),
          ),

          // Support
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () => _launchUrl('mailto:support@swipemail.app?subject=SwipeMail%20Support'),
          ),

          // About Application
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'SwipeMail',
            applicationVersion: '1.0.0',
            applicationLegalese: '© 2026 SwipeMail Team. Privacy-focused Gmail cleanup.',
          ),

          const Divider(color: Color(0xFF2C274C)),
          const SizedBox(height: 24),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD63031),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _confirmLogout(context, authNotifier),
              icon: const Icon(Icons.logout),
              label: const Text('Disconnect Gmail Account'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Data?'),
        content: const Text('This will reset your local statistics and cleaning history. This action does NOT delete any emails from your Gmail account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () async {
              final storage = ref.read(storageServiceProvider);
              await storage.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local statistics cache cleared successfully.')),
              );
            },
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AuthNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Gmail?'),
        content: const Text('Are you sure you want to log out and disconnect your Gmail account? All local cleanup sessions will be completed and secure tokens cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD63031), foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Exit settings
              await notifier.logout(); // Triggers logout and forces app to re-evaluate auth status, returning to onboarding
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
