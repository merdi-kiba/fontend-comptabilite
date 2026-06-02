import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _pendingCountProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfPendingCount();
});

class EmcfConfigTab extends ConsumerStatefulWidget {
  const EmcfConfigTab({super.key});

  @override
  ConsumerState<EmcfConfigTab> createState() => _EmcfConfigTabState();
}

class _EmcfConfigTabState extends ConsumerState<EmcfConfigTab> {
  final _tokenCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() { _tokenCtrl.dispose(); super.dispose(); }

  Future<void> _saveToken() async {
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) return;
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await ref.read(apiClientProvider).setEmcfToken(token);
      setState(() => _success = 'Token DGI enregistré et chiffré avec succès.');
      _tokenCtrl.clear();
      ref.invalidate(_pendingCountProvider);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(_pendingCountProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut pending
          pendingAsync.when(
            loading: () => const SizedBox(),
            error: (e, _) => const SizedBox(),
            data: (data) {
              final count = data['pendingCount'] as num? ?? 0;
              final max = data['max'] as num? ?? 10;
              final pct = max > 0 ? (count / max).clamp(0.0, 1.0) : 0.0;
              final color = count >= max ? AppColors.negative : count > max * 0.7 ? AppColors.warning : AppColors.positive;
              return Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.pending_actions_outlined, color: color, size: 20),
                      const SizedBox(width: 8),
                      Text('Factures en attente DGI : $count / $max',
                        style: TextStyle(fontWeight: FontWeight.w700, color: color)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct.toDouble(), minHeight: 6,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    if (count >= max) ...[
                      const SizedBox(height: 6),
                      Text('Limite DGI atteinte — les nouvelles soumissions sont bloquées.',
                        style: TextStyle(fontSize: 12, color: color)),
                    ],
                  ],
                ),
              );
            },
          ),

          // Token DGI
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.vpn_key_outlined, color: AppColors.primary, size: 18)),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Token DGI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('Chiffré AES-256-GCM avec clé HKDF dérivée du tenantId', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                  ]),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _tokenCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Token DGI brut',
                      hintText: 'Collez le token fourni par la DGI-RDC',
                      prefixIcon: const Icon(Icons.lock_outlined, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    maxLines: _obscure ? 1 : 3,
                  ),

                  if (_error != null) ...[const SizedBox(height: 10), _Banner(_error!, true)],
                  if (_success != null) ...[const SizedBox(height: 10), _Banner(_success!, false)],

                  const SizedBox(height: 16),
                  SizedBox(width: double.infinity, height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _loading ? null : _saveToken,
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined, size: 18),
                      label: const Text('Enregistrer le token'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Guide codes erreur
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.help_outline, color: AppColors.warning, size: 18)),
                    const SizedBox(width: 12),
                    const Text('Codes d\'erreur DGI fréquents', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  ]),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  ..._errorCodes.map((e) => _ErrorCodeRow(e[0], e[1], e[2])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _errorCodes = [
  ['1001', 'Token expiré', 'Renouveler via ce formulaire'],
  ['1002', 'NIF non enregistré', 'Vérifier le NIF du profil tenant'],
  ['1003', 'EDEF non trouvé', 'Créer/activer l\'EDEF dans l\'onglet EDEFs'],
  ['2001', 'Facture déjà soumise', 'Utiliser le uid existant (idempotence)'],
  ['3001', 'Montant invalide', 'Vérifier les calculs TVA'],
  ['4001', 'NIF client invalide', 'Mettre à jour le NIF du tiers'],
];

class _ErrorCodeRow extends StatelessWidget {
  final String code;
  final String label;
  final String action;
  const _ErrorCodeRow(this.code, this.label, this.action);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
            child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.negative, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text(action, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String msg;
  final bool isError;
  const _Banner(this.msg, this.isError);

  @override
  Widget build(BuildContext context) {
    final c = isError ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: c, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: c, fontSize: 12))),
      ]),
    );
  }
}
