import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _workflowsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getApprovalWorkflows();
});

class WorkflowsTab extends ConsumerWidget {
  const WorkflowsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workflows = ref.watch(_workflowsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau workflow'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_workflowsProvider.future),
        child: workflows.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Aucun workflow configuré', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Créez des workflows pour exiger des approbations sur les BCs, notes de frais, etc.',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () => _showCreate(context, ref), icon: const Icon(Icons.add), label: const Text('Créer un workflow')),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _WorkflowCard(
                    workflow: list[i] as Map<String, dynamic>,
                    onToggle: () async {
                      final wf = list[i] as Map<String, dynamic>;
                      final current = wf['isActive'] as bool? ?? true;
                      try {
                        await ref.read(apiClientProvider).updateApprovalWorkflow(wf['id'] as String, {'isActive': !current});
                        ref.invalidate(_workflowsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
                        }
                      }
                    },
                    onEdit: () => _showEdit(context, ref, list[i] as Map<String, dynamic>),
                    onDelete: () async {
                      final wf = list[i] as Map<String, dynamic>;
                      try {
                        await ref.read(apiClientProvider).deleteApprovalWorkflow(wf['id'] as String);
                        ref.invalidate(_workflowsProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
                        }
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _WorkflowDialog(onSaved: () => ref.invalidate(_workflowsProvider)));
  }

  void _showEdit(BuildContext context, WidgetRef ref, Map<String, dynamic> wf) {
    showDialog(context: context, builder: (_) => _WorkflowDialog(existing: wf, onSaved: () => ref.invalidate(_workflowsProvider)));
  }
}

// ── Workflow card ─────────────────────────────────────────────────────────────

class _WorkflowCard extends StatelessWidget {
  final Map<String, dynamic> workflow;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _WorkflowCard({required this.workflow, required this.onToggle, required this.onEdit, required this.onDelete});

  String _entityLabel(String t) {
    const m = {'PO': 'Bon de commande', 'EXPENSE': 'Note de frais', 'LEAVE': 'Congé', 'INVOICE': 'Facture', 'PAYMENT': 'Paiement'};
    return m[t] ?? t;
  }

  Color _entityColor(String t) {
    switch (t) {
      case 'PO': return AppColors.primary;
      case 'EXPENSE': return AppColors.warning;
      case 'LEAVE': return AppColors.accent;
      case 'INVOICE': return AppColors.neutral;
      default: return AppColors.positive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = workflow['name'] as String? ?? '—';
    final entityType = workflow['entityType'] as String? ?? '—';
    final isActive = workflow['isActive'] as bool? ?? true;
    final steps = workflow['steps'] as List? ?? [];
    final color = _entityColor(entityType);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(entityType, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
            Switch(value: isActive, onChanged: (_) => onToggle(), activeThumbColor: AppColors.positive),
          ]),
          const SizedBox(height: 8),
          Text('${_entityLabel(entityType)} · ${steps.length} étape(s)',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 4, children: steps.map((s) {
              final m = s as Map<String, dynamic>;
              final order = m['stepOrder'] as int? ?? 0;
              final label = m['label'] as String? ?? '—';
              final role = m['approverRole'] as String? ?? '—';
              final min = (m['amountMin'] as num?)?.toDouble() ?? 0;
              final max = m['amountMax'] as num?;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFDDE1E7))),
                child: Text('$order. $label ($role${min > 0 ? ' ≥${(min / 1000).toStringAsFixed(0)}K' : ''}${max != null ? ' ≤${(max / 1000).toStringAsFixed(0)}K' : ''})',
                  style: const TextStyle(fontSize: 11)),
              );
            }).toList()),
          ],
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 14), label: const Text('Modifier')),
            TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.negative),
              label: const Text('Supprimer', style: TextStyle(color: AppColors.negative))),
          ]),
        ]),
      ),
    );
  }
}

// ── Workflow dialog (create / edit) ───────────────────────────────────────────

