import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

class LedgerBalanceTab extends ConsumerStatefulWidget {
  const LedgerBalanceTab({super.key});

  @override
  ConsumerState<LedgerBalanceTab> createState() => _LedgerBalanceTabState();
}

class _LedgerBalanceTabState extends ConsumerState<LedgerBalanceTab> with SingleTickerProviderStateMixin {
  late final TabController _inner;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _inner.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _inner,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Grand livre'),
            Tab(text: 'Balance générale'),
            Tab(text: 'Créances âgées'),
          ],
        ),
        Expanded(child: TabBarView(
          controller: _inner,
          children: const [
            _LedgerView(),
            _GeneralBalanceView(),
            _AgedView(),
          ],
        )),
      ],
    );
  }
}

// ── Grand livre ───────────────────────────────────────────────────────────────

class _LedgerView extends ConsumerStatefulWidget {
  const _LedgerView();

  @override
  ConsumerState<_LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends ConsumerState<_LedgerView> {
  final _accountCtrl = TextEditingController();
  DateTime _from = DateTime(DateTime.now().year, 1, 1);
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _accountCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ref.read(apiClientProvider).getLedger(
        accountCode: _accountCtrl.text.trim().isEmpty ? null : _accountCtrl.text.trim(),
        from: _from.toIso8601String().substring(0, 10),
        to: _to.toIso8601String().substring(0, 10),
      );
      setState(() => _data = r);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _data?['lines'] as List? ?? _data?['entries'] as List? ?? [];
    final opening = (_data?['openingBalance'] as num?)?.toDouble() ?? 0;
    final closing = (_data?['closingBalance'] as num?)?.toDouble() ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres
          Row(children: [
            Expanded(child: TextFormField(
              controller: _accountCtrl,
              decoration: const InputDecoration(labelText: 'Code compte', hintText: 'Ex: 4111', isDense: true),
            )),
            const SizedBox(width: 8),
            Expanded(child: _DateBtn('Du', _from, (d) => setState(() => _from = d))),
            const SizedBox(width: 8),
            Expanded(child: _DateBtn('Au', _to, (d) => setState(() => _to = d))),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _loading ? null : _load,
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              child: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Charger'),
            ),
          ]),

          if (_error != null) ...[const SizedBox(height: 8), _ErrBanner(_error!)],

          if (_data != null) ...[
            const SizedBox(height: 16),
            // Soldes
            Row(children: [
              Expanded(child: _SoldeCard('Solde ouverture', opening)),
              const SizedBox(width: 12),
              Expanded(child: _SoldeCard('Solde clôture', closing)),
            ]),
            const SizedBox(height: 16),

            // Lignes
            if (lines.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('Date', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Journal', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Libellé', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Débit', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Crédit', style: TextStyle(fontSize: 12))),
                    DataColumn(label: Text('Solde', style: TextStyle(fontSize: 12))),
                  ],
                  rows: lines.map((l) {
                    final m = l as Map<String, dynamic>;
                    final debit = (m['debit'] as num?)?.toDouble() ?? 0;
                    final credit = (m['credit'] as num?)?.toDouble() ?? 0;
                    final balance = (m['balance'] as num?)?.toDouble() ?? 0;
                    return DataRow(cells: [
                      DataCell(Text((m['date'] as String? ?? '').substring(0, 10.clamp(0, (m['date'] as String? ?? '').length)), style: const TextStyle(fontSize: 12))),
                      DataCell(Text(m['journalCode'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
                      DataCell(SizedBox(width: 180, child: Text(m['description'] as String? ?? '—', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                      DataCell(Text(debit > 0 ? Fmt.compact(debit) : '—', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(credit > 0 ? Fmt.compact(credit) : '—', style: const TextStyle(fontSize: 12))),
                      DataCell(Text(Fmt.compact(balance), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: balance >= 0 ? null : AppColors.negative))),
                    ]);
                  }).toList(),
                ),
              )
            else if (_data != null)
              Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Aucune écriture sur cette période', style: TextStyle(color: Colors.grey[500])))),
          ],
        ],
      ),
    );
  }
}

// ── Balance générale ──────────────────────────────────────────────────────────

class _GeneralBalanceView extends ConsumerStatefulWidget {
  const _GeneralBalanceView();

  @override
  ConsumerState<_GeneralBalanceView> createState() => _GeneralBalanceViewState();
}

class _GeneralBalanceViewState extends ConsumerState<_GeneralBalanceView> {
  String? _fyId;
  Map<String, dynamic>? _data;
  bool _loading = false;
  final _fyCtrl = TextEditingController();

