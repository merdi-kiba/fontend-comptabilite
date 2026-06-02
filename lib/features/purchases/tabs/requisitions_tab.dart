import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _reqProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) async {
  return ref.watch(apiClientProvider).getRequisitions(status: status);
});

final _reqFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

class RequisitionsTab extends ConsumerWidget {
  const RequisitionsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_reqFilterProvider);
    final reqs = ref.watch(_reqProvider(filter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle DR'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(children: [
        _StatusFilter(current: filter, onChanged: (s) => ref.read(_reqFilterProvider.notifier).state = s),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(_reqProvider(filter).future),
            child: reqs.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (list) => list.isEmpty
                  ? _empty(onAdd: () => _showCreate(context, ref))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = list[i] as Map<String, dynamic>;
                        return _ReqCard(
                          req: r,
                          onSubmit: () => _action(context, ref, filter, () => ref.read(apiClientProvider).submitRequisition(r['id'] as String)),
                          onApprove: () => _action(context, ref, filter, () => ref.read(apiClientProvider).approveRequisition(r['id'] as String)),
                          onReject: () => _showReject(context, ref, filter, r['id'] as String),
                          onConvert: () => _showConvert(context, ref, filter, r['id'] as String),
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String? filter, Future<dynamic> Function() call) async {
    try {
      await call();
      ref.invalidate(_reqProvider(filter));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opération effectuée'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateReqDialog(onCreated: () => ref.invalidate(_reqProvider(ref.read(_reqFilterProvider)))));
  }

  void _showReject(BuildContext context, WidgetRef ref, String? filter, String id) {
    showDialog(context: context, builder: (_) => _RejectDialog(
      onConfirm: (reason) => _action(context, ref, filter, () => ref.read(apiClientProvider).rejectRequisition(id, reason)),
    ));
  }

  void _showConvert(BuildContext context, WidgetRef ref, String? filter, String id) {
    showDialog(context: context, builder: (_) => _ConvertToPODialog(
      reqId: id,
      onConverted: () => ref.invalidate(_reqProvider(filter)),
    ));
  }
}

Widget _empty({required VoidCallback onAdd}) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[300]),
  const SizedBox(height: 16),
  Text('Aucune demande d\'achat', style: TextStyle(color: Colors.grey[500])),
  const SizedBox(height: 8),
  ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer une DR')),
]));

// ── Status filter ─────────────────────────────────────────────────────────────

class _StatusFilter extends StatelessWidget {
  final String? current;
  final void Function(String?) onChanged;
  const _StatusFilter({required this.current, required this.onChanged});

  static const _statuses = [null, 'DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'CONVERTED'];
  static const _labels = ['Tous', 'Brouillon', 'Soumis', 'Approuvé', 'Rejeté', 'Converti'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _statuses.length,
        separatorBuilder: (_, i) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = current == _statuses[i];
          return GestureDetector(
            onTap: () => onChanged(_statuses[i]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
                border: selected ? null : Border.all(color: const Color(0xFFDDE1E7)),
              ),
              child: Text(_labels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey[700])),
            ),
          );
        },
      ),
    );
  }
}

// ── Requisition card ──────────────────────────────────────────────────────────

class _ReqCard extends StatelessWidget {
  final Map<String, dynamic> req;
  final VoidCallback onSubmit;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onConvert;
  const _ReqCard({required this.req, required this.onSubmit, required this.onApprove, required this.onReject, required this.onConvert});

