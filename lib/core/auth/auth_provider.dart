import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/api/api_client.dart';
import 'package:proxima/core/auth/token_storage.dart';

// ── État d'authentification ────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated, mfaPending }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  final String? role;
  final String? tenantId;
  final String? tenantName;
  final String? error;
  // Données temporaires pour l'étape MFA
  // NOTE: le mot de passe en clair (mfaPendingPassword) a été supprimé pour raisons de sécurité.
  // Le backend doit retourner un `mfaSessionToken` lors du premier appel login (mfaRequired=true).
  // Si le backend ne retourne pas encore ce token, le flux MFA nécessite une adaptation backend
  // (voir CORRECTIONS.md — Actions manuelles requises).
  final String? mfaPendingEmail;
  final String? mfaSessionToken;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.email,
    this.role,
    this.tenantId,
    this.tenantName,
    this.error,
    this.mfaPendingEmail,
    this.mfaSessionToken,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get hasTenant => tenantId != null;
  bool get isMfaPending => status == AuthStatus.mfaPending;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? email,
    String? role,
    String? tenantId,
    String? tenantName,
    String? error,
    String? mfaPendingEmail,
    String? mfaSessionToken,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        email: email ?? this.email,
        role: role ?? this.role,
        tenantId: tenantId ?? this.tenantId,
        tenantName: tenantName ?? this.tenantName,
        error: error,
        mfaPendingEmail: mfaPendingEmail ?? this.mfaPendingEmail,
        mfaSessionToken: mfaSessionToken ?? this.mfaSessionToken,
      );
}

// ── Notifier ───────────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiClient _api;

  AuthNotifier(this._api) : super(const AuthState()) {
    _restore();
    // Auto-logout when the refresh token is expired or revoked.
    ApiClient.onSessionExpired = () {
      if (mounted) state = const AuthState(status: AuthStatus.unauthenticated);
    };
  }

  // Restaurer la session depuis le stockage sécurisé
  Future<void> _restore() async {
    final hasSession = await TokenStorage.hasValidSession();
    if (!hasSession) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    final info = await TokenStorage.getUserInfo();
    state = AuthState(
      status: AuthStatus.authenticated,
      userId: info['userId'],
      email: info['email'],
      role: info['role'],
      tenantId: info['tenantId'],
      tenantName: info['tenantName'],
    );
  }

  // Connexion username/password
  Future<bool> login(String username, String password) async {
    try {
      final data = await _api.login(username, password);

      // MFA requis → conserver uniquement l'email et le mfaSessionToken retourné par le backend
      // Le mot de passe n'est JAMAIS conservé dans le state pour des raisons de sécurité.
      if (data['mfaRequired'] == true) {
        final mfaSessionToken = data['mfaSessionToken'] as String?;
        state = AuthState(
          status: AuthStatus.mfaPending,
          mfaPendingEmail: username,
          // Si le backend ne retourne pas encore mfaSessionToken, ce champ sera null.
          // Voir CORRECTIONS.md pour l'adaptation backend requise.
          mfaSessionToken: mfaSessionToken,
        );
        return false;
      }

      await _applyTokens(data);
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _extractError(e),
      );
      return false;
    }
  }

  // Deuxième étape login avec code TOTP
  // Utilise le mfaSessionToken retourné par le backend à l'étape 1.
  Future<bool> loginWithMfa(String code) async {
    final sessionToken = state.mfaSessionToken;
    final email = state.mfaPendingEmail;
    if (email == null) return false;
    try {
      final data = await _api.loginWithMfaToken(
        mfaSessionToken: sessionToken,
        mfaCode: code,
      );
      await _applyTokens(data);
      return true;
    } catch (e) {
      state = state.copyWith(error: _extractError(e));
      return false;
    }
  }

  Future<void> _applyTokens(Map<String, dynamic> data) async {
    final accessToken = data['accessToken'] as String;
    final refreshToken = data['refreshToken'] as String;
    final user = data['user'] as Map<String, dynamic>;

    final roles = (user['roles'] as List<dynamic>?) ?? [];
    final primaryRole = roles.isNotEmpty ? roles.first as String : 'UNKNOWN';
    final uname = user['username'] as String;
    final userTenantId = user['tenantId'] as String?;
    final tenant = user['tenant'] as Map<String, dynamic>?;

    await TokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await TokenStorage.saveUserInfo(userId: user['id'] as String, email: uname, role: primaryRole);

    if (userTenantId != null) {
      await TokenStorage.saveTenantInfo(
        tenantId: userTenantId,
        slug: '',
        name: tenant?['companyName'] as String? ?? '',
      );
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: user['id'] as String,
        email: uname,
        role: primaryRole,
        tenantId: userTenantId,
        tenantName: tenant?['companyName'] as String?,
      );
    } else {
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: user['id'] as String,
        email: uname,
        role: primaryRole,
      );
    }
  }

  // Changer de tenant (cabinet multi-clients)
  Future<void> switchTenant(String tenantId, String tenantName, String slug) async {
    try {
      final isSuperAdmin = state.role == 'SUPERADMIN';
      final data = await _api.switchTenant(tenantId, asSuperAdmin: isSuperAdmin);
      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess != null) {
        await TokenStorage.saveTokens(
          accessToken: newAccess,
          refreshToken: newRefresh ?? '',
        );
      }
      await TokenStorage.saveTenantInfo(
        tenantId: tenantId,
        slug: slug,
        name: tenantName,
      );
      state = state.copyWith(tenantId: tenantId, tenantName: tenantName);
    } catch (e) {
      state = state.copyWith(error: _extractError(e));
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await TokenStorage.clearAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _extractError(Object e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return e.toString();
  }
}

// ── Providers ──────────────────────────────────────────────────────────────────

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  client.init();
  return client;
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(apiClientProvider));
});
