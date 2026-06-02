import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _stockProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getStock();
});

final _valuationProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getStockValuation();
});

class StockTab extends ConsumerStatefulWidget {
  const StockTab({super.key});

  @override
  ConsumerState<StockTab> createState() => _StockTabState();
}

class _StockTabState extends ConsumerState<StockTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
            Tab(text: 'Inventaire'),
            Tab(text: 'Valorisation'),
            Tab(text: 'Inventaire physique'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: const [
          _StockListView(),
          _ValuationView(),
          _PhysicalInventoryView(),
        ]),
      ),
    ]);
  }
}

// ── Stock list ────────────────────────────────────────────────────────────────

class _StockListView extends ConsumerWidget {
  const _StockListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(_stockProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_stockProvider.future),
      child: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (items) => items.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Aucun article en stock', style: TextStyle(color: Colors.grey[500])),
                const SizedBox(height: 4),
                Text('Les articles sont ajoutés lors des bons de réception confirmés', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
              ]))
            : Column(children: [
                // Summary header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(children: [
                    Icon(Icons.inventory_2_outlined, size: 16, color: Colors.grey[500]),
                    const SizedBox(width: 6),
                    Text('${items.length} article(s) en stock', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                  ]),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _StockCard(
                      item: items[i] as Map<String, dynamic>,
                      onMovements: () => _showMovements(context, ref, items[i] as Map<String, dynamic>),
                    ),
                  ),
                ),
              ]),
      ),
    );
  }

  void _showMovements(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    showDialog(context: context, builder: (_) => _MovementsDialog(item: item));
  }
}

// ── Stock card ────────────────────────────────────────────────────────────────

class _StockCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onMovements;
  const _StockCard({required this.item, required this.onMovements});

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? item['productName'] as String? ?? '—';
    final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
    final cmup = (item['cmup'] as num?)?.toDouble() ?? 0;
    final totalValue = qty * cmup;
    final account = item['accountCode'] as String? ?? '—';

    final isLow = qty < 5;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(
              color: (isLow ? AppColors.warning : AppColors.primary).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.inventory_2_outlined,
              color: isLow ? AppColors.warning : AppColors.primary, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
              if (isLow) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: const Text('FAIBLE', style: TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w700)),
              ),
            ]),
            Text('Compte $account · CMUP : ${Fmt.compact(cmup)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${qty.toStringAsFixed(0)} u.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isLow ? AppColors.warning : AppColors.primary)),
            Text(Fmt.compact(totalValue), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            IconButton(icon: const Icon(Icons.history_outlined, size: 16), tooltip: 'Mouvements', onPressed: onMovements, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ]),
      ),
    );
  }
}

// ── Valuation view ────────────────────────────────────────────────────────────

