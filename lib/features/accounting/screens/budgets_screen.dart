import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _budgetsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getBudgets();
});

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(_budgetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau budget'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_budgetsProvider.future),
        child: budgetsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (budgets) => budgets.isEmpty
              ? _Empty(onAdd: () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: budgets.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _BudgetCard(
                    budget: budgets[i] as Map<String, dynamic>,
                    onApprove: () async {
                      await ref.read(apiClientProvider).approveBudget(budgets[i]['id'] as String);
                      ref.invalidate(_budgetsProvider);
                    },
                    onLock: () async {
                      await ref.read(apiClientProvider).lockBudget(budgets[i]['id'] as String);
                      ref.invalidate(_budgetsProvider);
                    },
                    onVsActual: () => _showVsActual(context, ref, budgets[i]['id'] as String),
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateBudgetDialog(onCreated: () => ref.invalidate(_budgetsProvider)));
  }

  void _showVsActual(BuildContext context, WidgetRef ref, String id) {
    showDialog(context: context, builder: (_) => _VsActualDialog(budgetId: id));
  }
}

class _BudgetCard extends StatelessWidget {
  final Map<String, dynamic> budget;
  final VoidCallback onApprove;
  final VoidCallback onLock;
  final VoidCallback onVsActual;
  const _BudgetCard({required this.budget, required this.onApprove, required this.onLock, required this.onVsActual});

  @override
  Widget build(BuildContext context) {
    final name = budget['name'] as String? ?? '—';
    final status = budget['status'] as String? ?? 'DRAFT';
    final color = switch (status) { 'APPROVED' => AppColors.positive, 'LOCKED' => AppColors.primary, _ => AppColors.warning };

    return Card(
      child: ListTile(
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 20)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700))),
        ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (a) {
            if (a == 'approve') { onApprove(); }
            else if (a == 'lock') { onLock(); }
            else if (a == 'vsactual') { onVsActual(); }
          },
          itemBuilder: (_) => [
            if (status == 'DRAFT') const PopupMenuItem(value: 'approve', child: Text('Approuver')),
            if (status == 'APPROVED') const PopupMenuItem(value: 'lock', child: Text('Verrouiller')),
            const PopupMenuItem(value: 'vsactual', child: Text('Budget vs Réalisé')),
          ],
        ),
      ),
    );
  }
}

class _VsActualDialog extends ConsumerStatefulWidget {
  final String budgetId;
  const _VsActualDialog({required this.budgetId});

  @override
  ConsumerState<_VsActualDialog> createState() => _VsActualDialogState();
}

class _VsActualDialogState extends ConsumerState<_VsActualDialog> {
  Map<String, dynamic>? _data;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getBudgetVsActual(widget.budgetId);
      if (mounted) setState(() => _data = r);
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = _data?['lines'] as List? ?? [];
    return AlertDialog(
      title: const Text('Budget vs Réalisé'),
      content: SizedBox(
        width: 500, height: 400,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(child: DataTable(
                columnSpacing: 12,
                columns: const [
                  DataColumn(label: Text('Compte')),
                  DataColumn(label: Text('Budget')),
                  DataColumn(label: Text('Réalisé')),
                  DataColumn(label: Text('Écart')),
                ],
                rows: lines.map((l) {
                  final m = l as Map<String, dynamic>;
                  final budget = (m['budget'] as num?)?.toDouble() ?? 0;
                  final actual = (m['actual'] as num?)?.toDouble() ?? 0;
                  final gap = actual - budget;
                  return DataRow(cells: [
                    DataCell(Text(m['label'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
                    DataCell(Text(Fmt.compact(budget), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(Fmt.compact(actual), style: const TextStyle(fontSize: 12))),
                    DataCell(Text(Fmt.compact(gap), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: gap <= 0 ? AppColors.positive : AppColors.negative))),
                  ]);
                }).toList(),
              )),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}

class _CreateBudgetDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateBudgetDialog({required this.onCreated});

  @override
  ConsumerState<_CreateBudgetDialog> createState() => _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends ConsumerState<_CreateBudgetDialog> {
  final _nameCtrl = TextEditingController();
  final _fyCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _nameCtrl.dispose(); _fyCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createBudget({
        'name': _nameCtrl.text.trim(),
        if (_fyCtrl.text.isNotEmpty) 'fiscalYearId': _fyCtrl.text.trim(),
        'lines': [],
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
      title: const Text('Nouveau budget', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du budget *')),
        const SizedBox(height: 10),
        TextFormField(controller: _fyCtrl, decoration: const InputDecoration(labelText: 'ID Exercice fiscal')),
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
    Text('Aucun budget', style: TextStyle(color: Colors.grey[600])),
    const SizedBox(height: 8),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer un budget')),
  ]));
}
