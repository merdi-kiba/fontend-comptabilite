import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _allFilterProvider = StateProvider.autoDispose<({String? status, String? entityType})>(
    (ref) => (status: null, entityType: null));

final _allProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ({String? status, String? entityType})>((ref, filter) async {
  return ref.watch(apiClientProvider).getAllApprovals(status: filter.status, entityType: filter.entityType);
});

class AllRequestsTab extends ConsumerWidget {
  const AllRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(_allFilterProvider);
    final requests = ref.watch(_allProvider(filter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        _Filters(filter: filter, onChanged: (f) => ref.read(_allFilterProvider.notifier).state = f),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(_allProvider(filter).future),
            child: requests.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (list) => list.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.history_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucune demande d\'approbation', style: TextStyle(color: Colors.grey[500])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _RequestRow(
                        request: list[i] as Map<String, dynamic>,
                        onHistory: () => _showHistory(context, ref, (list[i] as Map)['requestId'] as String? ?? (list[i] as Map)['id'] as String? ?? ''),
                      ),
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  void _showHistory(BuildContext context, WidgetRef ref, String requestId) {
    if (requestId.isEmpty) return;
    showDialog(context: context, builder: (_) => _HistoryDialog(requestId: requestId));
  }
}

// ── Filters ───────────────────────────────────────────────────────────────────

class _Filters extends StatelessWidget {
  final ({String? status, String? entityType}) filter;
  final void Function(({String? status, String? entityType})) onChanged;
  const _Filters({required this.filter, required this.onChanged});

  static const _statuses = [null, 'PENDING', 'APPROVED', 'REJECTED', 'CANCELLED'];
  static const _statusLabels = ['Tous statuts', 'En attente', 'Approuvé', 'Rejeté', 'Annulé'];
  static const _types = [null, 'PO', 'EXPENSE', 'LEAVE', 'INVOICE', 'PAYMENT'];
  static const _typeLabels = ['Tous types', 'BC', 'Frais', 'Congé', 'Facture', 'Paiement'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        Expanded(child: DropdownButton<String?>(
          isExpanded: true,
          value: filter.status,
          underline: const SizedBox(),
          items: List.generate(_statuses.length, (i) =>
            DropdownMenuItem(value: _statuses[i], child: Text(_statusLabels[i], style: const TextStyle(fontSize: 13)))),
          onChanged: (v) => onChanged((status: v, entityType: filter.entityType)),
        )),
        const SizedBox(width: 12),
        Expanded(child: DropdownButton<String?>(
          isExpanded: true,
          value: filter.entityType,
          underline: const SizedBox(),
          items: List.generate(_types.length, (i) =>
            DropdownMenuItem(value: _types[i], child: Text(_typeLabels[i], style: const TextStyle(fontSize: 13)))),
          onChanged: (v) => onChanged((status: filter.status, entityType: v)),
        )),
      ]),
    );
  }
}

// ── Request row ───────────────────────────────────────────────────────────────

class _RequestRow extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onHistory;
  const _RequestRow({required this.request, required this.onHistory});

  Color _statusColor(String s) {
    switch (s) {
      case 'APPROVED': return AppColors.positive;
      case 'REJECTED': return AppColors.negative;
      case 'PENDING': return AppColors.warning;
      case 'CANCELLED': return AppColors.neutral;
      default: return AppColors.neutral;
    }
  }

  String _statusLabel(String s) {
    const m = {'PENDING': 'En attente', 'APPROVED': 'Approuvé', 'REJECTED': 'Rejeté', 'CANCELLED': 'Annulé'};
    return m[s] ?? s;
  }

  @override
  Widget build(BuildContext context) {
    final entityType = request['entityType'] as String? ?? '—';
    final entityRef = request['entityRef'] as String? ?? request['entityId'] as String? ?? '—';
    final amount = (request['amount'] as num?)?.toDouble() ?? 0;
    final requestedBy = request['requestedBy'] as String? ?? '—';
    final status = request['status'] as String? ?? 'PENDING';
    final color = _statusColor(status);
    final workflow = request['workflow'] as String? ?? (request['workflowName'] as String?) ?? '—';

    return Card(
      child: ListTile(
        leading: Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Center(child: Text(entityType.length > 3 ? entityType.substring(0, 3) : entityType,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)))),
        title: Row(children: [
          Expanded(child: Text('$entityRef · $workflow', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(_statusLabel(status), style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
        subtitle: Text('$requestedBy${amount > 0 ? ' · ${Fmt.compact(amount)} CDF' : ''}',
          style: const TextStyle(fontSize: 11)),
        trailing: IconButton(icon: const Icon(Icons.history_outlined, size: 18), onPressed: onHistory, tooltip: 'Historique'),
      ),
    );
  }
}

// ── History dialog (reused pattern) ──────────────────────────────────────────

class _HistoryDialog extends ConsumerStatefulWidget {
  final String requestId;
  const _HistoryDialog({required this.requestId});

  @override
  ConsumerState<_HistoryDialog> createState() => _HistoryDialogState();
}

class _HistoryDialogState extends ConsumerState<_HistoryDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).getApprovalHistory(widget.requestId);
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final decisions = _data?['decisions'] as List? ?? [];
    final status = _data?['status'] as String? ?? '—';
    final entityRef = _data?['entityRef'] as String? ?? '—';

    return AlertDialog(
      title: Text('Historique — $entityRef', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 480, height: 340,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
                  child: Text('Statut final : $status', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: decisions.isEmpty
                      ? Center(child: Text('Aucune décision', style: TextStyle(color: Colors.grey[500])))
                      : ListView.separated(
                          itemCount: decisions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = decisions[i] as Map<String, dynamic>;
                            final dec = d['decision'] as String? ?? '—';
                            final isOk = dec == 'APPROVED';
                            return ListTile(
                              dense: true,
                              leading: Icon(isOk ? Icons.check_circle_outline : Icons.cancel_outlined,
                                color: isOk ? AppColors.positive : AppColors.negative, size: 18),
                              title: Text('Étape ${d['step']} · ${d['decidedBy'] ?? '—'}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              subtitle: (d['comment'] as String? ?? '').isNotEmpty
                                  ? Text('"${d['comment']}"', style: TextStyle(fontSize: 11, color: Colors.grey[600]))
                                  : null,
                              trailing: Text(
                                (d['decidedAt'] as String? ?? '').substring(0, 10.clamp(0, (d['decidedAt'] as String? ?? '').length)),
                                style: const TextStyle(fontSize: 11)),
                            );
                          },
                        ),
                ),
              ]),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }
}
