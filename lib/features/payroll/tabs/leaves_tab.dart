import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _leavesProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) async {
  return ref.watch(apiClientProvider).getLeaveRequests(status: status);
});

final _leaveFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

class LeavesTab extends ConsumerWidget {
  const LeavesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_leaveFilterProvider);
    final leaves = ref.watch(_leavesProvider(filter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showRequest(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Demande de congé'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(children: [
        _LeaveFilter(current: filter, onChanged: (s) => ref.read(_leaveFilterProvider.notifier).state = s),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(_leavesProvider(filter).future),
            child: leaves.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (list) => list.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.beach_access_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucune demande de congé', style: TextStyle(color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final l = list[i] as Map<String, dynamic>;
                        return _LeaveCard(
                          leave: l,
                          onApprove: l['status'] == 'PENDING'
                              ? () => _action(context, ref, filter, () => ref.read(apiClientProvider).approveLeave(l['id'] as String))
                              : null,
                          onReject: l['status'] == 'PENDING'
                              ? () => _showReject(context, ref, filter, l['id'] as String)
                              : null,
                          onBalances: () => _showBalances(context, ref, l),
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
      ref.invalidate(_leavesProvider(filter));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opération effectuée'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  void _showReject(BuildContext context, WidgetRef ref, String? filter, String id) {
    showDialog(context: context, builder: (_) => _RejectDialog(
      onConfirm: (reason) => _action(context, ref, filter, () => ref.read(apiClientProvider).rejectLeave(id, reason)),
    ));
  }

  void _showRequest(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _RequestLeaveDialog(onCreated: () => ref.invalidate(_leavesProvider(ref.read(_leaveFilterProvider)))));
  }

  void _showBalances(BuildContext context, WidgetRef ref, Map<String, dynamic> leave) {
    final empId = leave['employeeId'] as String?;
    if (empId == null) return;
    showDialog(context: context, builder: (_) => _BalancesDialog(employeeId: empId));
  }
}

// ── Filter ────────────────────────────────────────────────────────────────────

class _LeaveFilter extends StatelessWidget {
  final String? current;
  final void Function(String?) onChanged;
  const _LeaveFilter({required this.current, required this.onChanged});

  static const _statuses = [null, 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];
  static const _labels = ['Tous', 'En attente', 'Approuvé', 'Rejeté', 'Annulé'];

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

// ── Leave card ────────────────────────────────────────────────────────────────

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback onBalances;
  const _LeaveCard({required this.leave, required this.onApprove, required this.onReject, required this.onBalances});

  Color _statusColor(String s) {
    switch (s) {
      case 'APPROVED': return AppColors.positive;
      case 'REJECTED': case 'CANCELLED': return AppColors.negative;
      case 'PENDING': return AppColors.warning;
      default: return AppColors.neutral;
    }
  }

  String _typeLabel(String t) {
    const m = {'ANNUAL': 'Annuel', 'SICK': 'Maladie', 'MATERNITY': 'Maternité', 'PATERNITY': 'Paternité'};
    return m[t] ?? t;
  }

  @override
  Widget build(BuildContext context) {
    final status = leave['status'] as String? ?? 'PENDING';
    final empName = leave['employeeName'] as String? ?? '—';
    final type = leave['type'] as String? ?? 'ANNUAL';
    final days = leave['days'] as int? ?? 0;
    final start = (leave['startDate'] as String? ?? '').substring(0, 10.clamp(0, (leave['startDate'] as String? ?? '').length));
    final end = (leave['endDate'] as String? ?? '').substring(0, 10.clamp(0, (leave['endDate'] as String? ?? '').length));
    final reason = leave['reason'] as String? ?? '';
    final color = _statusColor(status);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.beach_access_outlined, color: color, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(empName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text('${_typeLabel(type)} · $days jour(s) · $start → $end', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Text(status, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reason, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
          ],
          if (onApprove != null || onReject != null) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton.icon(onPressed: onBalances, icon: const Icon(Icons.account_balance_wallet_outlined, size: 14), label: const Text('Soldes')),
              if (onReject != null) TextButton.icon(onPressed: onReject, icon: const Icon(Icons.close, size: 14, color: AppColors.negative), label: const Text('Rejeter', style: TextStyle(color: AppColors.negative))),
              if (onApprove != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(onPressed: onApprove, icon: const Icon(Icons.check, size: 14), label: const Text('Approuver'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6))),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

// ── Request leave dialog ──────────────────────────────────────────────────────

class _RequestLeaveDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _RequestLeaveDialog({required this.onCreated});

  @override
  ConsumerState<_RequestLeaveDialog> createState() => _RequestLeaveDialogState();
}

class _RequestLeaveDialogState extends ConsumerState<_RequestLeaveDialog> {
  List<dynamic> _employees = [];
  String? _selectedEmpId;
  String _type = 'ANNUAL';
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  DateTime _end = DateTime.now().add(const Duration(days: 14));
  final _reasonCtrl = TextEditingController();
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  int get _days => _end.difference(_start).inDays + 1;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() { _reasonCtrl.dispose(); super.dispose(); }

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
    if (_selectedEmpId == null) return;
    setState(() { _submitting = true; _error = null; });
    try {
      await ref.read(apiClientProvider).requestLeave(_selectedEmpId!, {
        'type': _type,
        'startDate': _start.toIso8601String().substring(0, 10),
        'endDate': _end.toIso8601String().substring(0, 10),
        'days': _days,
        if (_reasonCtrl.text.isNotEmpty) 'reason': _reasonCtrl.text.trim(),
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
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Demande de congé', style: TextStyle(fontWeight: FontWeight.w700)),
    content: SizedBox(width: 400, child: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Employé *'),
              initialValue: _selectedEmpId,
              items: _employees.map((e) {
                final m = e as Map<String, dynamic>;
                return DropdownMenuItem<String>(value: m['id'] as String,
                  child: Text('${m['firstName']} ${m['lastName']}'.trim()));
              }).toList(),
              onChanged: (v) => setState(() => _selectedEmpId = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Type de congé'),
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'ANNUAL', child: Text('Annuel (18j/an)')),
                DropdownMenuItem(value: 'SICK', child: Text('Maladie (30j/an)')),
                DropdownMenuItem(value: 'MATERNITY', child: Text('Maternité (98j)')),
                DropdownMenuItem(value: 'PATERNITY', child: Text('Paternité (5j)')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _datePicker('Du', _start, (d) => setState(() => _start = d))),
              const SizedBox(width: 10),
              Expanded(child: _datePicker('Au', _end, (d) => setState(() => _end = d))),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('$_days j.', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 10),
            TextFormField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: 'Motif')),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
          ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      ElevatedButton(onPressed: _submitting ? null : _submit,
        child: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Soumettre')),
    ],
  );

  Widget _datePicker(String label, DateTime date, void Function(DateTime) onPick) => InkWell(
    onTap: () async {
      final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2030));
      if (d != null) onPick(d);
    },
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, isDense: true),
      child: Text(date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 13)),
    ),
  );
}

