enum AppEnvironment {
  development,
  staging,
  production,
}

class AppConfig {
  final AppEnvironment environment;
  final String environmentName;
  final String backendApiUrl;

  const AppConfig({
    required this.environment,
    required this.environmentName,
    required this.backendApiUrl,
  });

  static const AppConfig development = AppConfig(
    environment: AppEnvironment.development,
    environmentName: 'Development',
    backendApiUrl: String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'http://localhost:8080/',
    ),
  );

  static const AppConfig staging = AppConfig(
    environment: AppEnvironment.staging,
    environmentName: 'Staging',
    backendApiUrl: String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'https://api-staging.dodouniverse.com/',
    ),
  );

  static const AppConfig production = AppConfig(
    environment: AppEnvironment.production,
    environmentName: 'Production',
    backendApiUrl: String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'https://api.dodouniverse.com/',
    ),
  );

  static AppConfig current() {
    const envString = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
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