class _ValuationView extends ConsumerWidget {
  const _ValuationView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final valAsync = ref.watch(_valuationProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_valuationProvider.future),
      child: valAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (data) {
          final total = (data['totalValue'] as num?)?.toDouble() ?? 0;
          final at = (data['at'] as String? ?? '').substring(0, 10.clamp(0, (data['at'] as String? ?? '').length));
          final byAccount = data['byAccount'] as List? ?? [];
          final lines = data['lines'] as List? ?? [];

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withValues(alpha: 0.8)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Valeur stock au $at', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text(Fmt.currency(total), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                  ])),
                  const Icon(Icons.inventory_outlined, color: Colors.white38, size: 44),
                ]),
              ),
              if (byAccount.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text('Par classe de compte', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...byAccount.map((a) {
                  final m = a as Map<String, dynamic>;
                  final acct = m['accountCode'] as String? ?? '—';
                  final acctName = m['accountName'] as String? ?? '—';
                  final value = (m['value'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(acct, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.accent))),
                      ),
                      title: Text(acctName, style: const TextStyle(fontSize: 13)),
                      trailing: Text(Fmt.compact(value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  );
                }),
              ],
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Détail articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DataTable(
                  columnSpacing: 12,
                  headingRowHeight: 36,
                  columns: const [
                    DataColumn(label: Text('Article', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Qté', style: TextStyle(fontSize: 12)), numeric: true),
                    DataColumn(label: Text('CMUP', style: TextStyle(fontSize: 12)), numeric: true),
                    DataColumn(label: Text('Valeur', style: TextStyle(fontSize: 12)), numeric: true),
                  ],
                  rows: lines.map((l) {
                    final m = l as Map<String, dynamic>;
                    final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
                    final cmup = (m['cmup'] as num?)?.toDouble() ?? 0;
                    final value = (m['totalValue'] as num?)?.toDouble() ?? (qty * cmup);
                    return DataRow(cells: [
                      DataCell(Text(m['productName'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(qty.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(Fmt.compact(cmup), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(Fmt.compact(value), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                    ]);
                  }).toList(),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

// ── Physical inventory view ───────────────────────────────────────────────────

class _PhysicalInventoryView extends ConsumerStatefulWidget {
  const _PhysicalInventoryView();

  @override
  ConsumerState<_PhysicalInventoryView> createState() => _PhysicalInventoryViewState();
}

class _PhysicalInventoryViewState extends ConsumerState<_PhysicalInventoryView> {
  List<dynamic> _items = [];
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _costCtrls = {};
  bool _loading = true;
  bool _submitting = false;
  DateTime _date = DateTime.now();
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) { c.dispose(); }
    for (final c in _costCtrls.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final r = await ref.read(apiClientProvider).getInventorySheet();
      if (mounted) {
        setState(() {
          _items = r;
          _loading = false;
          for (final item in r) {
            final m = item as Map<String, dynamic>;
            final id = m['productId'] as String? ?? m['id'] as String? ?? '';
            _qtyCtrls[id] = TextEditingController(text: '${(m['quantity'] as num?)?.toInt() ?? 0}');
            _costCtrls[id] = TextEditingController(text: '${(m['cmup'] as num?)?.toInt() ?? 0}');
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; _success = null; });
    try {
      final lines = _items.map((item) {
        final m = item as Map<String, dynamic>;
        final id = m['productId'] as String? ?? m['id'] as String? ?? '';
        return {
          'productId': id,
          'quantityPhysical': int.tryParse(_qtyCtrls[id]?.text ?? '0') ?? 0,
          'unitCost': double.tryParse(_costCtrls[id]?.text ?? '0') ?? 0,
        };
      }).toList();
      await ref.read(apiClientProvider).postInventory({
        'date': _date.toIso8601String().substring(0, 10),
        'lines': lines,
      });
      setState(() => _success = 'Inventaire comptabilisé — écritures d\'ajustement générées');
      ref.invalidate(_stockProvider);
      ref.invalidate(_valuationProvider);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _submitting ? null : _submit,
        icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.post_add_outlined),
        label: Text(_submitting ? 'Comptabilisation…' : 'Valider l\'inventaire'),
        backgroundColor: AppColors.warning,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Date picker
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
              if (d != null) setState(() => _date = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Date d\'inventaire', isDense: true),
              child: Text(_date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 14)),
            ),
          ),
          const SizedBox(height: 4),
          Text('Saisissez les quantités physiques comptées. Les écarts génèrent des OD D603/C31x.', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 16),
          if (_success != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(_success!, style: const TextStyle(color: AppColors.positive)),
            ),
          if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))),
          if (_items.isEmpty)
            Center(child: Text('Aucun article stockable', style: TextStyle(color: Colors.grey[500])))
          else
            ..._items.map((item) {
              final m = item as Map<String, dynamic>;
              final id = m['productId'] as String? ?? m['id'] as String? ?? '';
              final name = m['name'] as String? ?? m['productName'] as String? ?? '—';
              final sysQty = (m['quantity'] as num?)?.toDouble() ?? 0;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      Text('Système : ${sysQty.toStringAsFixed(0)} u.', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _qtyCtrls[id],
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qté physique', isDense: true),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: TextFormField(
                        controller: _costCtrls[id],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Coût unitaire (CDF)', isDense: true),
                      )),
                    ]),
                  ]),
                ),
              );
            }),
        ]),
      ),
    );
  }
}

// ── Movements dialog ──────────────────────────────────────────────────────────

class _MovementsDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> item;
  const _MovementsDialog({required this.item});

  @override
  ConsumerState<_MovementsDialog> createState() => _MovementsDialogState();
}

class _MovementsDialogState extends ConsumerState<_MovementsDialog> {
  List<dynamic> _movements = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.item['productId'] as String? ?? widget.item['id'] as String? ?? '';
    try {
      final r = await ref.read(apiClientProvider).getProductMovements(id);
      if (mounted) setState(() { _movements = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.item['name'] as String? ?? widget.item['productName'] as String? ?? '—';
    return AlertDialog(
      title: Text('Mouvements — $name'),
      content: SizedBox(
        width: 480, height: 360,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _movements.isEmpty
                ? Center(child: Text('Aucun mouvement', style: TextStyle(color: Colors.grey[500])))
                : ListView.separated(
                    itemCount: _movements.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final m = _movements[i] as Map<String, dynamic>;
                      final type = m['type'] as String? ?? '—';
                      final qty = (m['quantity'] as num?)?.toDouble() ?? 0;
                      final dir = (m['direction'] as num?)?.toInt() ?? 1;
                      final isIn = dir > 0;
                      final date = (m['date'] as String? ?? '').substring(0, 10.clamp(0, (m['date'] as String? ?? '').length));
                      return ListTile(
                        dense: true,
                        leading: Icon(isIn ? Icons.add_circle_outline : Icons.remove_circle_outline,
                          color: isIn ? AppColors.positive : AppColors.negative, size: 18),
                        title: Text(type, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(date, style: const TextStyle(fontSize: 11)),
                        trailing: Text('${isIn ? '+' : '-'}${qty.toStringAsFixed(0)} u.',
                          style: TextStyle(fontWeight: FontWeight.w700, color: isIn ? AppColors.positive : AppColors.negative)),
                      );
                    },
                  ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
