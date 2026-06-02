import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxima/core/config/app_config.dart';

/// Stockage des tokens via SharedPreferences.
/// Note : pour la production mobile, remplacer par flutter_secure_storage.
class TokenStorage {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    final p = await _store;
    await Future.wait([
      p.setString(AppConfig.kAccessToken, accessToken),
      p.setString(AppConfig.kRefreshToken, refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() async {
    final p = await _store;
    return p.getString(AppConfig.kAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final p = await _store;
    return p.getString(AppConfig.kRefreshToken);
  }

  static Future<void> saveTenantInfo({
    required String tenantId,
    required String slug,
    required String name,
  }) async {
    final p = await _store;
    await Future.wait([
      p.setString(AppConfig.kTenantId, tenantId),
      p.setString(AppConfig.kTenantSlug, slug),
      p.setString(AppConfig.kTenantName, name),
    ]);
  }

  static Future<String?> getTenantId() async {
    final p = await _store;
    return p.getString(AppConfig.kTenantId);
  }

  static Future<void> saveUserInfo({
    required String userId,
    required String email,
    required String role,
  }) async {
    final p = await _store;
    await Future.wait([
      p.setString(AppConfig.kUserId, userId),
      p.setString(AppConfig.kUserEmail, email),
      p.setString(AppConfig.kUserRole, role),
    ]);
  }

  static Future<Map<String, String?>> getUserInfo() async {
    final p = await _store;
    return {
      'userId': p.getString(AppConfig.kUserId),
      'email': p.getString(AppConfig.kUserEmail),
      'role': p.getString(AppConfig.kUserRole),
      'tenantId': p.getString(AppConfig.kTenantId),
      'tenantName': p.getString(AppConfig.kTenantName),
    };
  }

  static Future<void> clearAll() async {
    final p = await _store;
    await p.clear();
  }

  static Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
