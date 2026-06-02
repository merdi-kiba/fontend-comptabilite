import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _agedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAgedPayables();
});

class AgedPayablesTab extends ConsumerStatefulWidget {
  const AgedPayablesTab({super.key});

  @override
  ConsumerState<AgedPayablesTab> createState() => _AgedPayablesTabState();
}

class _AgedPayablesTabState extends ConsumerState<AgedPayablesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Balance âgée'),
            Tab(text: 'Payer une facture'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: const [
          _AgedView(),
          _PaymentView(),
        ]),
      ),
    ]);
  }
}

// ── Aged payables view ────────────────────────────────────────────────────────

class _AgedView extends ConsumerWidget {
  const _AgedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aged = ref.watch(_agedProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_agedProvider.future),
      child: aged.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (data) {
          final total = (data['total'] as num?)?.toDouble() ?? 0;
          final buckets = data['byBucket'] as List? ?? [];
          final suppliers = data['suppliers'] as List? ?? [];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Total banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.negative, AppColors.negative.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Total dettes fournisseurs', style: TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(Fmt.currency(total), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  ])),
                  const Icon(Icons.payments_outlined, color: Colors.white38, size: 44),
                ]),
              ),
              const SizedBox(height: 16),

              // Buckets
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Répartition par ancienneté', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 12),
                  ...buckets.map((b) {
                    final m = b as Map<String, dynamic>;
                    final bucket = m['bucket'] as String? ?? '—';
                    final amount = (m['amount'] as num?)?.toDouble() ?? 0;
                    final invoices = m['invoices'] as int? ?? 0;
                    final color = _bucketColor(bucket);
                    final pct = total > 0 ? amount / total : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(_bucketLabel(bucket), style: const TextStyle(fontSize: 13))),
                          Text('$invoices FA', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          const SizedBox(width: 10),
                          Text(Fmt.compact(amount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: pct.toDouble(), backgroundColor: color.withValues(alpha: 0.1), color: color, minHeight: 6),
                        ),
                      ]),
                    );
                  }),
                ]),
              )),
              const SizedBox(height: 12),

              // Suppliers list
              if (suppliers.isNotEmpty) ...[
                const Text('Détail par fournisseur', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...suppliers.map((s) {
                  final m = s as Map<String, dynamic>;
                  final name = m['name'] as String? ?? '—';
                  final amount = (m['total'] as num?)?.toDouble() ?? 0;
                  final oldest = (m['oldest'] as String? ?? '').substring(0, 10.clamp(0, (m['oldest'] as String? ?? '').length));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.business_outlined, size: 18, color: AppColors.neutral),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: oldest.isNotEmpty ? Text('Depuis le $oldest', style: const TextStyle(fontSize: 11)) : null,
                      trailing: Text(Fmt.compact(amount),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.negative)),
                    ),
                  );
                }),
              ],
            ]),
          );
        },
      ),
    );
  }

  Color _bucketColor(String bucket) {
    switch (bucket) {
      case 'current': return AppColors.positive;
      case '30days': return AppColors.warning;
      case '60days': return const Color(0xFFE65100);
      case '90days': case 'over90': return AppColors.negative;
      default: return AppColors.neutral;
    }
  }

  String _bucketLabel(String bucket) {
    switch (bucket) {
      case 'current': return 'Courant (non échu)';
      case '30days': return '1–30 jours';
      case '60days': return '31–60 jours';
      case '90days': return '61–90 jours';
      case 'over90': return '> 90 jours';
      default: return bucket;
    }
  }
}

// ── Payment view ──────────────────────────────────────────────────────────────

class _PaymentView extends ConsumerStatefulWidget {
  const _PaymentView();

