import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _edefsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEdefs();
});

class EmcfEdefsTab extends ConsumerWidget {
  const EmcfEdefsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final edefsAsync = ref.watch(_edefsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEdefDialog(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel EDEF'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_edefsProvider.future),
        child: Column(
          children: [
            // Bouton sync DGI
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text('Opérateurs DGI (EDEF)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ref.read(apiClientProvider).syncEdefsFromDgi();
                        ref.invalidate(_edefsProvider);
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('EDEFs synchronisés depuis la DGI')));
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
                      }
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sync DGI'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: edefsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
                data: (edefs) => edefs.isEmpty
                    ? _EmptyEdefs(onAdd: () => _showEdefDialog(context, ref, null))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                        itemCount: edefs.length,
                        separatorBuilder: (context, i) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => _EdefCard(
                          edef: edefs[i] as Map<String, dynamic>,
                          onEdit: () => _showEdefDialog(context, ref, edefs[i] as Map<String, dynamic>),
                          onDelete: () async {
                            final id = (edefs[i] as Map<String, dynamic>)['id'] as String;
                            await ref.read(apiClientProvider).deleteEdef(id);
                            ref.invalidate(_edefsProvider);
                          },
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEdefDialog(BuildContext context, WidgetRef ref, Map<String, dynamic>? existing) {
    showDialog(
      context: context,
      builder: (_) => _EdefDialog(
        existing: existing,
        onSaved: () => ref.invalidate(_edefsProvider),
      ),
    );
  }
}

class _EdefCard extends StatelessWidget {
  final Map<String, dynamic> edef;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _EdefCard({required this.edef, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final edefId = edef['edefId'] as String? ?? '—';
    final name = edef['edefName'] as String? ?? '—';
    final active = edef['isActive'] as bool? ?? true;

    return Card(
      child: ListTile(
        leading: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: (active ? AppColors.positive : Colors.grey).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.badge_outlined, color: active ? AppColors.positive : Colors.grey, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text('ID: $edefId', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (active ? AppColors.positive : Colors.grey).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(active ? 'Actif' : 'Inactif',
                style: TextStyle(fontSize: 11, color: active ? AppColors.positive : Colors.grey, fontWeight: FontWeight.w600)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppColors.negative))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EdefDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _EdefDialog({required this.existing, required this.onSaved});

  @override
  ConsumerState<_EdefDialog> createState() => _EdefDialogState();
}

class _EdefDialogState extends ConsumerState<_EdefDialog> {
  late final TextEditingController _idCtrl;
  late final TextEditingController _nameCtrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idCtrl = TextEditingController(text: widget.existing?['edefId'] as String? ?? '');
    _nameCtrl = TextEditingController(text: widget.existing?['edefName'] as String? ?? '');
  }

  @override
  void dispose() { _idCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_idCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      if (widget.existing != null) {
        await api.updateEdef(widget.existing!['id'] as String, {'edefName': _nameCtrl.text.trim()});
      } else {
        await api.createEdef({'edefId': _idCtrl.text.trim().toUpperCase(), 'edefName': _nameCtrl.text.trim()});
      }
      widget.onSaved();
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
      title: Text(widget.existing == null ? 'Créer un EDEF' : 'Modifier l\'EDEF', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _idCtrl, readOnly: widget.existing != null,
              decoration: const InputDecoration(labelText: 'ID EDEF (ex: EDEF-001)')),
            const SizedBox(height: 12),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom de l\'opérateur')),
            if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

class _EmptyEdefs extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyEdefs({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.badge_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucun opérateur EDEF', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer un EDEF')),
        ],
      ),
    );
  }
}
