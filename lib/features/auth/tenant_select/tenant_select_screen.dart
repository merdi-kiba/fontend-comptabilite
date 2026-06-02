import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/router/app_router.dart';
import 'package:proxima/core/theme/app_theme.dart';

// Provider adaptatif : SUPERADMIN → GET /tenants, autres → GET /tenants/my-tenants
final _tenantsProvider = FutureProvider.family<List<Map<String, dynamic>>, bool>((ref, isSuperAdmin) async {
  final api = ref.watch(apiClientProvider);
  final List<dynamic> list;
  if (isSuperAdmin) {
    list = await api.getAllTenants();
  } else {
    list = await api.getMyTenants();
  }
  return list.cast<Map<String, dynamic>>();
});

class TenantSelectScreen extends ConsumerWidget {
  const TenantSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isSuperAdmin = auth.role == 'SUPERADMIN';
    final tenantsAsync = ref.watch(_tenantsProvider(isSuperAdmin));
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      floatingActionButton: isSuperAdmin
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Nouvelle société'),
              backgroundColor: AppColors.primary,
              onPressed: () => _showCreateTenantDialog(context, ref),
            )
          : null,
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 600 : double.infinity),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // En-tête
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_graph, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('PROXIMA', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.primary, letterSpacing: 1)),
                        Text('Connecté : ${auth.email ?? ''}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('Déconnexion'),
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Titre adaptatif
                Text(
                  isSuperAdmin ? 'Gestion des sociétés' : 'Sélectionner un dossier',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  isSuperAdmin
                      ? 'Sélectionnez une société pour y accéder, ou créez-en une nouvelle'
                      : 'Choisissez la société sur laquelle travailler',
                  style: TextStyle(color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Bannière Super Admin
                if (isSuperAdmin) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings_outlined, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Mode Super Admin — vous voyez toutes les sociétés',
                            style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Liste tenants
                tenantsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => _ErrorCard(message: parseError(e)),
                  data: (tenants) => tenants.isEmpty
                      ? _EmptyState(isSuperAdmin: isSuperAdmin, onCreateTap: () => _showCreateTenantDialog(context, ref))
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tenants.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _TenantCard(
                            tenant: tenants[i],
                            isActive: tenants[i]['id'] == auth.tenantId,
                            isSuperAdmin: isSuperAdmin,
                            onTap: () async {
                              await ref.read(authProvider.notifier).switchTenant(
                                tenants[i]['id'] as String,
                                tenants[i]['companyName'] as String,
                                tenants[i]['slug'] as String,
                              );
                              if (context.mounted) context.go(AppRoutes.dashboard);
                            },
                          ),
                        ),
                ),

                // Espace pour le FAB
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateTenantDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CreateTenantDialog(ref: ref),
    );
  }
}

// ─── Dialogue création de tenant ─────────────────────────────────────────────

class _CreateTenantDialog extends StatefulWidget {
  final WidgetRef ref;
  const _CreateTenantDialog({required this.ref});

  @override
  State<_CreateTenantDialog> createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<_CreateTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _slugController = TextEditingController();
  final _nifController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _adminPasswordController = TextEditingController();

  bool _loading = false;
  String? _error;
  String? _successId;

