import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _cashProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCashRegisters();
});

class CashRegistersTab extends ConsumerWidget {
  const CashRegistersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cashAsync = ref.watch(_cashProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle caisse'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_cashProvider.future),
        child: cashAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (registers) => registers.isEmpty
              ? _Empty(onAdd: () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: registers.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final reg = registers[i] as Map<String, dynamic>;
                    return _CashCard(
                      register: reg,
                      onOpen: () => _showOpenDialog(context, ref, reg['id'] as String),
                      onClose: () async {
                        await ref.read(apiClientProvider).closeCashRegister(reg['id'] as String);
                        ref.invalidate(_cashProvider);
                      },
                      onAddTx: () => _showAddTx(context, ref, reg['id'] as String),
                      onHistory: () => _showHistory(context, ref, reg),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateCashDialog(
      onCreated: () => ref.invalidate(_cashProvider),
    ));
  }

  void _showOpenDialog(BuildContext context, WidgetRef ref, String id) {
    showDialog(context: context, builder: (_) => _OpenCashDialog(
      cashId: id,
      onOpened: () => ref.invalidate(_cashProvider),
    ));
  }

  void _showAddTx(BuildContext context, WidgetRef ref, String cashId) {
    showDialog(context: context, builder: (_) => _AddCashTxDialog(
      cashId: cashId,
      onAdded: () => ref.invalidate(_cashProvider),
    ));
  }

  void _showHistory(BuildContext context, WidgetRef ref, Map<String, dynamic> reg) {
    showDialog(context: context, builder: (_) => _CashHistoryDialog(register: reg));
  }
}

class _CashCard extends StatelessWidget {
  final Map<String, dynamic> register;
  final VoidCallback onOpen;
  final VoidCallback onClose;
  final VoidCallback onAddTx;
  final VoidCallback onHistory;
  const _CashCard({required this.register, required this.onOpen, required this.onClose, required this.onAddTx, required this.onHistory});

  @override
  Widget build(BuildContext context) {
    final name = register['name'] as String? ?? '—';
    final code = register['code'] as String? ?? '—';
    final isOpen = register['isOpen'] as bool? ?? false;
    final balance = (register['currentBalance'] as num?)?.toDouble() ?? 0;
    final currency = register['currency'] as String? ?? 'CDF';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: (isOpen ? AppColors.positive : Colors.grey).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.account_balance_wallet_outlined, color: isOpen ? AppColors.positive : Colors.grey, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isOpen ? AppColors.positive : Colors.grey).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(isOpen ? 'OUVERTE' : 'FERMÉE',
                  style: TextStyle(fontSize: 9, color: isOpen ? AppColors.positive : Colors.grey, fontWeight: FontWeight.w700)),
              ),
            ]),
            Text(code, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text('$currency ${Fmt.currency(balance)}',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                color: balance >= 0 ? null : AppColors.negative)),
          ])),
          Column(children: [
            if (!isOpen)
              IconButton(icon: const Icon(Icons.lock_open_outlined, size: 18, color: AppColors.positive), tooltip: 'Ouvrir', onPressed: onOpen)
            else
              IconButton(icon: const Icon(Icons.lock_outlined, size: 18, color: AppColors.warning), tooltip: 'Fermer', onPressed: onClose),
            IconButton(icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.primary), tooltip: 'Transaction', onPressed: onAddTx),
            IconButton(icon: const Icon(Icons.history_outlined, size: 18), tooltip: 'Historique', onPressed: onHistory),
          ]),
        ]),
      ),
    );
  }
}

class _OpenCashDialog extends ConsumerStatefulWidget {
  final String cashId;
  final VoidCallback onOpened;
  const _OpenCashDialog({required this.cashId, required this.onOpened});

  @override
  ConsumerState<_OpenCashDialog> createState() => _OpenCashDialogState();
}

class _OpenCashDialogState extends ConsumerState<_OpenCashDialog> {
  final _balCtrl = TextEditingController(text: '0');
  bool _loading = false;

