import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _quotesProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, status) async {
  return ref.watch(apiClientProvider).getQuotes(status: status);
});

final _quoteStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getQuoteStats();
});

class QuotesTab extends ConsumerStatefulWidget {
  const QuotesTab({super.key});

  @override
  ConsumerState<QuotesTab> createState() => _QuotesTabState();
}

class _QuotesTabState extends ConsumerState<QuotesTab> {
  String? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final quotesAsync = ref.watch(_quotesProvider(_statusFilter));
    final statsAsync = ref.watch(_quoteStatsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateQuote(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau devis'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Stats + filtre
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                statsAsync.when(
                  loading: () => const SizedBox(),
                  error: (e, _) => const SizedBox(),
                  data: (s) => Row(
                    children: [
                      _StatChip('Total', '${s['total'] ?? 0}', Colors.grey),
                      const SizedBox(width: 8),
                      _StatChip('Acceptés', '${s['accepted'] ?? 0}', AppColors.positive),
                      const SizedBox(width: 8),
                      _StatChip('Taux conv.', '${((s['conversionRate'] as num?)?.toDouble() ?? 0).toStringAsFixed(0)}%', AppColors.primary),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [null, 'DRAFT', 'SENT', 'ACCEPTED', 'REJECTED', 'EXPIRED'].map((s) => Padding(
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
                const SizedBox(height: 4),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_quotesProvider(_statusFilter));
                ref.invalidate(_quoteStatsProvider);
              },
              child: quotesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
                data: (quotes) => quotes.isEmpty
                    ? _EmptyQuotes(onAdd: () => _showCreateQuote(context))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: quotes.length,
                        separatorBuilder: (_, i) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _QuoteCard(
                          quote: quotes[i] as Map<String, dynamic>,
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
      switch (action) {
        case 'send':    { await api.sendQuote(id); }
        case 'accept':  { await api.acceptQuote(id); }
        case 'reject':  { await api.rejectQuote(id); }
        case 'convert': { await api.convertQuoteToInvoice(id); }
      }
      ref.invalidate(_quotesProvider(_statusFilter));
      ref.invalidate(_quoteStatsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative),
        );
      }
    }
  }

  void _showCreateQuote(BuildContext context) {
    showDialog(context: context, builder: (_) => _CreateQuoteDialog(
      onCreated: () {
        ref.invalidate(_quotesProvider(_statusFilter));
        ref.invalidate(_quoteStatsProvider);
      },
    ));
  }
}

class _QuoteCard extends StatelessWidget {
  final Map<String, dynamic> quote;
  final void Function(String action, String id) onAction;
  const _QuoteCard({required this.quote, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final id = quote['id'] as String;
    final number = quote['number'] as String? ?? '—';
    final status = quote['status'] as String? ?? 'DRAFT';
    final tiersName = (quote['tiers'] as Map?)?['name'] as String? ?? '—';
    final totalTTC = (quote['totalTTC'] as num?)?.toDouble() ?? 0;
    final validUntil = quote['validUntil'] as String?;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 8),
                  _QuoteStatusBadge(status),
                ]),
                const SizedBox(height: 4),
                Text(tiersName, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                if (validUntil != null)
                  Text('Valide jusqu\'au ${Fmt.date(DateTime.tryParse(validUntil) ?? DateTime.now())}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            )),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(Fmt.currency(totalTTC), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 4),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 18),
                  onSelected: (a) => onAction(a, id),
                  itemBuilder: (_) => [
                    if (status == 'DRAFT') const PopupMenuItem(value: 'send', child: Text('Envoyer au client')),
                    if (status == 'SENT') ...[
                      const PopupMenuItem(value: 'accept', child: Text('Marquer accepté')),
                      const PopupMenuItem(value: 'reject', child: Text('Marquer rejeté')),
                    ],
                    if (status == 'ACCEPTED') const PopupMenuItem(value: 'convert', child: Text('Convertir en facture')),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteStatusBadge extends StatelessWidget {
  final String status;
  const _QuoteStatusBadge(this.status);

  Color get _color => switch (status) {
    'ACCEPTED' => AppColors.positive,
    'REJECTED' => AppColors.negative,
    'SENT' => AppColors.primary,
    'EXPIRED' => Colors.grey,
    _ => AppColors.warning,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(fontSize: 10, color: _color, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
      ]),
    );
  }
}

class _CreateQuoteDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateQuoteDialog({required this.onCreated});

  @override
  ConsumerState<_CreateQuoteDialog> createState() => _CreateQuoteDialogState();
}

class _CreateQuoteDialogState extends ConsumerState<_CreateQuoteDialog> {
  final _noteCtrl = TextEditingController();
  String? _tiersId;
  String? _tiersName;
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _pickTiers() async {
    final customers = await ref.read(apiClientProvider).getCustomers(type: 'CLIENT');
    if (!mounted) return;
    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _PickerDialog(title: 'Choisir un client', items: customers.cast()),
    );
    if (picked != null) setState(() { _tiersId = picked['id'] as String; _tiersName = picked['name'] as String? ?? '—'; });
  }

  Future<void> _submit() async {
    if (_tiersId == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createQuote({
        'tiersId': _tiersId,
        'validUntil': _validUntil.toIso8601String().substring(0, 10),
        if (_noteCtrl.text.isNotEmpty) 'notes': _noteCtrl.text.trim(),
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
      title: const Text('Nouveau devis', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: _pickTiers,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Client', prefixIcon: Icon(Icons.person_outline, size: 18)),
                child: Text(_tiersName ?? 'Sélectionner un client', style: TextStyle(color: _tiersId == null ? Colors.grey : null)),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _validUntil, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _validUntil = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Valide jusqu\'au', prefixIcon: Icon(Icons.calendar_today_outlined, size: 18)),
                child: Text(Fmt.date(_validUntil)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _noteCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes (optionnel)')),
            if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
          ],
        ),
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

class _PickerDialog extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  const _PickerDialog({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: 360, height: 300,
        child: ListView.separated(
          itemCount: items.length,
          separatorBuilder: (_, i) => const Divider(height: 1),
          itemBuilder: (_, i) => ListTile(
            title: Text(items[i]['name'] as String? ?? '—', style: const TextStyle(fontSize: 14)),
            subtitle: Text(items[i]['code'] as String? ?? '', style: const TextStyle(fontSize: 12)),
            onTap: () => Navigator.pop(context, items[i]),
          ),
        ),
      ),
    );
  }
}

class _EmptyQuotes extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyQuotes({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('Aucun devis', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer un devis')),
    ]));
  }
}
