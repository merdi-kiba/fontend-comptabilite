import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _poProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) async {
  return ref.watch(apiClientProvider).getPurchaseOrders(status: status);
});

final _poFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

class PurchaseOrdersTab extends ConsumerWidget {
  const PurchaseOrdersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_poFilterProvider);
    final orders = ref.watch(_poProvider(filter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau BC'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(children: [
        _PoFilter(current: filter, onChanged: (s) => ref.read(_poFilterProvider.notifier).state = s),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(_poProvider(filter).future),
            child: orders.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (list) => list.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucun bon de commande', style: TextStyle(color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final o = list[i] as Map<String, dynamic>;
                        return _PoCard(
                          order: o,
                          onApprove: () => _action(context, ref, filter, () => ref.read(apiClientProvider).approvePurchaseOrder(o['id'] as String)),
                          onConfirm: () => _action(context, ref, filter, () => ref.read(apiClientProvider).confirmPurchaseOrder(o['id'] as String)),
                          onCancel: () => _action(context, ref, filter, () => ref.read(apiClientProvider).cancelPurchaseOrder(o['id'] as String)),
                          onMatch: () => _showThreeWayMatch(context, ref, o['id'] as String),
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
      ref.invalidate(_poProvider(filter));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opération effectuée'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreatePoDialog(onCreated: () => ref.invalidate(_poProvider(ref.read(_poFilterProvider)))));
  }

  void _showThreeWayMatch(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(context: context, builder: (_) => _ThreeWayMatchDialog(orderId: orderId));
  }
}

// ── Filter ────────────────────────────────────────────────────────────────────

class _PoFilter extends StatelessWidget {
  final String? current;
  final void Function(String?) onChanged;
  const _PoFilter({required this.current, required this.onChanged});

  static const _statuses = [null, 'DRAFT', 'PENDING_APPROVAL', 'APPROVED', 'CONFIRMED', 'RECEIVED', 'CANCELLED'];
  static const _labels =   ['Tous', 'Brouillon', 'En approbation', 'Approuvé', 'Confirmé', 'Reçu', 'Annulé'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44, color: Colors.white,
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

// ── PO card ───────────────────────────────────────────────────────────────────

class _PoCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onApprove;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final VoidCallback onMatch;
  const _PoCard({required this.order, required this.onApprove, required this.onConfirm, required this.onCancel, required this.onMatch});

  Color _statusColor(String s) {
    switch (s) {
      case 'APPROVED': case 'CONFIRMED': return AppColors.positive;
      case 'CANCELLED': return AppColors.negative;
      case 'PENDING_APPROVAL': return AppColors.warning;
      case 'RECEIVED': return AppColors.primary;
      default: return AppColors.neutral;
    }
  }

  String _statusLabel(String s) {
    const labels = {
      'DRAFT': 'Brouillon', 'PENDING_APPROVAL': 'En approbation',
      'APPROVED': 'Approuvé', 'CONFIRMED': 'Confirmé',
      'RECEIVED': 'Reçu', 'CANCELLED': 'Annulé',
    };
    return labels[s] ?? s;
  }

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'DRAFT';
    final ref_ = order['reference'] as String? ?? '—';
    final supplier = order['tierName'] as String? ?? order['tiersName'] as String? ?? '—';
    final total = (order['totalTtc'] as num?)?.toDouble() ?? (order['totalCdf'] as num?)?.toDouble() ?? 0;
    final currency = order['currency'] as String? ?? 'CDF';
    final color = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.shopping_cart_outlined, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ref_, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(supplier, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 2),
              Text('$currency ${Fmt.compact(total)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (status == 'CONFIRMED' || status == 'RECEIVED')
              TextButton.icon(onPressed: onMatch, icon: const Icon(Icons.compare_arrows_outlined, size: 14), label: const Text('3-Way Match')),
            if (status == 'PENDING_APPROVAL')
              ElevatedButton.icon(onPressed: onApprove, icon: const Icon(Icons.check, size: 14), label: const Text('Approuver'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
            if (status == 'APPROVED')
              ElevatedButton.icon(onPressed: onConfirm, icon: const Icon(Icons.send_outlined, size: 14), label: const Text('Confirmer'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
            if (status != 'CANCELLED' && status != 'RECEIVED') ...[
              const SizedBox(width: 8),
              if (status == 'DRAFT')
                ElevatedButton.icon(onPressed: onApprove, icon: const Icon(Icons.check, size: 14), label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
              TextButton.icon(onPressed: onCancel, icon: const Icon(Icons.close, size: 14, color: AppColors.negative), label: const Text('Annuler', style: TextStyle(color: AppColors.negative))),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ── 3-Way Match dialog ────────────────────────────────────────────────────────

class _ThreeWayMatchDialog extends ConsumerStatefulWidget {
  final String orderId;
  const _ThreeWayMatchDialog({required this.orderId});

  @override
  ConsumerState<_ThreeWayMatchDialog> createState() => _ThreeWayMatchDialogState();
}

class _ThreeWayMatchDialogState extends ConsumerState<_ThreeWayMatchDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).getThreeWayMatch(widget.orderId);
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _data = {'error': parseError(e)}; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPay = _data?['canPay'] as bool? ?? false;
    final status = _data?['status'] as String? ?? '—';
    final divergence = ((_data?['divergence'] as num?)?.toDouble() ?? 0) * 100;
    final checks = (_data?['checks'] as List? ?? []);

    return AlertDialog(
      title: const Text('Rapprochement 3 voies', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 460, height: 300,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Global status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (canPay ? AppColors.positive : AppColors.negative).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: canPay ? AppColors.positive : AppColors.negative),
                  ),
                  child: Row(children: [
                    Icon(canPay ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                      color: canPay ? AppColors.positive : AppColors.negative),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(canPay ? 'Paiement autorisé' : 'Paiement bloqué',
                        style: TextStyle(fontWeight: FontWeight.w700, color: canPay ? AppColors.positive : AppColors.negative)),
                      Text('Statut : $status · Écart : ${divergence.toStringAsFixed(1)}%',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ])),
                  ]),
                ),
                const SizedBox(height: 12),
                // Checks
                Expanded(
                  child: ListView(children: checks.map((c) {
                    final m = c as Map<String, dynamic>;
                    final ok = m['ok'] as bool? ?? false;
                    return ListTile(
                      dense: true,
                      leading: Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                        color: ok ? AppColors.positive : AppColors.negative, size: 18),
                      title: Text(m['label'] as String? ?? '—', style: const TextStyle(fontSize: 13)),
                      trailing: Text(m['detail'] as String? ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    );
                  }).toList()),
                ),
              ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}

// ── Create PO dialog ──────────────────────────────────────────────────────────

class _CreatePoDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreatePoDialog({required this.onCreated});

  @override
  ConsumerState<_CreatePoDialog> createState() => _CreatePoDialogState();
}

class _CreatePoDialogState extends ConsumerState<_CreatePoDialog> {
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _accCtrl = TextEditingController(text: '6011');
  List<dynamic> _suppliers = [];
  String? _selectedTiersId;
  String _currency = 'CDF';
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() { _descCtrl.dispose(); _qtyCtrl.dispose(); _priceCtrl.dispose(); _accCtrl.dispose(); super.dispose(); }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getCustomers(type: 'FOURNISSEUR');
      if (mounted) setState(() { _suppliers = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedTiersId == null || _descCtrl.text.isEmpty) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createPurchaseOrder({
        'tiersId': _selectedTiersId,
        'currency': _currency,
        'lines': [{
          'description': _descCtrl.text.trim(),
          'accountCode': _accCtrl.text.trim(),
          'taxGroup': 'A',
          'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
          'unitPrice': double.tryParse(_priceCtrl.text) ?? 0,
        }],
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau bon de commande', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 420, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Fournisseur *'),
                initialValue: _selectedTiersId,
                items: _suppliers.map((s) {
                  final m = s as Map<String, dynamic>;
                  return DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] as String? ?? '—'));
                }).toList(),
                onChanged: (v) => setState(() => _selectedTiersId = v),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Devise'),
                  initialValue: _currency,
                  items: ['CDF', 'USD', 'EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                )),
              ]),
              const Divider(height: 24),
              const Text('Ligne de commande', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qté'))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: 'Prix unitaire ($_currency)'))),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(controller: _accCtrl, decoration: const InputDecoration(labelText: 'Compte'))),
              ]),
              if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
            ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}
