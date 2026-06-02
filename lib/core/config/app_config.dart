import 'package:flutter/foundation.dart';

class AppConfig {
  static const String appName = 'PROXIMA';
  static const String appVersion = '1.0.0';

  // URL de l'API backend — configurable via dart-define ou auto-détectée
  // Production web (Docker): flutter build web --dart-define=API_BASE_URL=http://myhost/api
  // Dev local: http://localhost:3000 (accès direct, pas via nginx)
  // Android émulateur: http://10.0.2.2:3000
  static const String _envBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:3000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Clés de stockage sécurisé
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kTenantId = 'tenant_id';
  static const String kTenantSlug = 'tenant_slug';
  static const String kTenantName = 'tenant_name';
  static const String kUserId = 'user_id';
  static const String kUserEmail = 'user_email';
  static const String kUserRole = 'user_role';
}
