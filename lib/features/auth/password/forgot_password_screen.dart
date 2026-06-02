import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/router/app_router.dart';
import 'package:proxima/core/theme/app_theme.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _usernameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  // En dev, le backend retourne le token directement
  String? _devToken;
  bool _sent = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim().toUpperCase();
    if (username.isEmpty) return;
    setState(() { _loading = true; _error = null; });

    try {
      final api = ref.read(apiClientProvider);
      final data = await api.forgotPassword(username);
      final devToken = data['resetToken'] as String?;
      setState(() {
        _sent = true;
        _devToken = devToken;
      });
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 440 : double.infinity),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.lock_reset_outlined, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('Mot de passe oublié', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary)),
                const SizedBox(height: 40),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: _sent ? _SuccessView(devToken: _devToken, onReset: () => context.go(AppRoutes.resetPassword)) : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Réinitialiser', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text('Entrez votre nom d\'utilisateur pour recevoir un lien de réinitialisation.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        const SizedBox(height: 24),

                        TextFormField(
                          controller: _usernameCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Nom d\'utilisateur',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'Ex: 0123456789A-ADMIN',
                          ),
                          onFieldSubmitted: (_) => _submit(),
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.negative.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.negative, size: 16),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 13))),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Envoyer le lien'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text('Retour à la connexion'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String? devToken;
  final VoidCallback onReset;
  const _SuccessView({required this.devToken, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 56, color: AppColors.positive),
        const SizedBox(height: 16),
        const Text('Demande envoyée', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        const SizedBox(height: 8),
        Text('En production, un email est envoyé. En mode dev, utilisez le token ci-dessous.', style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
        if (devToken != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: SelectableText(devToken!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: onReset,
              icon: const Icon(Icons.lock_reset_outlined, size: 18),
              label: const Text('Utiliser ce token'),
            ),
          ),
        ],
      ],
    );
  }
}
