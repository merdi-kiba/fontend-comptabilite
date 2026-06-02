import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _receiptsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getReceipts();
});

class ReceiptsTab extends ConsumerWidget {
  const ReceiptsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receipts = ref.watch(_receiptsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau BR'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_receiptsProvider.future),
        child: receipts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucun bon de réception', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: () => _showCreate(context, ref), icon: const Icon(Icons.add), label: const Text('Créer un BR')),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = list[i] as Map<String, dynamic>;
                    return _ReceiptCard(
                      receipt: r,
                      onConfirm: r['status'] == 'DRAFT'
                          ? () async {
                              try {
                                await ref.read(apiClientProvider).confirmReceipt(r['id'] as String);
                                ref.invalidate(_receiptsProvider);
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Réception confirmée — écriture comptable générée'), backgroundColor: AppColors.positive));
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
                              }
                            }
                          : null,
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateReceiptDialog(onCreated: () => ref.invalidate(_receiptsProvider)));
  }
}

// ── Receipt card ──────────────────────────────────────────────────────────────

class _ReceiptCard extends StatelessWidget {
  final Map<String, dynamic> receipt;
  final VoidCallback? onConfirm;
  const _ReceiptCard({required this.receipt, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final status = receipt['status'] as String? ?? 'DRAFT';
    final ref_ = receipt['reference'] as String? ?? '—';
    final supplier = receipt['tierName'] as String? ?? receipt['tiersName'] as String? ?? '—';
    final date = (receipt['date'] as String? ?? '').substring(0, 10.clamp(0, (receipt['date'] as String? ?? '').length));
    final total = (receipt['totalCost'] as num?)?.toDouble() ?? 0;
    final isConfirmed = status == 'CONFIRMED';
    final color = isConfirmed ? AppColors.positive : AppColors.warning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.local_shipping_outlined, color: color, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ref_, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('$supplier · $date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            if (total > 0)
              Text(Fmt.currency(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(isConfirmed ? 'Confirmé' : 'Brouillon',
                style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
            ),
            if (onConfirm != null) ...[
              const SizedBox(height: 6),
              ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Confirmer'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
              ),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ── Create receipt dialog ─────────────────────────────────────────────────────

class _CreateReceiptDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateReceiptDialog({required this.onCreated});

  @override
  ConsumerState<_CreateReceiptDialog> createState() => _CreateReceiptDialogState();
}

class _CreateReceiptDialogState extends ConsumerState<_CreateReceiptDialog> {
  List<dynamic> _orders = [];
  String? _selectedOrderId;
  Map<String, dynamic>? _orderDetail;
  String? _selectedTiersId;
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _lotCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() { _descCtrl.dispose(); _qtyCtrl.dispose(); _costCtrl.dispose(); _lotCtrl.dispose(); super.dispose(); }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getPurchaseOrders(status: 'CONFIRMED');
      if (mounted) setState(() { _orders = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrderDetail(String orderId) async {
    try {
      final r = await ref.read(apiClientProvider).getPurchaseOrder(orderId);
      if (mounted) {
        setState(() {
          _orderDetail = r;
          _selectedTiersId = r['tiersId'] as String?;
          final lines = r['lines'] as List? ?? [];
          if (lines.isNotEmpty) {
            final l = lines.first as Map<String, dynamic>;
            _descCtrl.text = l['description'] as String? ?? '';
            _qtyCtrl.text = '${l['quantity'] ?? 1}';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selectedOrderId == null || _descCtrl.text.isEmpty) return;
    setState(() { _submitting = true; _error = null; });
    try {
      final lines = _orderDetail?['lines'] as List? ?? [];
      await ref.read(apiClientProvider).createReceipt({
        'orderId': _selectedOrderId,
        'tiersId': _selectedTiersId ?? '',
        'date': _date.toIso8601String().substring(0, 10),
        'lines': lines.isNotEmpty ? [{
          'orderLineId': (lines.first as Map)['id'],
          'description': _descCtrl.text.trim(),
          'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
          'unitCost': double.tryParse(_costCtrl.text) ?? 0,
          if (_lotCtrl.text.isNotEmpty) 'lotNumber': _lotCtrl.text.trim(),
        }] : [],
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
      title: const Text('Nouveau bon de réception', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 440, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Bon de commande (confirmé) *'),
                initialValue: _selectedOrderId,
                items: _orders.map((o) {
                  final m = o as Map<String, dynamic>;
                  return DropdownMenuItem<String>(value: m['id'] as String,
                    child: Text('${m['reference'] ?? '—'} — ${m['tierName'] ?? m['tiersName'] ?? '—'}'));
                }).toList(),
                onChanged: (v) { setState(() => _selectedOrderId = v); if (v != null) _loadOrderDetail(v); },
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date de réception', isDense: true),
                  child: Text(_date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 14)),
                ),
              ),
              const Divider(height: 24),
              const Text('Ligne reçue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 10),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantité'))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: TextFormField(controller: _costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Coût unitaire (CDF)'))),
              ]),
              const SizedBox(height: 10),
              TextFormField(controller: _lotCtrl, decoration: const InputDecoration(labelText: 'N° lot / SN (optionnel)')),
              if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
            ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _submitting ? null : _submit,
          child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer BR')),
      ],
    );
  }
}