  @override
  ConsumerState<_PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends ConsumerState<_PaymentView> {
  final _entryIdCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _method = 'VIREMENT';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() { _entryIdCtrl.dispose(); _amtCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _pay() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (_entryIdCtrl.text.isEmpty || amount == null) return;
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await ref.read(apiClientProvider).paySupplierInvoice(_entryIdCtrl.text.trim(), {
        'amount': amount,
        'method': _method,
        'reference': _refCtrl.text.trim(),
        'date': _date.toIso8601String().substring(0, 10),
      });
      setState(() => _success = 'Paiement enregistré — écriture D401/C521 générée');
      ref.invalidate(_agedProvider);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Payer une facture fournisseur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 4),
        Text('Le paiement est lié à l\'écriture comptable de type AC (journal Achats).', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 16),
        TextFormField(controller: _entryIdCtrl, decoration: const InputDecoration(labelText: 'ID écriture comptable (journalEntryId) *')),
        const SizedBox(height: 12),
        TextFormField(controller: _amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montant (CDF) *', suffixText: 'CDF')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Mode de paiement'),
          initialValue: _method,
          items: ['VIREMENT', 'CHEQUE', 'ESPECES', 'MOBILE_MONEY'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
          onChanged: (v) => setState(() => _method = v!),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Référence paiement')),
        const SizedBox(height: 12),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date de paiement', isDense: true),
            child: Text(_date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 20),
        if (_success != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(_success!, style: const TextStyle(color: AppColors.positive))),
            ]),
          ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loading ? null : _pay,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_outlined),
            label: Text(_loading ? 'Traitement…' : 'Enregistrer le paiement'),
          ),
        ),
        const SizedBox(height: 24),
        // Note de débit
        const Divider(),
        const SizedBox(height: 12),
        _DebitNoteSection(),
      ]),
    );
  }
}

// ── Debit note section ────────────────────────────────────────────────────────

class _DebitNoteSection extends ConsumerStatefulWidget {
  @override
  ConsumerState<_DebitNoteSection> createState() => _DebitNoteSectionState();
}

class _DebitNoteSectionState extends ConsumerState<_DebitNoteSection> {
  bool _expanded = false;
  List<dynamic> _suppliers = [];
  String? _selectedTiersId;
  final _descCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _origRefCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _success;

  @override
  void dispose() { _descCtrl.dispose(); _qtyCtrl.dispose(); _priceCtrl.dispose(); _origRefCtrl.dispose(); super.dispose(); }

  Future<void> _loadSuppliers() async {
    try {
      final r = await ref.read(apiClientProvider).getCustomers(type: 'FOURNISSEUR');
      if (mounted) setState(() => _suppliers = r);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (_selectedTiersId == null || _descCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await ref.read(apiClientProvider).createDebitNote({
        'tiersId': _selectedTiersId,
        'date': DateTime.now().toIso8601String().substring(0, 10),
        if (_origRefCtrl.text.isNotEmpty) 'originalFaRef': _origRefCtrl.text.trim(),
        'lines': [{
          'description': _descCtrl.text.trim(),
          'accountCode': '6011',
          'taxGroup': 'A',
          'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
          'unitPrice': double.tryParse(_priceCtrl.text) ?? 0,
        }],
      });
      setState(() => _success = 'Note de débit créée — écriture D401/C60x générée');
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      GestureDetector(
        onTap: () {
          setState(() => _expanded = !_expanded);
          if (_expanded && _suppliers.isEmpty) _loadSuppliers();
        },
        child: Row(children: [
          const Icon(Icons.note_alt_outlined, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          const Text('Note de débit fournisseur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey[500]),
        ]),
      ),
      if (_expanded) ...[
        const SizedBox(height: 12),
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
        TextFormField(controller: _origRefCtrl, decoration: const InputDecoration(labelText: 'Réf. FA d\'origine (optionnel)')),
        const SizedBox(height: 10),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Motif *')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Qté'))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix unitaire (CDF)'))),
        ]),
        if (_success != null) ...[
          const SizedBox(height: 8),
          Text(_success!, style: const TextStyle(color: AppColors.positive, fontSize: 12)),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _submit,
            icon: const Icon(Icons.note_add_outlined, size: 16),
            label: const Text('Créer note de débit'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.warning, side: const BorderSide(color: AppColors.warning)),
          ),
        ),
      ],
    ]);
  }
}
