import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _contractsProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) async {
  return ref.watch(apiClientProvider).getContracts(status: status);
});

class ContractsTab extends ConsumerStatefulWidget {
  const ContractsTab({super.key});

  @override
  ConsumerState<ContractsTab> createState() => _ContractsTabState();
}

class _ContractsTabState extends ConsumerState<ContractsTab> {
  String? _statusFilter = 'ACTIVE';

  @override
  Widget build(BuildContext context) {
    final contractsAsync = ref.watch(_contractsProvider(_statusFilter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateContract(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau contrat'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [null, 'ACTIVE', 'PAUSED', 'TERMINATED'].map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s ?? 'Tous', style: const TextStyle(fontSize: 12)),
                    selected: _statusFilter == s,
                    onSelected: (_) => setState(() => _statusFilter = s),
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                )).toList(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(_contractsProvider(_statusFilter).future),
              child: contractsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
                data: (contracts) => contracts.isEmpty
                    ? _EmptyContracts(onAdd: () => _showCreateContract(context))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: contracts.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _ContractCard(
                          contract: contracts[i] as Map<String, dynamic>,
                          onAction: (action, id) => _handleAction(context, action, id),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(BuildContext context, String action, String id) async {
    final api = ref.read(apiClientProvider);
    try {
      if (action == 'bill')      { await api.billContractNow(id); }
      else if (action == 'pause')     { await api.pauseContract(id); }
      else if (action == 'resume')    { await api.resumeContract(id); }
      else if (action == 'terminate') { await api.terminateContract(id); }
      ref.invalidate(_contractsProvider(_statusFilter));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action effectuée')));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative),
        );
      }
    }
  }

  void _showCreateContract(BuildContext context) {
    showDialog(context: context, builder: (_) => _CreateContractDialog(
      onCreated: () => ref.invalidate(_contractsProvider(_statusFilter)),
    ));
  }
}

class _ContractCard extends StatelessWidget {
  final Map<String, dynamic> contract;
  final void Function(String action, String id) onAction;
  const _ContractCard({required this.contract, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final id = contract['id'] as String;
    final name = contract['name'] as String? ?? '—';
    final status = contract['status'] as String? ?? 'ACTIVE';
    final tiersName = (contract['tiers'] as Map?)?['name'] as String? ?? '—';
    final freq = contract['frequency'] as String? ?? '—';
    final nextBilling = contract['nextBillingAt'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: _statusColor(status).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.repeat_outlined, color: _statusColor(status), size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text(tiersName, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Row(children: [
                  _Badge(freq, AppColors.primary),
                  const SizedBox(width: 6),
                  _Badge(status, _statusColor(status)),
                ]),
                if (nextBilling != null)
                  Text('Prochaine facturation: ${Fmt.date(DateTime.tryParse(nextBilling) ?? DateTime.now())}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ]),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (a) => onAction(a, id),
              itemBuilder: (_) => [
                if (status == 'ACTIVE') ...[
                  const PopupMenuItem(value: 'bill', child: Text('Facturer maintenant')),
                  const PopupMenuItem(value: 'pause', child: Text('Mettre en pause')),
                ],
                if (status == 'PAUSED') const PopupMenuItem(value: 'resume', child: Text('Reprendre')),
                if (status != 'TERMINATED') const PopupMenuItem(
                  value: 'terminate',
                  child: Text('Résilier', style: TextStyle(color: AppColors.negative)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'ACTIVE' => AppColors.positive,
    'PAUSED' => AppColors.warning,
    'TERMINATED' => Colors.grey,
    _ => AppColors.primary,
  };
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );
}

class _CreateContractDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateContractDialog({required this.onCreated});

  @override
  ConsumerState<_CreateContractDialog> createState() => _CreateContractDialogState();
}

class _CreateContractDialogState extends ConsumerState<_CreateContractDialog> {
  final _nameCtrl = TextEditingController();
  String? _tiersId;
  String? _tiersName;
  String _frequency = 'MONTHLY';
  DateTime _nextBilling = DateTime.now().add(const Duration(days: 30));
  bool _autoSubmit = false;
  bool _loading = false;
  String? _error;

  static const _freqs = ['WEEKLY', 'MONTHLY', 'QUARTERLY', 'YEARLY'];

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _pickTiers() async {
    final customers = await ref.read(apiClientProvider).getCustomers(type: 'CLIENT');
    if (!mounted) return;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _TiersPickerDialog(customers: customers.cast()),
    );
    if (picked != null) setState(() { _tiersId = picked['id'] as String; _tiersName = picked['name'] as String?; });
  }

  Future<void> _submit() async {
    if (_tiersId == null || _nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createContract({
        'tiersId': _tiersId,
        'name': _nameCtrl.text.trim(),
        'frequency': _frequency,
        'nextBillingAt': _nextBilling.toIso8601String().substring(0, 10),
        'startDate': DateTime.now().toIso8601String().substring(0, 10),
        'autoSubmit': _autoSubmit,
        'items': [],
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
      title: const Text('Nouveau contrat récurrent', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du contrat *')),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickTiers,
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Client *', prefixIcon: Icon(Icons.person_outline, size: 18)),
              child: Text(_tiersName ?? 'Sélectionner un client', style: TextStyle(color: _tiersId == null ? Colors.grey : null)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Fréquence'),
            items: _freqs.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
            onChanged: (v) => setState(() => _frequency = v!),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _nextBilling, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
              if (d != null) setState(() => _nextBilling = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Première facturation', prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
              child: Text(Fmt.date(_nextBilling)),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _autoSubmit,
            onChanged: (v) => setState(() => _autoSubmit = v),
            title: const Text('Soumettre automatiquement à la DGI', style: TextStyle(fontSize: 13)),
            contentPadding: EdgeInsets.zero,
          ),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer'),
        ),
      ],
    );
  }
}

class _TiersPickerDialog extends StatelessWidget {
  final List<Map<String, dynamic>> customers;
  const _TiersPickerDialog({required this.customers});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Choisir un client'),
      content: SizedBox(
        width: 360, height: 300,
        child: ListView.separated(
          itemCount: customers.length,
          separatorBuilder: (_, i) => const Divider(height: 1),
          itemBuilder: (_, i) => ListTile(
            title: Text(customers[i]['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            subtitle: Text(customers[i]['code'] as String? ?? '', style: const TextStyle(fontSize: 12)),
            onTap: () => Navigator.pop(context, customers[i]),
          ),
        ),
      ),
    );
  }
}

class _EmptyContracts extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyContracts({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.repeat_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('Aucun contrat récurrent', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer un contrat')),
    ]));
  }
}
