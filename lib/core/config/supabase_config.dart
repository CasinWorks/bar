import 'supabase_secrets.dart';

class SupabaseConfig {
  static String get url => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: SupabaseSecrets.url,
  );

  static String get anonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: SupabaseSecrets.anonKey,
  );

  static bool get isConfigured =>
      url.isNotEmpty && anonKey.isNotEmpty && !url.contains('YOUR_');
}
