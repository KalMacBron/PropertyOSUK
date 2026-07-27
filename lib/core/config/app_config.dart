class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_ANON_KEY must be provided with --dart-define.',
      );
    }

    return const AppConfig(supabaseUrl: url, supabaseAnonKey: anonKey);
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
}
