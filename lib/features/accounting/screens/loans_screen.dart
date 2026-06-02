import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _loansProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getLoans();
});

class LoansScreen extends ConsumerWidget {
  const LoansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loansAsync = ref.watch(_loansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emprunts'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel emprunt'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_loansProvider.future),
        child: loansAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (loans) => loans.isEmpty
              ? _Empty(onAdd: () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: loans.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _LoanCard(
                    loan: loans[i] as Map<String, dynamic>,
                    onViewSchedule: () => _showSchedule(context, ref, loans[i] as Map<String, dynamic>),
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateLoanDialog(onCreated: () => ref.invalidate(_loansProvider)));
  }

  void _showSchedule(BuildContext context, WidgetRef ref, Map<String, dynamic> loan) {
    showDialog(context: context, builder: (_) => _ScheduleDialog(loan: loan, ref: ref));
  }
}

class _LoanCard extends StatelessWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onViewSchedule;
  const _LoanCard({required this.loan, required this.onViewSchedule});

  @override
  Widget build(BuildContext context) {
    final ref_ = loan['reference'] as String? ?? '—';
    final lender = loan['lenderName'] as String? ?? '—';
    final principal = (loan['principal'] as num?)?.toDouble() ?? 0;
    final rate = ((loan['interestRate'] as num?)?.toDouble() ?? 0) * 100;
    final remaining = (loan['remainingBalance'] as num?)?.toDouble() ?? principal;

    return Card(
      child: ListTile(
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.request_quote_outlined, color: AppColors.warning, size: 20)),
        title: Text('$ref_ – $lender', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Principal: ${Fmt.compact(principal)} CDF · Taux: ${rate.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
          Text('Restant: ${Fmt.compact(remaining)} CDF', style: const TextStyle(fontSize: 12, color: AppColors.negative, fontWeight: FontWeight.w600)),
        ]),
        isThreeLine: true,
        trailing: TextButton(onPressed: onViewSchedule, child: const Text('Tableau', style: TextStyle(fontSize: 12))),
      ),
    );
  }
}

class _ScheduleDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> loan;
  final WidgetRef ref;
  const _ScheduleDialog({required this.loan, required this.ref});

  @override
  ConsumerState<_ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<_ScheduleDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).getLoan(widget.loan['id'] as String);
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _data?['scheduleLines'] as List? ?? [];
    return AlertDialog(
      title: Text('Tableau: ${widget.loan['reference']}'),
      content: SizedBox(
        width: 520, height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: DataTable(
                  columnSpacing: 10,
                  columns: const [
                    DataColumn(label: Text('Échéance')),
                    DataColumn(label: Text('Capital')),
                    DataColumn(label: Text('Intérêts')),
                    DataColumn(label: Text('Mensualité')),
                    DataColumn(label: Text('Statut')),
                  ],
                  rows: lines.map((l) {
                    final m = l as Map<String, dynamic>;
                    final paid = m['isPaid'] as bool? ?? false;
                    final dueDate = (m['dueDate'] as String? ?? '').substring(0, 10.clamp(0, (m['dueDate'] as String? ?? '').length));
                    return DataRow(
                      color: WidgetStateProperty.all(paid ? AppColors.positive.withValues(alpha: 0.04) : null),
                      cells: [
                        DataCell(Text(dueDate, style: const TextStyle(fontSize: 12))),
                        DataCell(Text(Fmt.compact((m['principalAmount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(Fmt.compact((m['interestAmount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(Fmt.compact((m['totalAmount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                        DataCell(paid
                            ? const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 16)
                            : TextButton(
                                onPressed: () async {
                                  await ref.read(apiClientProvider).payLoanSchedule(m['id'] as String);
                                  _load();
                                },
                                child: const Text('Payer', style: TextStyle(fontSize: 11)),
                              )),
                      ],
                    );
                  }).toList(),
                ),
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}

class _CreateLoanDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateLoanDialog({required this.onCreated});

  @override
  ConsumerState<_CreateLoanDialog> createState() => _CreateLoanDialogState();
}

class _CreateLoanDialogState extends ConsumerState<_CreateLoanDialog> {
  final _refCtrl = TextEditingController();
  final _lenderCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '0.12');
  final _accountCtrl = TextEditingController(text: '163');
  final DateTime _start = DateTime.now();
  final DateTime _end = DateTime.now().add(const Duration(days: 730));
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _refCtrl.dispose(); _lenderCtrl.dispose(); _principalCtrl.dispose(); _rateCtrl.dispose(); _accountCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final principal = double.tryParse(_principalCtrl.text);
    if (principal == null || _lenderCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createLoan({
        'reference': _refCtrl.text.trim(),
        'lenderName': _lenderCtrl.text.trim(),
        'principal': principal,
        'interestRate': double.tryParse(_rateCtrl.text) ?? 0.12,
        'startDate': _start.toIso8601String().substring(0, 10),
        'endDate': _end.toIso8601String().substring(0, 10),
        'paymentFreq': 'MONTHLY',
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
      title: const Text('Nouvel emprunt', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 420, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Référence', hintText: 'EMP-2026-001')),
        const SizedBox(height: 10),
        TextFormField(controller: _lenderCtrl, decoration: const InputDecoration(labelText: 'Prêteur *', hintText: 'Ex: Rawbank')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _principalCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Capital *', suffixText: 'CDF'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _rateCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Taux annuel', hintText: '0.12'))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _accountCtrl, decoration: const InputDecoration(labelText: 'Compte comptable', hintText: '163')),
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
    Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text('Aucun emprunt', style: TextStyle(color: Colors.grey[600])),
    const SizedBox(height: 8),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Enregistrer un emprunt')),
  ]));
}
