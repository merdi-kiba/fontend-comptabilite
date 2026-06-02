import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _expProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) async {
  return ref.watch(apiClientProvider).getExpenseClaims(status: status);
});

final _expFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

class ExpenseClaimsTab extends ConsumerWidget {
  const ExpenseClaimsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_expFilterProvider);
    final claims = ref.watch(_expProvider(filter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Note de frais'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(children: [
        _ExpFilter(current: filter, onChanged: (s) => ref.read(_expFilterProvider.notifier).state = s),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(_expProvider(filter).future),
            child: claims.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (list) => list.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucune note de frais', style: TextStyle(color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final c = list[i] as Map<String, dynamic>;
                        return _ExpCard(
                          claim: c,
                          onSubmit: c['status'] == 'DRAFT' ? () => _action(context, ref, filter, () => ref.read(apiClientProvider).submitExpenseClaim(c['id'] as String)) : null,
                          onApprove: c['status'] == 'PENDING' ? () => _action(context, ref, filter, () => ref.read(apiClientProvider).approveExpenseClaim(c['id'] as String)) : null,
                          onReject: c['status'] == 'PENDING' ? () => _showReject(context, ref, filter, c['id'] as String) : null,
                          onPay: c['status'] == 'APPROVED' ? () => _action(context, ref, filter, () => ref.read(apiClientProvider).payExpenseClaim(c['id'] as String)) : null,
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _action(BuildContext context, WidgetRef ref, String? filter, Future<void> Function() call) async {
    try {
      await call();
      ref.invalidate(_expProvider(filter));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opération effectuée'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateExpenseDialog(onCreated: () => ref.invalidate(_expProvider(ref.read(_expFilterProvider)))));
  }

  void _showReject(BuildContext context, WidgetRef ref, String? filter, String id) {
    showDialog(context: context, builder: (_) => _RejectDialog(
      onConfirm: (reason) => _action(context, ref, filter, () => ref.read(apiClientProvider).rejectExpenseClaim(id, reason)),
    ));
  }
}

// ── Filter ────────────────────────────────────────────────────────────────────

class _ExpFilter extends StatelessWidget {
  final String? current;
  final void Function(String?) onChanged;
  const _ExpFilter({required this.current, required this.onChanged});

  static const _statuses = [null, 'DRAFT', 'PENDING', 'APPROVED', 'PAID', 'REJECTED'];
  static const _labels = ['Tous', 'Brouillon', 'En attente', 'Approuvé', 'Payé', 'Rejeté'];

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

// ── Expense card ──────────────────────────────────────────────────────────────

class _ExpCard extends StatelessWidget {
  final Map<String, dynamic> claim;
  final VoidCallback? onSubmit;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onPay;
  const _ExpCard({required this.claim, required this.onSubmit, required this.onApprove, required this.onReject, required this.onPay});

  Color _statusColor(String s) {
    switch (s) {
      case 'PAID': case 'APPROVED': return AppColors.positive;
      case 'REJECTED': return AppColors.negative;
      case 'PENDING': return AppColors.warning;
      default: return AppColors.neutral;
    }
  }

  String _statusLabel(String s) {
    const m = {'DRAFT': 'Brouillon', 'PENDING': 'En attente', 'APPROVED': 'Approuvé', 'PAID': 'Payé', 'REJECTED': 'Rejeté'};
    return m[s] ?? s;
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'TRANSPORT': return Icons.directions_car_outlined;
      case 'REPAS': return Icons.restaurant_outlined;
      case 'HEBERGEMENT': return Icons.hotel_outlined;
      case 'MATERIEL': return Icons.computer_outlined;
      default: return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = claim['status'] as String? ?? 'DRAFT';
    final empName = claim['employeeName'] as String? ?? '—';
    final category = claim['category'] as String? ?? 'AUTRE';
    final amount = (claim['amount'] as num?)?.toDouble() ?? 0;
    final currency = claim['currency'] as String? ?? 'CDF';
    final desc = claim['description'] as String? ?? '—';
    final date = (claim['date'] as String? ?? '').substring(0, 10.clamp(0, (claim['date'] as String? ?? '').length));
    final color = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(_categoryIcon(category), color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(empName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('$desc · $date', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$currency ${Fmt.compact(amount)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(_statusLabel(status), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
          if (onSubmit != null || onApprove != null || onPay != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (onSubmit != null)
                ElevatedButton.icon(onPressed: onSubmit, icon: const Icon(Icons.send_outlined, size: 14), label: const Text('Soumettre'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
              if (onReject != null)
                TextButton.icon(onPressed: onReject, icon: const Icon(Icons.close, size: 14, color: AppColors.negative), label: const Text('Rejeter', style: TextStyle(color: AppColors.negative))),
              if (onApprove != null) ...[
                const SizedBox(width: 6),
                ElevatedButton.icon(onPressed: onApprove, icon: const Icon(Icons.check, size: 14), label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
              ],
              if (onPay != null)
                ElevatedButton.icon(onPressed: onPay, icon: const Icon(Icons.payment_outlined, size: 14), label: const Text('Payer'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Create dialog ─────────────────────────────────────────────────────────────

class _CreateExpenseDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateExpenseDialog({required this.onCreated});

  @override
  ConsumerState<_CreateExpenseDialog> createState() => _CreateExpenseDialogState();
}

class _CreateExpenseDialogState extends ConsumerState<_CreateExpenseDialog> {
  List<dynamic> _employees = [];
  String? _selectedEmpId;
  String _category = 'TRANSPORT';
  String _currency = 'CDF';
  final _amtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() { _amtCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getEmployees(status: 'ACTIVE');
      if (mounted) setState(() { _employees = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (_selectedEmpId == null || amount == null || _descCtrl.text.isEmpty) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createExpenseClaim({
        'employeeId': _selectedEmpId,
        'date': _date.toIso8601String().substring(0, 10),
        'category': _category,
        'amount': amount,
        'currency': _currency,
        'description': _descCtrl.text.trim(),
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
      title: const Text('Nouvelle note de frais', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 400, child: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Employé *'),
                initialValue: _selectedEmpId,
                items: _employees.map((e) {
                  final m = e as Map<String, dynamic>;
                  return DropdownMenuItem<String>(value: m['id'] as String, child: Text('${m['firstName']} ${m['lastName']}'.trim()));
                }).toList(),
                onChanged: (v) => setState(() => _selectedEmpId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Catégorie'),
                initialValue: _category,
                items: const [
                  DropdownMenuItem(value: 'TRANSPORT', child: Text('Transport')),
                  DropdownMenuItem(value: 'REPAS', child: Text('Repas')),
                  DropdownMenuItem(value: 'HEBERGEMENT', child: Text('Hébergement')),
                  DropdownMenuItem(value: 'MATERIEL', child: Text('Matériel')),
                  DropdownMenuItem(value: 'AUTRE', child: Text('Autre')),
                ],
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextFormField(controller: _amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Montant *'))),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _currency,
                  items: ['CDF', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _currency = v!),
                  underline: const SizedBox(),
                ),
              ]),
              const SizedBox(height: 10),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description *')),
              const SizedBox(height: 10),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', isDense: true),
                  child: Text(_date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 14)),
                ),
              ),
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

// ── Reject dialog ─────────────────────────────────────────────────────────────

class _RejectDialog extends StatefulWidget {
  final void Function(String) onConfirm;
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
    title: const Text('Rejeter la note de frais'),
    content: TextFormField(controller: _ctrl, decoration: const InputDecoration(labelText: 'Motif *')),
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