// ── Balances dialog ───────────────────────────────────────────────────────────

class _BalancesDialog extends ConsumerStatefulWidget {
  final String employeeId;
  const _BalancesDialog({required this.employeeId});

  @override
  ConsumerState<_BalancesDialog> createState() => _BalancesDialogState();
}

class _BalancesDialogState extends ConsumerState<_BalancesDialog> {
  List<dynamic> _balances = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).getLeaveBalances(widget.employeeId);
      if (mounted) setState(() { _balances = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Soldes de congés'),
    content: SizedBox(width: 380, height: 280,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _balances.isEmpty
              ? const Center(child: Text('Aucun solde initialisé'))
              : ListView(children: _balances.map((b) {
                  final m = b as Map<String, dynamic>;
                  final type = m['type'] as String? ?? '—';
                  final entitled = (m['entitled'] as num?)?.toDouble() ?? 0;
                  final taken = (m['taken'] as num?)?.toDouble() ?? 0;
                  final remaining = (m['remaining'] as num?)?.toDouble() ?? (entitled - taken);
                  return ListTile(
                    dense: true,
                    title: Text(type, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: LinearProgressIndicator(
                      value: entitled > 0 ? (taken / entitled).clamp(0.0, 1.0) : 0,
                      backgroundColor: AppColors.surfaceVariant,
                      color: remaining < 3 ? AppColors.negative : AppColors.positive,
                    ),
                    trailing: Text('${remaining.toStringAsFixed(0)} / ${entitled.toStringAsFixed(0)} j.',
                      style: TextStyle(fontWeight: FontWeight.w700, color: remaining < 3 ? AppColors.negative : null)),
                  );
                }).toList()),
    ),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
  );
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
    title: const Text('Rejeter la demande'),
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
