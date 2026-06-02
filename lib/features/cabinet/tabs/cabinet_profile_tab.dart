import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _cabinetProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCabinetProfile();
});

class CabinetProfileTab extends ConsumerWidget {
  const CabinetProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_cabinetProfileProvider);

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.domain_disabled_outlined, size: 56, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Aucun cabinet enregistré', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Créez votre cabinet pour commencer.', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showRegisterDialog(context, ref),
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Enregistrer mon cabinet'),
            ),
          ],
        ),
      )),
      data: (profile) => _ProfileForm(
        profile: profile,
        onSaved: () => ref.invalidate(_cabinetProfileProvider),
      ),
    );
  }

  void _showRegisterDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _RegisterCabinetDialog(onCreated: () => ref.invalidate(_cabinetProfileProvider)),
    );
  }
}

// ── Formulaire profil ────────────────────────────────────────────────────────

class _ProfileForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onSaved;
  const _ProfileForm({required this.profile, required this.onSaved});

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _nifCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _nameCtrl    = TextEditingController(text: p['name'] as String? ?? '');
    _nifCtrl     = TextEditingController(text: p['nif'] as String? ?? '');
    _emailCtrl   = TextEditingController(text: p['email'] as String? ?? '');
    _phoneCtrl   = TextEditingController(text: p['phone'] as String? ?? '');
    _addressCtrl = TextEditingController(text: p['address'] as String? ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _nifCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await ref.read(apiClientProvider).updateCabinetProfile({
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_addressCtrl.text.isNotEmpty) 'address': _addressCtrl.text.trim(),
      });
      setState(() => _success = 'Profil du cabinet mis à jour.');
      widget.onSaved();
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.domain_outlined, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_nameCtrl.text.isEmpty ? 'Mon Cabinet' : _nameCtrl.text,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                    Text('NIF: ${_nifCtrl.text.isEmpty ? '—' : _nifCtrl.text}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Informations du cabinet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'Nom du cabinet', prefixIcon: Icon(Icons.business_outlined, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nifCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'NIF', prefixIcon: Icon(Icons.numbers_outlined, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Téléphone', prefixIcon: Icon(Icons.phone_outlined, size: 18)),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Adresse', prefixIcon: Icon(Icons.location_on_outlined, size: 18)),
                  ),
                ],
              ),
            ),
          ),

          if (_error != null) ...[const SizedBox(height: 12), _Banner(message: _error!, isError: true)],
          if (_success != null) ...[const SizedBox(height: 12), _Banner(message: _success!, isError: false)],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer les modifications'),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Dialog enregistrement cabinet ────────────────────────────────────────────

class _RegisterCabinetDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _RegisterCabinetDialog({required this.onCreated});

  @override
  ConsumerState<_RegisterCabinetDialog> createState() => _RegisterCabinetDialogState();
}

class _RegisterCabinetDialogState extends ConsumerState<_RegisterCabinetDialog> {
  final _nameCtrl    = TextEditingController();
  final _nifCtrl     = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _nifCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _nifCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).registerCabinet({
        'name': _nameCtrl.text.trim(),
        'nif': _nifCtrl.text.trim().toUpperCase(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enregistrer le cabinet', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du cabinet *')),
            const SizedBox(height: 12),
            TextFormField(controller: _nifCtrl, decoration: const InputDecoration(labelText: 'NIF *')),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Téléphone')),
            const SizedBox(height: 12),
            TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Adresse')),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Créer'),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
