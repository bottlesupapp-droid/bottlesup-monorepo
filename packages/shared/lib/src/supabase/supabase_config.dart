import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase config for all Bottles Up apps.
///
/// Both apps point to the same Supabase project.
///
/// Initialization:
/// - Vendor app calls [SupabaseConfig.initialize] directly (hardcoded creds).
/// - User app initializes Supabase itself in main.dart via --dart-define,
///   then uses [SupabaseConfig.client] / [SupabaseConfig.auth] to access the instance.
class SupabaseConfig {
  static const String url = 'https://hwmynlghrmtoufyrcihp.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh3bXlubGdocm10b3VmeXJjaWhwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE2Mzc3ODAsImV4cCI6MjA2NzIxMzc4MH0.1VpevdV-ReX7w3QCoM0xaPjSywusUtrbrtFk9AsWNAw';

  /// Used by the vendor app to initialize Supabase.
  /// The user app initializes Supabase in its own main.dart using --dart-define.
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  /// Access the Supabase client after initialization (works for both apps).
  static SupabaseClient get client => Supabase.instance.client;

  /// Access the auth client after initialization (works for both apps).
  static GoTrueClient get auth => Supabase.instance.client.auth;
}
