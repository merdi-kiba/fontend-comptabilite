import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _bankAccountsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getBankAccounts();
});

class BankAccountsTab extends ConsumerWidget {
  const BankAccountsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(_bankAccountsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau compte'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_bankAccountsProvider.future),
        child: accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (accounts) => accounts.isEmpty
              ? _Empty(onAdd: () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: accounts.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _BankCard(
                    account: accounts[i] as Map<String, dynamic>,
                    onStatement: () => _showStatement(context, ref, accounts[i] as Map<String, dynamic>),
                    onAddTx: () => _showAddTx(context, ref, (accounts[i] as Map)['id'] as String),
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateBankDialog(
      onCreated: () => ref.invalidate(_bankAccountsProvider),
    ));
  }

  void _showStatement(BuildContext context, WidgetRef ref, Map<String, dynamic> account) {
    showDialog(context: context, builder: (_) => _StatementDialog(account: account));
  }

  void _showAddTx(BuildContext context, WidgetRef ref, String bankId) {
    showDialog(context: context, builder: (_) => _AddTransactionDialog(
      bankId: bankId, isCash: false,
      onAdded: () => ref.invalidate(_bankAccountsProvider),
    ));
  }
}

class _BankCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onStatement;
  final VoidCallback onAddTx;
  const _BankCard({required this.account, required this.onStatement, required this.onAddTx});

  @override
  Widget build(BuildContext context) {
    final name = account['bankName'] as String? ?? account['name'] as String? ?? '—';
    final code = account['code'] as String? ?? '—';
    final num_ = account['accountNumber'] as String? ?? '—';
    final balance = toDouble(account['balance']);
    final currency = account['currency'] as String? ?? 'CDF';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('$code · $num_', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('$currency ${Fmt.currency(balance)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                color: balance >= 0 ? AppColors.positive : AppColors.negative)),
          ])),
          Column(children: [
            IconButton(icon: const Icon(Icons.receipt_outlined, size: 18), tooltip: 'Relevé', onPressed: onStatement),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary), tooltip: 'Transaction', onPressed: onAddTx),
          ]),
        ]),
      ),
    );
  }
}

class _StatementDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> account;
  const _StatementDialog({required this.account});

  @override
  ConsumerState<_StatementDialog> createState() => _StatementDialogState();
}

class _StatementDialogState extends ConsumerState<_StatementDialog> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _data;
  bool _loading = false;

  Future<void> _load() async {
    setState(() { _loading = true; _data = null; });
    try {
      final r = await ref.read(apiClientProvider).getBankStatement(
        widget.account['id'] as String,
        _from.toIso8601String().substring(0, 10),
        _to.toIso8601String().substring(0, 10),
      );
      if (mounted) setState(() => _data = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _data?['lines'] as List? ?? _data?['transactions'] as List? ?? [];
    return AlertDialog(
      title: Text('Relevé — ${widget.account['bankName'] ?? "Compte"}'),
      content: SizedBox(
        width: 560, height: 400,
        child: Column(children: [
          Row(children: [
            Expanded(child: _DateBtn('Du', _from, (d) => setState(() => _from = d))),
            const SizedBox(width: 8),
            Expanded(child: _DateBtn('Au', _to, (d) => setState(() => _to = d))),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _loading ? null : _load, child: const Text('Charger')),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : lines.isEmpty
                    ? Center(child: Text('Aucune transaction', style: TextStyle(color: Colors.grey[500])))
                    : SingleChildScrollView(
                        child: DataTable(
                          columnSpacing: 12,
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Débit')),
                            DataColumn(label: Text('Crédit')),
                          ],
                          rows: lines.map((l) {
                            final m = l as Map<String, dynamic>;
                            final amount = (m['amount'] as num?)?.toDouble() ?? 0;
                            final dir = m['direction'] as String? ?? 'CREDIT';
                            final date = (m['date'] as String? ?? '').substring(0, 10.clamp(0, (m['date'] as String? ?? '').length));
                            return DataRow(cells: [
                              DataCell(Text(date, style: const TextStyle(fontSize: 12))),
                              DataCell(SizedBox(width: 160, child: Text(m['description'] as String? ?? '—', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))),
                              DataCell(Text(dir == 'DEBIT' ? Fmt.compact(amount) : '—', style: const TextStyle(fontSize: 12, color: AppColors.negative))),
                              DataCell(Text(dir == 'CREDIT' ? Fmt.compact(amount) : '—', style: const TextStyle(fontSize: 12, color: AppColors.positive))),
                            ]);
                          }).toList(),
                        ),
                      ),
          ),
        ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}

class _CreateBankDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateBankDialog({required this.onCreated});

  @override
  ConsumerState<_CreateBankDialog> createState() => _CreateBankDialogState();
}

class _CreateBankDialogState extends ConsumerState<_CreateBankDialog> {
  final _codeCtrl = TextEditingController();
  final _bankCtrl = TextEditingController();
  final _numCtrl = TextEditingController();
  final _accountCtrl = TextEditingController(text: '521');
  String _currency = 'CDF';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); _bankCtrl.dispose(); _numCtrl.dispose(); _accountCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_bankCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createBankAccount({
        'code': _codeCtrl.text.trim(),
        'bankName': _bankCtrl.text.trim(),
        'accountNumber': _numCtrl.text.trim(),
        'currency': _currency,
        'accountCode': _accountCtrl.text.trim(),
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
      title: const Text('Nouveau compte bancaire', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'BQ-RAWBANK-001')),
        const SizedBox(height: 10),
        TextFormField(controller: _bankCtrl, decoration: const InputDecoration(labelText: 'Banque *', hintText: 'Ex: Rawbank')),
        const SizedBox(height: 10),
        TextFormField(controller: _numCtrl, decoration: const InputDecoration(labelText: 'N° compte')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Devise'),
            items: ['CDF', 'USD', 'EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _currency = v!),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _accountCtrl, decoration: const InputDecoration(labelText: 'Compte 521'))),
        ]),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}

class _AddTransactionDialog extends ConsumerStatefulWidget {
  final String bankId;
  final bool isCash;
  final VoidCallback onAdded;
  const _AddTransactionDialog({required this.bankId, required this.isCash, required this.onAdded});

  @override
  ConsumerState<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends ConsumerState<_AddTransactionDialog> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _direction = 'CREDIT';
  final DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _descCtrl.dispose(); _amtCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || _descCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'date': _date.toIso8601String().substring(0, 10),
        'description': _descCtrl.text.trim(),
        'amount': amount,
        'direction': _direction,
        if (_refCtrl.text.isNotEmpty) 'reference': _refCtrl.text.trim(),
      };
      if (widget.isCash) {
        await ref.read(apiClientProvider).addCashTransaction(widget.bankId, {...data, 'direction': _direction == 'CREDIT' ? 'IN' : 'OUT'});
      } else {
        await ref.read(apiClientProvider).addBankTransaction(widget.bankId, data);
      }
      widget.onAdded();
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
      title: const Text('Nouvelle transaction', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'CREDIT', label: Text('Entrée'), icon: Icon(Icons.arrow_downward, size: 14)),
            ButtonSegment(value: 'DEBIT', label: Text('Sortie'), icon: Icon(Icons.arrow_upward, size: 14)),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 10),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
        const SizedBox(height: 10),
        TextFormField(controller: _amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montant *', suffixText: 'CDF')),
        const SizedBox(height: 10),
        TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Référence')),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer')),
      ],
    );
  }
}

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

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text('Aucun compte bancaire', style: TextStyle(color: Colors.grey[600])),
    const SizedBox(height: 8),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Ajouter un compte')),
  ]));
}
