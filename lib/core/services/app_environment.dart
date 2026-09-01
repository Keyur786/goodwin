enum AppEnvironment { development, staging, production }

class AppEnvironmentConfig {
  AppEnvironmentConfig({
    required this.environment,
    required this.useFirebase,
    required this.useDemoData,
  });

  final AppEnvironment environment;
  final bool useFirebase;
  final bool useDemoData;

  static AppEnvironmentConfig fromPlatform() {
    const useFirebase = bool.fromEnvironment('USE_FIREBASE', defaultValue: false);
    const useDemoData = bool.fromEnvironment('USE_DEMO_DATA', defaultValue: true);
    const environmentName = String.fromEnvironment('APP_ENV', defaultValue: 'development');

    final environment = switch (environmentName) {
      'production' => AppEnvironment.production,
      'staging' => AppEnvironment.staging,
      _ => AppEnvironment.development,
    };

    return AppEnvironmentConfig(
      environment: environment,
      useFirebase: useFirebase,
      useDemoData: useDemoData,
    );
  }
}
