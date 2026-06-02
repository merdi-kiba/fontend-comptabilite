import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _pendingProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getMyPendingApprovals();
});

class PendingTab extends ConsumerWidget {
  const PendingTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_pendingProvider.future),
        child: pending.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Aucune approbation en attente', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Tout est à jour pour votre rôle', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ]))
              : Column(children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Text('${list.length} en attente de votre décision',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.warning)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _PendingCard(
                        request: list[i] as Map<String, dynamic>,
                        onApprove: () => _decide(context, ref, (list[i] as Map)['requestId'] as String, true),
                        onReject: () => _showReject(context, ref, (list[i] as Map)['requestId'] as String),
                        onHistory: () => _showHistory(context, ref, (list[i] as Map)['requestId'] as String),
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, String requestId, bool approve) async {
    try {
      if (approve) {
        await ref.read(apiClientProvider).approveRequest(requestId, comment: 'Approuvé');
      }
      ref.invalidate(_pendingProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(approve ? 'Approbation enregistrée' : 'Rejet enregistré'),
          backgroundColor: approve ? AppColors.positive : AppColors.negative));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
      }
    }
  }

  void _showReject(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(context: context, builder: (_) => _RejectDialog(
      onConfirm: (comment) async {
        try {
          await ref.read(apiClientProvider).rejectRequest(requestId, comment);
          ref.invalidate(_pendingProvider);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demande rejetée'), backgroundColor: AppColors.negative));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
          }
        }
      },
    ));
  }

  void _showHistory(BuildContext context, WidgetRef ref, String requestId) {
    showDialog(context: context, builder: (_) => _HistoryDialog(requestId: requestId));
  }
}

// ── Pending card ──────────────────────────────────────────────────────────────

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onHistory;
  const _PendingCard({required this.request, required this.onApprove, required this.onReject, required this.onHistory});

  IconData _entityIcon(String type) {
    switch (type) {
      case 'PO': return Icons.shopping_cart_outlined;
      case 'EXPENSE': return Icons.receipt_outlined;
      case 'LEAVE': return Icons.beach_access_outlined;
      case 'INVOICE': return Icons.receipt_long_outlined;
      case 'PAYMENT': return Icons.payments_outlined;
      default: return Icons.assignment_outlined;
    }
  }

  String _entityLabel(String type) {
    const m = {'PO': 'Bon de commande', 'EXPENSE': 'Note de frais', 'LEAVE': 'Congé', 'INVOICE': 'Facture', 'PAYMENT': 'Paiement'};
    return m[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    final entityType = request['entityType'] as String? ?? '—';
    final entityRef = request['entityRef'] as String? ?? request['entityId'] as String? ?? '—';
    final amount = (request['amount'] as num?)?.toDouble() ?? 0;
    final requestedBy = request['requestedBy'] as String? ?? '—';
    final requestedAt = (request['requestedAt'] as String? ?? '').substring(0, 10.clamp(0, (request['requestedAt'] as String? ?? '').length));
    final stepLabel = request['stepLabel'] as String? ?? request['workflow'] as String? ?? '—';
    final currentStep = request['currentStep'] as int? ?? 1;
    final totalSteps = request['totalSteps'] as int? ?? 1;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE8ECF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(_entityIcon(entityType), color: AppColors.warning, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_entityLabel(entityType)} · $entityRef',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Demandé par $requestedBy le $requestedAt',
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ])),
            if (amount > 0)
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(Fmt.compact(amount), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text('CDF', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ]),
          ]),
          const SizedBox(height: 10),
          // Step indicator
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
              child: Text('Étape $currentStep/$totalSteps · $stepLabel',
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
            const Spacer(),
            TextButton.icon(onPressed: onHistory, icon: const Icon(Icons.history_outlined, size: 14), label: const Text('Historique'),
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), foregroundColor: Colors.grey[600])),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close, size: 16, color: AppColors.negative),
              label: const Text('Rejeter', style: TextStyle(color: AppColors.negative)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.negative), padding: const EdgeInsets.symmetric(vertical: 10)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: onApprove,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Approuver'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(vertical: 10)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ── History dialog ────────────────────────────────────────────────────────────

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
    final isApproved = status == 'APPROVED';

    return AlertDialog(
      title: Text('Historique — $entityRef', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 480, height: 340,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (isApproved ? AppColors.positive : (status == 'REJECTED' ? AppColors.negative : AppColors.warning)).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(isApproved ? Icons.check_circle_outline : Icons.pending_outlined,
                      size: 16, color: isApproved ? AppColors.positive : AppColors.warning),
                    const SizedBox(width: 8),
                    Text('Statut : $status', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ]),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: decisions.isEmpty
                      ? Center(child: Text('Aucune décision encore', style: TextStyle(color: Colors.grey[500])))
                      : ListView.separated(
                          itemCount: decisions.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final d = decisions[i] as Map<String, dynamic>;
                            final decision = d['decision'] as String? ?? '—';
                            final isOk = decision == 'APPROVED';
                            return ListTile(
                              dense: true,
                              leading: Icon(isOk ? Icons.check_circle_outline : Icons.cancel_outlined,
                                color: isOk ? AppColors.positive : AppColors.negative, size: 18),
                              title: Text('Étape ${d['step']} · ${d['label'] ?? d['decidedBy'] ?? '—'}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(d['decidedBy'] as String? ?? '—', style: const TextStyle(fontSize: 11)),
                                if ((d['comment'] as String? ?? '').isNotEmpty)
                                  Text('"${d['comment']}"', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
                              ]),
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
    content: TextFormField(controller: _ctrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Motif du rejet *')),
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