  // Génère un slug valide depuis le nom de la société
  String _toSlug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r"[àâä]"), 'a')
        .replaceAll(RegExp(r"[éèêë]"), 'e')
        .replaceAll(RegExp(r"[îï]"), 'i')
        .replaceAll(RegExp(r"[ôö]"), 'o')
        .replaceAll(RegExp(r"[ùûü]"), 'u')
        .replaceAll(RegExp(r"[^a-z0-9]+"), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  @override
  void initState() {
    super.initState();
    _companyNameController.addListener(() {
      final slug = _toSlug(_companyNameController.text);
      if (_slugController.text != slug) _slugController.text = slug;
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _slugController.dispose();
    _nifController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _adminPasswordController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final api = widget.ref.read(apiClientProvider);
      final body = <String, dynamic>{
        'companyName': _companyNameController.text.trim(),
        'slug': _slugController.text.trim(),
        'nif': _nifController.text.trim(),
        'adminPassword': _adminPasswordController.text,
      };
      final email = _emailController.text.trim();
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();
      if (email.isNotEmpty) body['email'] = email;
      if (phone.isNotEmpty) body['phone'] = phone;
      if (address.isNotEmpty) body['address'] = address;

      final result = await api.createTenant(body);
      setState(() { _loading = false; _successId = result['id'] as String?; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = parseError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_successId != null) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 64),
            const SizedBox(height: 16),
            const Text('Société créée !', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Le provisionnement de la base de données est en cours.\nVeuillez patienter quelques secondes puis rafraîchir la liste.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Invalider le cache pour rafraîchir la liste
              widget.ref.invalidate(_tenantsProvider);
            },
            child: const Text('OK — Rafraîchir la liste'),
          ),
        ],
      );
    }

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_business_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          const Text('Nouvelle société', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.negative.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 13)),
                ),
                const SizedBox(height: 12),
              ],
              _Field(controller: _companyNameController, label: 'Nom de la société *', hint: 'Ex: ACME SARL', validator: (v) => (v ?? '').isEmpty ? 'Champ obligatoire' : null),
              const SizedBox(height: 12),
              _Field(
                controller: _slugController,
                label: 'Slug (identifiant URL) *',
                hint: 'acme-sarl',
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Champ obligatoire';
                  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v!)) return 'Lettres minuscules, chiffres et tirets uniquement';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _Field(controller: _nifController, label: 'NIF (Numéro d\'Identification Fiscale) *', hint: 'Ex: A1234567890', validator: (v) => (v ?? '').isEmpty ? 'Champ obligatoire' : null),
              const SizedBox(height: 12),
              _Field(controller: _emailController, label: 'Email', hint: 'contact@entreprise.cd', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _Field(controller: _phoneController, label: 'Téléphone', hint: '+243 8XX XXX XXX', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _Field(controller: _addressController, label: 'Adresse', hint: 'Kinshasa, RDC'),
              const SizedBox(height: 12),
              _Field(
                controller: _adminPasswordController,
                label: 'Mot de passe admin *',
                hint: 'Min. 12 caractères',
                obscureText: true,
                validator: (v) {
                  if ((v ?? '').isEmpty) return 'Champ obligatoire';
                  if (v!.length < 12) return 'Minimum 12 caractères';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _loading ? null : _create,
          icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check, size: 18),
          label: Text(_loading ? 'Création...' : 'Créer'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool obscureText;

  const _Field({required this.controller, required this.label, required this.hint, this.keyboardType, this.validator, this.obscureText = false});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }
}

// ─── Carte tenant ──────────────────────────────────────────────────────────────

class _TenantCard extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final bool isActive;
  final bool isSuperAdmin;
  final VoidCallback onTap;

  const _TenantCard({required this.tenant, required this.isActive, required this.isSuperAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = tenant['status'] as String? ?? 'ACTIVE';
    final isProvisioning = status == 'PROVISIONING';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isActive ? AppColors.primary : const Color(0xFFE8ECF0),
          width: isActive ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: isProvisioning ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary : isProvisioning ? AppColors.warning.withValues(alpha: 0.1) : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isProvisioning ? Icons.hourglass_top : Icons.business,
                  color: isActive ? Colors.white : isProvisioning ? AppColors.warning : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tenant['companyName'] as String? ?? 'Société',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                        ),
                        if (isSuperAdmin) _StatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'NIF: ${tenant['nif'] ?? '—'}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    if (isProvisioning)
                      const Text('Provisionnement en cours...', style: TextStyle(fontSize: 11, color: AppColors.warning, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              if (isActive)
                const Icon(Icons.check_circle, color: AppColors.primary)
              else if (isProvisioning)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              else
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'ACTIVE' => (AppColors.positive, 'Actif'),
      'PROVISIONING' => (AppColors.warning, 'Création...'),
      'SUSPENDED' => (AppColors.negative, 'Suspendu'),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── État vide ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool isSuperAdmin;
  final VoidCallback onCreateTap;

  const _EmptyState({required this.isSuperAdmin, required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text('Aucun dossier assigné', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
        const SizedBox(height: 8),
        Text(
          isSuperAdmin
              ? 'Créez votre première société pour commencer'
              : 'Contactez votre administrateur',
          style: TextStyle(color: Colors.grey[400], fontSize: 13),
          textAlign: TextAlign.center,
        ),
        if (isSuperAdmin) ...[
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onCreateTap,
            icon: const Icon(Icons.add_business_outlined),
            label: const Text('Créer une société'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.negative.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.negative),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.negative))),
        ],
      ),
    );
  }
}