  @override
  void dispose() { _fyCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (_fyId == null || _fyId!.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getGeneralBalance(_fyId!);
      setState(() => _data = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _data?['accounts'] as List? ?? [];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: TextFormField(
              controller: _fyCtrl,
              decoration: const InputDecoration(labelText: 'ID Exercice fiscal', isDense: true),
              onChanged: (v) => _fyId = v.trim(),
            )),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _loading ? null : _load, child: const Text('Charger')),
          ]),
          const SizedBox(height: 16),
          if (accounts.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columnSpacing: 16,
                columns: const [
                  DataColumn(label: Text('Compte')),
                  DataColumn(label: Text('Libellé')),
                  DataColumn(label: Text('Débit')),
                  DataColumn(label: Text('Crédit')),
                  DataColumn(label: Text('Solde')),
                ],
                rows: accounts.map((a) {
                  final m = a as Map<String, dynamic>;
                  final debit = (m['totalDebit'] as num?)?.toDouble() ?? 0;
                  final credit = (m['totalCredit'] as num?)?.toDouble() ?? 0;
                  final balance = debit - credit;
                  return DataRow(cells: [
                    DataCell(Text(m['code'] as String? ?? '—', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                    DataCell(SizedBox(width: 200, child: Text(m['name'] as String? ?? '—', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                    DataCell(Text(Fmt.compact(debit), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(Fmt.compact(credit), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(Fmt.compact(balance), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: balance >= 0 ? null : AppColors.negative))),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Créances âgées ────────────────────────────────────────────────────────────

class _AgedView extends ConsumerWidget {
  const _AgedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [Tab(text: 'Clients'), Tab(text: 'Fournisseurs')],
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
          ),
          Expanded(child: TabBarView(children: [
            _AgedList(isClients: true),
            _AgedList(isClients: false),
          ])),
        ],
      ),
    );
  }
}

class _AgedList extends ConsumerWidget {
  final bool isClients;
  const _AgedList({required this.isClients});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
      return isClients
          ? ref.watch(apiClientProvider).getAgedClientsBalance()
          : ref.watch(apiClientProvider).getAgedSuppliersBalance();
    });
    final async = ref.watch(provider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative, fontSize: 12))),
      data: (data) {
        final items = data['items'] as List? ?? data['accounts'] as List? ?? [];
        if (items.isEmpty) {
          return Center(child: Text('Aucune créance ${isClients ? "client" : "fournisseur"}', style: TextStyle(color: Colors.grey[500])));
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            columns: const [
              DataColumn(label: Text('Tiers')),
              DataColumn(label: Text('0–30j')),
              DataColumn(label: Text('31–60j')),
              DataColumn(label: Text('61–90j')),
              DataColumn(label: Text('>90j')),
              DataColumn(label: Text('Total')),
            ],
            rows: items.map((item) {
              final m = item as Map<String, dynamic>;
              final b0 = (m['bucket0_30'] as num?)?.toDouble() ?? 0;
              final b1 = (m['bucket31_60'] as num?)?.toDouble() ?? 0;
              final b2 = (m['bucket61_90'] as num?)?.toDouble() ?? 0;
              final b3 = (m['bucket90plus'] as num?)?.toDouble() ?? 0;
              final total = b0 + b1 + b2 + b3;
              return DataRow(cells: [
                DataCell(Text(m['name'] as String? ?? '—', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                DataCell(Text(Fmt.compact(b0), style: const TextStyle(fontSize: 12, color: AppColors.positive))),
                DataCell(Text(Fmt.compact(b1), style: const TextStyle(fontSize: 12, color: AppColors.warning))),
                DataCell(Text(Fmt.compact(b2), style: TextStyle(fontSize: 12, color: Colors.orange[700]))),
                DataCell(Text(Fmt.compact(b3), style: const TextStyle(fontSize: 12, color: AppColors.negative))),
                DataCell(Text(Fmt.compact(total), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ]);
            }).toList(),
          ),
        );
      },
    );
  }
}

// ── Utilitaires ───────────────────────────────────────────────────────────────

class _DateBtn extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onPicked;
  const _DateBtn(this.label, this.date, this.onPicked);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _SoldeCard extends StatelessWidget {
  final String label;
  final double value;
  const _SoldeCard(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8ECF0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: value >= 0 ? null : AppColors.negative)),
      ]),
    );
  }
}

class _ErrBanner extends StatelessWidget {
  final String msg;
  const _ErrBanner(this.msg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(msg, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
    );
  }
}