class _WorkflowDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _WorkflowDialog({this.existing, required this.onSaved});

  @override
  ConsumerState<_WorkflowDialog> createState() => _WorkflowDialogState();
}

class _WorkflowDialogState extends ConsumerState<_WorkflowDialog> {
  final _nameCtrl = TextEditingController();
  String _entityType = 'PO';
  final List<Map<String, dynamic>> _steps = [];
  bool _loading = false;
  String? _error;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text = e['name'] as String? ?? '';
      _entityType = e['entityType'] as String? ?? 'PO';
      final existingSteps = e['steps'] as List? ?? [];
      _steps.addAll(existingSteps.map((s) => Map<String, dynamic>.from(s as Map)));
    }
    if (_steps.isEmpty) _addStep();
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  void _addStep() {
    setState(() => _steps.add({
      'stepOrder': _steps.length + 1,
      'label': 'Étape ${_steps.length + 1}',
      'approverRole': 'ADMIN',
      'amountMin': 0,
      'amountMax': null,
    }));
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty || _steps.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'name': _nameCtrl.text.trim(),
        'entityType': _entityType,
        'steps': _steps,
      };
      if (isEdit) {
        await ref.read(apiClientProvider).updateApprovalWorkflow(widget.existing!['id'] as String, data);
      } else {
        await ref.read(apiClientProvider).createApprovalWorkflow(data);
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
      title: Text(isEdit ? 'Modifier le workflow' : 'Nouveau workflow', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom *', hintText: 'Ex: Approbation BC > 500 000 CDF')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Type d\'entité'),
          initialValue: _entityType,
          items: const [
            DropdownMenuItem(value: 'PO',      child: Text('Bon de commande (PO)')),
            DropdownMenuItem(value: 'EXPENSE', child: Text('Note de frais (EXPENSE)')),
            DropdownMenuItem(value: 'LEAVE',   child: Text('Congé (LEAVE)')),
            DropdownMenuItem(value: 'INVOICE', child: Text('Facture (INVOICE)')),
            DropdownMenuItem(value: 'PAYMENT', child: Text('Paiement (PAYMENT)')),
          ],
          onChanged: (v) => setState(() => _entityType = v!),
        ),
        const SizedBox(height: 16),
        Row(children: [
          const Text('Étapes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const Spacer(),
          TextButton.icon(onPressed: _addStep, icon: const Icon(Icons.add, size: 14), label: const Text('Ajouter')),
        ]),
        ..._steps.asMap().entries.map((entry) {
          final i = entry.key;
          final step = entry.value;
          final labelCtrl = TextEditingController(text: step['label'] as String? ?? '');
          final roleCtrl = TextEditingController(text: step['approverRole'] as String? ?? 'ADMIN');
          final minCtrl = TextEditingController(text: '${(step['amountMin'] as num?)?.toInt() ?? 0}');
          final maxCtrl = TextEditingController(text: step['amountMax'] != null ? '${(step['amountMax'] as num).toInt()}' : '');
          return Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDDE1E7)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary))),
                ),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(labelText: 'Label étape', isDense: true),
                  onChanged: (v) => _steps[i]['label'] = v,
                )),
                const SizedBox(width: 8),
                IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.negative),
                  onPressed: () => setState(() => _steps.removeAt(i))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: roleCtrl,
                  decoration: const InputDecoration(labelText: 'Rôle approbateur', isDense: true, hintText: 'ADMIN, COMPTABLE…'),
                  onChanged: (v) => _steps[i]['approverRole'] = v,
                )),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  controller: minCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant min (CDF)', isDense: true),
                  onChanged: (v) => _steps[i]['amountMin'] = int.tryParse(v) ?? 0,
                )),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(
                  controller: maxCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Montant max (vide=∞)', isDense: true),
                  onChanged: (v) => _steps[i]['amountMax'] = v.isEmpty ? null : (int.tryParse(v)),
                )),
              ]),
            ]),
          );
        }),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Enregistrer' : 'Créer')),
      ],
    );
  }
}
