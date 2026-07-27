class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory AppConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

    if (url.isEmpty || publishableKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY must be provided '
        'with --dart-define.',
      );
    }

    return const AppConfig(
      supabaseUrl: url,
      supabasePublishableKey: publishableKey,
    );
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
}
