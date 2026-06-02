import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _sessionsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getSessions();
});

// ── Screen principale ─────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final padding = EdgeInsets.all(isDesktop ? 24.0 : 16.0);

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Paramètres', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Sécurité et gestion du compte', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 24),

          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(children: [
                  const _ChangePasswordCard(),
                  const SizedBox(height: 16),
                  const _MfaCard(),
                ])),
                const SizedBox(width: 16),
                Expanded(child: const _SessionsCard()),
              ],
            )
          else ...[
            const _ChangePasswordCard(),
            const SizedBox(height: 16),
            const _MfaCard(),
            const SizedBox(height: 16),
            const _SessionsCard(),
          ],
        ],
      ),
    );
  }
}

// ── Carte changer mot de passe ────────────────────────────────────────────────

class _ChangePasswordCard extends ConsumerStatefulWidget {
  const _ChangePasswordCard();

  @override
  ConsumerState<_ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<_ChangePasswordCard> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _currentCtrl.text;
    final next = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || next.isEmpty) return;
    if (next != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas.');
      return;
    }
    setState(() { _loading = true; _error = null; _success = false; });

    try {
      final api = ref.read(apiClientProvider);
      await api.changePassword(current, next);
      setState(() => _success = true);
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.lock_outlined, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Changer le mot de passe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 20),

            TextFormField(
              controller: _currentCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Mot de passe actuel', prefixIcon: Icon(Icons.lock_outline, size: 18)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: const Icon(Icons.lock_reset_outlined, size: 18),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirmer le nouveau mot de passe', prefixIcon: Icon(Icons.lock_reset_outlined, size: 18)),
              onFieldSubmitted: (_) => _submit(),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              _StatusBanner(message: _error!, isError: true),
            ],
            if (_success) ...[
              const SizedBox(height: 12),
              const _StatusBanner(message: 'Mot de passe modifié. Reconnectez-vous depuis vos autres appareils.', isError: false),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Carte MFA ─────────────────────────────────────────────────────────────────

class _MfaCard extends ConsumerStatefulWidget {
  const _MfaCard();

  @override
  ConsumerState<_MfaCard> createState() => _MfaCardState();
}

class _MfaCardState extends ConsumerState<_MfaCard> {
  // null = inconnu, false = désactivé, true = activé
  bool? _mfaEnabled;
  String? _setupSecret;
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final api = ref.read(apiClientProvider);
      final profile = await api.dio.get('/auth/me');
      final data = profile.data as Map<String, dynamic>;
      if (mounted) setState(() => _mfaEnabled = data['mfaEnabled'] as bool? ?? false);
    } catch (_) {}
  }

  Future<void> _startSetup() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.setupMfa();
      setState(() {
        _setupSecret = data['secret'] as String?;
      });
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _confirmEnable() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      await api.verifyMfa(code);
      setState(() { _mfaEnabled = true; _setupSecret = null; _success = 'MFA activé avec succès.'; });
      _codeCtrl.clear();
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _disable() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      await api.disableMfa(code);
      setState(() { _mfaEnabled = false; _success = 'MFA désactivé.'; });
      _codeCtrl.clear();
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (_mfaEnabled == true ? AppColors.positive : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.shield_outlined, color: _mfaEnabled == true ? AppColors.positive : Colors.grey, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Authentification à deux facteurs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  if (_mfaEnabled != null)
                    Text(_mfaEnabled! ? 'Activée' : 'Désactivée',
                      style: TextStyle(fontSize: 12, color: _mfaEnabled! ? AppColors.positive : Colors.grey[600]),
                    ),
                ],
              )),
            ]),
            const SizedBox(height: 16),

            if (_mfaEnabled == null)
              const Center(child: CircularProgressIndicator())

            // MFA désactivé → proposer activation
            else if (!_mfaEnabled!) ...[
              Text('Protégez votre compte avec un code TOTP (Google Authenticator, Authy…)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 12),

              if (_setupSecret == null)
                SizedBox(
                  width: double.infinity, height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _startSetup,
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('Activer le MFA'),
                  ),
                )
              else ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('1. Scannez ce secret dans votre app :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      SelectableText(_setupSecret ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 13, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
                  decoration: const InputDecoration(counterText: '', labelText: '2. Entrez le code TOTP pour confirmer', hintText: '000000'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _confirmEnable,
                    child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirmer et activer'),
                  ),
                ),
              ],
            ]

            // MFA activé → proposer désactivation
            else ...[
              Text('Le MFA est actif sur votre compte. Entrez un code TOTP pour le désactiver.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
                decoration: const InputDecoration(counterText: '', labelText: 'Code TOTP', hintText: '000000'),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton(
                  onPressed: _loading ? null : _disable,
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.negative, side: const BorderSide(color: AppColors.negative)),
                  child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.negative)) : const Text('Désactiver le MFA'),
                ),
              ),
            ],

            if (_error != null) ...[const SizedBox(height: 10), _StatusBanner(message: _error!, isError: true)],
            if (_success != null) ...[const SizedBox(height: 10), _StatusBanner(message: _success!, isError: false)],
          ],
        ),
      ),
    );
  }
}

// ── Carte sessions actives ────────────────────────────────────────────────────

class _SessionsCard extends ConsumerWidget {
  const _SessionsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(_sessionsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.devices_outlined, color: AppColors.warning, size: 18),
              ),
              const SizedBox(width: 12),
              const Text('Sessions actives', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Actualiser',
                onPressed: () => ref.invalidate(_sessionsProvider),
              ),
            ]),
            const SizedBox(height: 4),
            Text('Appareils connectés à votre compte', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 16),

            sessionsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
              error: (e, _) => _StatusBanner(message: parseError(e), isError: true),
              data: (sessions) => sessions.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Aucune session active', style: TextStyle(color: Colors.grey[400])),
                    ))
                  : Column(
                      children: sessions.map((s) => _SessionTile(
                        session: s as Map<String, dynamic>,
                        onRevoke: () async {
                          try {
                            await ref.read(apiClientProvider).revokeSession(s['jti'] as String);
                            ref.invalidate(_sessionsProvider);
                          } catch (_) {}
                        },
                      )).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onRevoke;

  const _SessionTile({required this.session, required this.onRevoke});

  @override
  Widget build(BuildContext context) {
    final isCurrent = session['isCurrent'] as bool? ?? false;
    final ip = session['ip'] as String? ?? '—';
    final ua = session['userAgent'] as String? ?? '—';
    final createdAt = session['createdAt'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.primary.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isCurrent ? AppColors.primary.withValues(alpha: 0.2) : const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Icon(
            ua.toLowerCase().contains('mobile') ? Icons.smartphone_outlined : Icons.computer_outlined,
            size: 20, color: isCurrent ? AppColors.primary : Colors.grey[600],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(ip, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: const Text('Session actuelle', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                ]),
                if (createdAt != null)
                  Text(_formatDate(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
          ),
          if (!isCurrent)
            IconButton(
              icon: const Icon(Icons.logout, size: 18, color: AppColors.negative),
              tooltip: 'Révoquer',
              onPressed: onRevoke,
            ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Widget utilitaire ─────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String message;
  final bool isError;
  const _StatusBanner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
