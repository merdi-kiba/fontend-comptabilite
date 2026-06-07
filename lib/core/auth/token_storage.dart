import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:proxima/core/config/app_config.dart';

/// Stockage sécurisé des tokens JWT via flutter_secure_storage (Keychain/Keystore).
/// Les données non sensibles (userId, email, role, tenantName) restent dans SharedPreferences.
class TokenStorage {
  // ── Stockage sécurisé — tokens JWT sensibles ──────────────────────────────
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // ── SharedPreferences — données non sensibles ─────────────────────────────
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> get _store async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ── Tokens JWT ─────────────────────────────────────────────────────────────

  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      _secureStorage.write(key: AppConfig.kAccessToken, value: accessToken),
      _secureStorage.write(key: AppConfig.kRefreshToken, value: refreshToken),
    ]);
  }

  static Future<String?> getAccessToken() async {
    return _secureStorage.read(key: AppConfig.kAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    return _secureStorage.read(key: AppConfig.kRefreshToken);
  }

  // ── Tenant ─────────────────────────────────────────────────────────────────
  // tenantId est stocké de manière sécurisée car c'est un identifiant de session

  static Future<void> saveTenantInfo({
    required String tenantId,
    required String slug,
    required String name,
  }) async {
    final p = await _store;
    await Future.wait([
      _secureStorage.write(key: AppConfig.kTenantId, value: tenantId),
      p.setString(AppConfig.kTenantSlug, slug),
      p.setString(AppConfig.kTenantName, name),
    ]);
  }

  static Future<String?> getTenantId() async {
    return _secureStorage.read(key: AppConfig.kTenantId);
  }

  // ── User info (non sensible) ───────────────────────────────────────────────

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
    final tenantId = await getTenantId();
    return {
      'userId': p.getString(AppConfig.kUserId),
      'email': p.getString(AppConfig.kUserEmail),
      'role': p.getString(AppConfig.kUserRole),
      'tenantId': tenantId,
      'tenantName': p.getString(AppConfig.kTenantName),
    };
  }

  // ── Effacement complet ─────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final p = await _store;
    await Future.wait([
      _secureStorage.deleteAll(),
      p.clear(),
    ]);
  }

  // ── Validation de session ──────────────────────────────────────────────────

  /// Vérifie que le token JWT est présent ET non expiré (décode le payload base64url).
  static Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return false;
    try {
      // Décode le payload JWT (base64url, partie du milieu)
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded =
          jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      final exp = decoded['exp'] as int?;
      if (exp == null) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expiry);
    } catch (_) {
      return false;
    }
  }
}