  @override
  void dispose() { _balCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ouvrir la caisse'),
      content: TextFormField(
        controller: _balCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Solde d\'ouverture (CDF)', suffixText: 'CDF'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : () async {
            setState(() => _loading = true);
            try {
              await ref.read(apiClientProvider).openCashRegister(widget.cashId, double.tryParse(_balCtrl.text) ?? 0);
              widget.onOpened();
              if (mounted) Navigator.pop(context);
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: const Text('Ouvrir'),
        ),
      ],
    );
  }
}

class _AddCashTxDialog extends ConsumerStatefulWidget {
  final String cashId;
  final VoidCallback onAdded;
  const _AddCashTxDialog({required this.cashId, required this.onAdded});

  @override
  ConsumerState<_AddCashTxDialog> createState() => _AddCashTxDialogState();
}

class _AddCashTxDialogState extends ConsumerState<_AddCashTxDialog> {
  final _descCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _direction = 'IN';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _descCtrl.dispose(); _amtCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || _descCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).addCashTransaction(widget.cashId, {
        'date': DateTime.now().toIso8601String().substring(0, 10),
        'description': _descCtrl.text.trim(),
        'amount': amount,
        'direction': _direction,
        if (_refCtrl.text.isNotEmpty) 'reference': _refCtrl.text.trim(),
      });
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
      title: const Text('Transaction caisse', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'IN', label: Text('Encaissement'), icon: Icon(Icons.arrow_downward, size: 14)),
            ButtonSegment(value: 'OUT', label: Text('Décaissement'), icon: Icon(Icons.arrow_upward, size: 14)),
          ],
          selected: {_direction},
          onSelectionChanged: (s) => setState(() => _direction = s.first),
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
        ),
        const SizedBox(height: 12),
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

class _CashHistoryDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> register;
  const _CashHistoryDialog({required this.register});

  @override
  ConsumerState<_CashHistoryDialog> createState() => _CashHistoryDialogState();
}

class _CashHistoryDialogState extends ConsumerState<_CashHistoryDialog> {
  List<dynamic> _txs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).getCashTransactions(widget.register['id'] as String);
      if (mounted) setState(() { _txs = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Historique — ${widget.register['name']}'),
      content: SizedBox(
        width: 480, height: 380,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _txs.isEmpty
                ? Center(child: Text('Aucune transaction', style: TextStyle(color: Colors.grey[500])))
                : ListView.separated(
                    itemCount: _txs.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final tx = _txs[i] as Map<String, dynamic>;
                      final dir = tx['direction'] as String? ?? 'IN';
                      final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
                      final isIn = dir == 'IN';
                      return ListTile(
                        dense: true,
                        leading: Icon(isIn ? Icons.arrow_downward : Icons.arrow_upward,
                          color: isIn ? AppColors.positive : AppColors.negative, size: 18),
                        title: Text(tx['description'] as String? ?? '—', style: const TextStyle(fontSize: 13)),
                        subtitle: Text((tx['date'] as String? ?? '').substring(0, 10.clamp(0, (tx['date'] as String? ?? '').length)), style: const TextStyle(fontSize: 11)),
                        trailing: Text(
                          '${isIn ? '+' : '-'}${Fmt.compact(amount)}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: isIn ? AppColors.positive : AppColors.negative),
                        ),
                      );
                    },
                  ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}

class _CreateCashDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateCashDialog({required this.onCreated});

  @override
  ConsumerState<_CreateCashDialog> createState() => _CreateCashDialogState();
}

class _CreateCashDialogState extends ConsumerState<_CreateCashDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _accountCtrl = TextEditingController(text: '571');
  String _currency = 'CDF';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); _nameCtrl.dispose(); _accountCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createCashRegister({
        'code': _codeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
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
      title: const Text('Nouvelle caisse', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'CAISSE-01')),
        const SizedBox(height: 10),
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom *')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(labelText: 'Devise'),
            items: ['CDF', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _currency = v!),
          )),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _accountCtrl, decoration: const InputDecoration(labelText: 'Compte 571'))),
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

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text('Aucune caisse', style: TextStyle(color: Colors.grey[600])),
    const SizedBox(height: 8),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer une caisse')),
  ]));
}
