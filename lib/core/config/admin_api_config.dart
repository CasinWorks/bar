class AdminApiConfig {
  static const url = String.fromEnvironment(
    'ADMIN_API_URL',
    defaultValue: 'https://blind-tiger-admin.vercel.app',
  );

  static bool get isConfigured => url.isNotEmpty;
}
