import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _queueStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfQueueStats();
});

class EmcfQueueTab extends ConsumerWidget {
  const EmcfQueueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(_queueStatsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_queueStatsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('File d\'attente DGI', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Gestion des factures en cours de certification', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 20),

            statsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorBanner(parseError(e)),
              data: (stats) => _QueueStats(stats: stats),
            ),

            const SizedBox(height: 20),
            _ManualRetryCard(),
            const SizedBox(height: 16),
            _ResetToDraftCard(),
          ],
        ),
      ),
    );
  }
}

class _QueueStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _QueueStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final waiting = stats['waiting'] as num? ?? 0;
    final active = stats['active'] as num? ?? 0;
    final completed = stats['completed'] as num? ?? 0;
    final failed = stats['failed'] as num? ?? 0;

    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.2,
      children: [
        _StatTile('En attente', '$waiting', AppColors.warning, Icons.hourglass_empty_outlined),
        _StatTile('En traitement', '$active', AppColors.primary, Icons.sync_outlined),
        _StatTile('Complétées', '$completed', AppColors.positive, Icons.check_circle_outline),
        _StatTile('Échecs', '$failed', AppColors.negative, Icons.cancel_outlined),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _StatTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ]),
      ]),
    );
  }
}

class _ManualRetryCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ManualRetryCard> createState() => _ManualRetryCardState();
}

class _ManualRetryCardState extends ConsumerState<_ManualRetryCard> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _msg;
  bool _isError = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.replay_outlined, color: AppColors.warning, size: 18)),
              const SizedBox(width: 12),
              const Text('Relancer une facture en erreur', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _ctrl, decoration: const InputDecoration(labelText: 'UUID de la facture', hintText: 'xxxxxxxx-xxxx-...'))),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _loading ? null : () async {
                  if (_ctrl.text.trim().isEmpty) return;
                  setState(() { _loading = true; _msg = null; });
                  try {
                    await ref.read(apiClientProvider).retryEmcfInvoice(_ctrl.text.trim());
                    setState(() { _msg = 'Facture relancée dans la queue DGI.'; _isError = false; });
                    _ctrl.clear();
                  } catch (e) {
                    setState(() { _msg = parseError(e); _isError = true; });
                  } finally {
                    setState(() => _loading = false);
                  }
                },
                icon: const Icon(Icons.send_outlined, size: 16),
                label: const Text('Retry'),
              ),
            ]),
            if (_msg != null) ...[const SizedBox(height: 8), _Banner(_msg!, _isError)],
          ],
        ),
      ),
    );
  }
}

class _ResetToDraftCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_ResetToDraftCard> createState() => _ResetToDraftCardState();
}

class _ResetToDraftCardState extends ConsumerState<_ResetToDraftCard> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _msg;
  bool _isError = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.undo_outlined, color: AppColors.primary, size: 18)),
              const SizedBox(width: 12),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Remettre en brouillon (DRAFT)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('Pour une facture bloquée en PENDING_DGI ou ERROR', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _ctrl, decoration: const InputDecoration(labelText: 'UUID de la facture'))),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _loading ? null : () async {
                  if (_ctrl.text.trim().isEmpty) return;
                  setState(() { _loading = true; _msg = null; });
                  try {
                    await ref.read(apiClientProvider).resetInvoiceToDraft(_ctrl.text.trim());
                    setState(() { _msg = 'Facture remise en DRAFT.'; _isError = false; });
                    _ctrl.clear();
                  } catch (e) {
                    setState(() { _msg = parseError(e); _isError = true; });
                  } finally {
                    setState(() => _loading = false);
                  }
                },
                icon: const Icon(Icons.undo_outlined, size: 16),
                label: const Text('Reset'),
              ),
            ]),
            if (_msg != null) ...[const SizedBox(height: 8), _Banner(_msg!, _isError)],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final String msg;
  final bool isError;
  const _Banner(this.msg, this.isError);

  @override
  Widget build(BuildContext context) {
    final c = isError ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: c.withValues(alpha: 0.2))),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: c, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: TextStyle(color: c, fontSize: 12))),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String msg;
  const _ErrorBanner(this.msg);

  @override
  Widget build(BuildContext context) => _Banner(msg, true);
}
