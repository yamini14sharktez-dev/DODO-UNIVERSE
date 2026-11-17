enum AppEnvironment {
  development,
  staging,
  production,
}

class AppConfig {
  final AppEnvironment environment;
  final String environmentName;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String apiBaseUrl;
  final bool useGoBackend;

  /// Backwards-compatible alias for publishable key
  String get supabaseAnonKey => supabasePublishableKey;

  const AppConfig({
    required this.environment,
    required this.environmentName,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    this.apiBaseUrl = 'http://localhost:8080',
    this.useGoBackend = true,
  });

  static const AppConfig development = AppConfig(
    environment: AppEnvironment.development,
    environmentName: 'Development',
    supabaseUrl: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://swivkawtnqymvymjxlpl.supabase.co',
    ),
    supabasePublishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue:
          String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    ),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080',
    ),
    useGoBackend: bool.fromEnvironment('USE_GO_BACKEND', defaultValue: true),
  );

  static const AppConfig staging = AppConfig(
    environment: AppEnvironment.staging,
    environmentName: 'Staging',
    supabaseUrl: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://swivkawtnqymvymjxlpl.supabase.co',
    ),
    supabasePublishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue:
          String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    ),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api-staging.dodouniverse.com',
    ),
    useGoBackend: bool.fromEnvironment('USE_GO_BACKEND', defaultValue: true),
  );

  static const AppConfig production = AppConfig(
    environment: AppEnvironment.production,
    environmentName: 'Production',
    supabaseUrl: String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://swivkawtnqymvymjxlpl.supabase.co',
    ),
    supabasePublishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
      defaultValue:
          String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: ''),
    ),
    apiBaseUrl: String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://api.dodouniverse.com',
    ),
    useGoBackend: bool.fromEnvironment('USE_GO_BACKEND', defaultValue: true),
  );

  static AppConfig current() {
    const envString =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    switch (envString.toLowerCase()) {
      case 'production':
      case 'prod':
        return production;
      case 'staging':
      case 'stage':
        return staging;
      case 'development':
      case 'dev':
      default:
        return development;
    }
  }
}