  Color _statusColor(String s) {
    switch (s) {
      case 'APPROVED': return AppColors.positive;
      case 'REJECTED': return AppColors.negative;
      case 'SUBMITTED': return AppColors.warning;
      case 'CONVERTED': return AppColors.primary;
      default: return AppColors.neutral;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'DRAFT': return 'Brouillon';
      case 'SUBMITTED': return 'En attente';
      case 'APPROVED': return 'Approuvée';
      case 'REJECTED': return 'Rejetée';
      case 'CONVERTED': return 'Convertie';
      default: return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = req['status'] as String? ?? 'DRAFT';
    final ref_ = req['reference'] as String? ?? '—';
    final dept = req['department'] as String? ?? '—';
    final total = (req['totalEstimated'] as num?)?.toDouble() ?? 0;
    final color = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.assignment_outlined, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ref_, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(dept, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              if (total > 0) ...[
                const SizedBox(height: 2),
                Text(Fmt.compact(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ]),
          if (status == 'DRAFT' || status == 'SUBMITTED' || status == 'APPROVED') ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (status == 'DRAFT')
                TextButton.icon(onPressed: onSubmit, icon: const Icon(Icons.send_outlined, size: 14), label: const Text('Soumettre')),
              if (status == 'SUBMITTED') ...[
                TextButton.icon(onPressed: onReject, icon: const Icon(Icons.close, size: 14, color: AppColors.negative), label: const Text('Rejeter', style: TextStyle(color: AppColors.negative))),
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: onApprove, icon: const Icon(Icons.check, size: 14), label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
              ],
              if (status == 'APPROVED')
                ElevatedButton.icon(onPressed: onConvert, icon: const Icon(Icons.shopping_cart_outlined, size: 14), label: const Text('→ Bon de commande'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Create dialog ─────────────────────────────────────────────────────────────

class _CreateReqDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateReqDialog({required this.onCreated});

  @override
  ConsumerState<_CreateReqDialog> createState() => _CreateReqDialogState();
}

class _CreateReqDialogState extends ConsumerState<_CreateReqDialog> {
  final _deptCtrl = TextEditingController();
  final _justCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _accCtrl = TextEditingController(text: '6011');
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _deptCtrl.dispose(); _justCtrl.dispose(); _descCtrl.dispose(); _qtyCtrl.dispose(); _priceCtrl.dispose(); _accCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_deptCtrl.text.isEmpty || _descCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createRequisition({
        'department': _deptCtrl.text.trim(),
        'justification': _justCtrl.text.trim(),
        'lines': [{
          'description': _descCtrl.text.trim(),
          'accountCode': _accCtrl.text.trim(),
          'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
          'estimatedPrice': double.tryParse(_priceCtrl.text) ?? 0,
        }],
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
      title: const Text('Nouvelle demande d\'achat', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _deptCtrl, decoration: const InputDecoration(labelText: 'Département *', hintText: 'Ex: INFORMATIQUE')),
        const SizedBox(height: 10),
        TextFormField(controller: _justCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Justification')),
        const Divider(height: 24),
        const Text('Ligne d\'achat', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 10),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix estimé (CDF)'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _accCtrl, decoration: const InputDecoration(labelText: 'Compte'))),
        ]),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}

// ── Reject dialog ─────────────────────────────────────────────────────────────

class _RejectDialog extends StatefulWidget {
  final void Function(String reason) onConfirm;
  const _RejectDialog({required this.onConfirm});

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Rejeter la demande'),
    content: TextFormField(controller: _ctrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif de rejet *')),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      ElevatedButton(
        onPressed: () { if (_ctrl.text.isNotEmpty) { Navigator.pop(context); widget.onConfirm(_ctrl.text.trim()); } },
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
        child: const Text('Rejeter'),
      ),
    ],
  );
}

// ── Convert to PO dialog ──────────────────────────────────────────────────────

class _ConvertToPODialog extends ConsumerStatefulWidget {
  final String reqId;
  final VoidCallback onConverted;
  const _ConvertToPODialog({required this.reqId, required this.onConverted});

  @override
  ConsumerState<_ConvertToPODialog> createState() => _ConvertToPODialogState();
}

class _ConvertToPODialogState extends ConsumerState<_ConvertToPODialog> {
  List<dynamic> _suppliers = [];
  String? _selectedTiersId;
  bool _loading = false;
  bool _converting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);
    try {
      final res = await ref.read(apiClientProvider).getCustomers(type: 'FOURNISSEUR');
      if (mounted) setState(() { _suppliers = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _convert() async {
    if (_selectedTiersId == null) return;
    setState(() { _converting = true; _error = null; });
    try {
      await ref.read(apiClientProvider).convertRequisitionToPO(widget.reqId, _selectedTiersId!);
      widget.onConverted();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Convertir en bon de commande', style: TextStyle(fontWeight: FontWeight.w700)),
    content: SizedBox(width: 360, child: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Fournisseur *'),
              initialValue: _selectedTiersId,
              items: _suppliers.map((s) {
                final m = s as Map<String, dynamic>;
                return DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] as String? ?? '—'));
              }).toList(),
              onChanged: (v) => setState(() => _selectedTiersId = v),
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
          ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      ElevatedButton(onPressed: _converting ? null : _convert,
        child: _converting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Convertir')),
    ],
  );
}
