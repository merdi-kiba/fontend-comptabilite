import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _invoiceDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>(
  (ref, id) => ref.watch(apiClientProvider).getInvoice(id),
);

final _paymentsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>(
  (ref, id) => ref.watch(apiClientProvider).getPayments(id),
);

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(_invoiceDetailProvider(invoiceId));

    return Scaffold(
      backgroundColor: AppColors.surfaceVariant,
      appBar: AppBar(
        title: const Text('Détail facture'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE8ECF0)),
        ),
      ),
      body: invoiceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (inv) => _InvoiceDetail(invoice: inv, ref: ref, onRefresh: () => ref.invalidate(_invoiceDetailProvider(invoiceId))),
      ),
    );
  }
}

class _InvoiceDetail extends StatelessWidget {
  final Map<String, dynamic> invoice;
  final WidgetRef ref;
  final VoidCallback onRefresh;
  const _InvoiceDetail({required this.invoice, required this.ref, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final id = invoice['id'] as String;
    final number = invoice['number'] as String? ?? '—';
    final status = invoice['status'] as String? ?? 'DRAFT';
    final type = invoice['type'] as String? ?? 'FV';
    final tiersName = (invoice['tiers'] as Map?)?['name'] as String? ?? '—';
    final tiersNif = (invoice['tiers'] as Map?)?['nif'] as String? ?? '';
    final totalHT = (invoice['totalHT'] as num?)?.toDouble() ?? 0;
    final totalTVA = (invoice['totalTVA'] as num?)?.toDouble() ?? 0;
    final totalTTC = (invoice['totalTTC'] as num?)?.toDouble() ?? 0;
    final amountPaid = (invoice['amountPaid'] as num?)?.toDouble() ?? 0;
    final outstanding = totalTTC - amountPaid;
    final items = invoice['items'] as List? ?? [];
    final codeDEF = invoice['codeDEFDGI'] as String?;
    final nim = invoice['nim'] as String?;
    final createdAt = invoice['createdAt'] as String? ?? '';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(number, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
                          const SizedBox(height: 4),
                          Text('Type: $type · ${Fmt.date(DateTime.tryParse(createdAt) ?? DateTime.now())}',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      )),
                      _StatusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tiersName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (tiersNif.isNotEmpty) Text('NIF: $tiersNif', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ])),
                  ]),
                  if (codeDEF != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.positive.withValues(alpha: 0.2))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.verified_outlined, color: AppColors.positive, size: 16),
                          const SizedBox(width: 6),
                          const Text('Certifiée DGI', style: TextStyle(color: AppColors.positive, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                        const SizedBox(height: 6),
                        Text('Code DEFDGI: $codeDEF', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                        if (nim != null) Text('NIM: $nim', style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      ]),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Actions DGI
          _ActionsCard(invoice: invoice, onRefresh: onRefresh),
          const SizedBox(height: 12),

          // Lignes de facturation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Articles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 12),
                  ...items.map((item) {
                    final m = item as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(m['name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Qté: ${m['quantity']} × ${Fmt.compact((m['unitPrice'] as num?)?.toDouble() ?? 0)} HT · TVA: ${m['taxGroup']}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        ])),
                        Text(Fmt.currency((m['totalTTC'] as num?)?.toDouble() ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ]),
                    );
                  }),
                  const Divider(),
                  _TotalRow('Total HT', totalHT, isGrey: true),
                  _TotalRow('TVA', totalTVA, isGrey: true),
                  _TotalRow('Total TTC', totalTTC, isBold: true),
                  if (amountPaid > 0) _TotalRow('Encaissé', amountPaid, color: AppColors.positive),
                  if (outstanding > 0) _TotalRow('Restant dû', outstanding, color: AppColors.negative, isBold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Paiements
          _PaymentsSection(invoiceId: id, onRefresh: onRefresh, canAddPayment: status == 'CONFIRMED' || status == 'PARTIALLY_PAID'),
        ],
      ),
    );
  }
}

// ── Actions DGI ───────────────────────────────────────────────────────────────

class _ActionsCard extends ConsumerWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onRefresh;
  const _ActionsCard({required this.invoice, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = invoice['id'] as String;
    final status = invoice['status'] as String? ?? 'DRAFT';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                if (status == 'DRAFT')
                  _ActionBtn('Soumettre DGI', Icons.send_outlined, AppColors.primary, () async {
                    await ref.read(apiClientProvider).submitInvoice(id);
                    onRefresh();
                  }),
                if (status == 'PENDING_DGI')
                  _ActionBtn('Confirmer', Icons.verified_outlined, AppColors.positive, () async {
                    await ref.read(apiClientProvider).confirmInvoice(id);
                    onRefresh();
                  }),
                if (status == 'CONFIRMED' || status == 'PARTIALLY_PAID')
                  _ActionBtn('Envoyer email', Icons.email_outlined, Colors.blue, () async {
                    await ref.read(apiClientProvider).sendInvoiceMail(id);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email envoyé')));
                  }),
                if (status == 'CONFIRMED' || status == 'PARTIALLY_PAID')
                  _ActionBtn('Relance email', Icons.notification_important_outlined, AppColors.warning, () async {
                    await ref.read(apiClientProvider).sendReminderMail(id);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Relance envoyée')));
                  }),
                if (status != 'CANCELLED' && status != 'PAID')
                  _ActionBtn('Annuler', Icons.cancel_outlined, AppColors.negative, () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Annuler la facture ?'),
                        content: const Text('Cette action révoque la certification DGI et génère une extourne comptable.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
                            child: const Text('Annuler la facture'),
                          ),
                        ],
                      ),
                    ) ?? false;
                    if (ok) { await ref.read(apiClientProvider).cancelInvoice(id); onRefresh(); }
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;
  const _ActionBtn(this.label, this.icon, this.color, this.onTap);

  @override
  State<_ActionBtn> createState() => _ActionBtnState();
}

class _ActionBtnState extends State<_ActionBtn> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _loading ? null : () async {
        setState(() => _loading = true);
        try { await widget.onTap(); } catch (e) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
        } finally { if (mounted) setState(() => _loading = false); }
      },
      icon: _loading
          ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: widget.color))
          : Icon(widget.icon, size: 16, color: widget.color),
      label: Text(widget.label, style: TextStyle(color: widget.color, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: widget.color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}

// ── Paiements ─────────────────────────────────────────────────────────────────

class _PaymentsSection extends ConsumerWidget {
  final String invoiceId;
  final VoidCallback onRefresh;
  final bool canAddPayment;
  const _PaymentsSection({required this.invoiceId, required this.onRefresh, required this.canAddPayment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(_paymentsProvider(invoiceId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Paiements', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              if (canAddPayment)
                ElevatedButton.icon(
                  onPressed: () => _showAddPayment(context, ref),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Encaisser', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            paymentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(parseError(e), style: const TextStyle(color: AppColors.negative, fontSize: 12)),
              data: (payments) => payments.isEmpty
                  ? Center(child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Aucun paiement enregistré', style: TextStyle(color: Colors.grey[500])),
                    ))
                  : Column(children: payments.map((p) => _PaymentRow(
                      payment: p as Map<String, dynamic>,
                      onDelete: () async {
                        await ref.read(apiClientProvider).deletePayment(invoiceId, p['id'] as String);
                        ref.invalidate(_paymentsProvider(invoiceId));
                        onRefresh();
                      },
                    )).toList()),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPayment(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => _AddPaymentDialog(
        invoiceId: invoiceId,
        onAdded: () {
          ref.invalidate(_paymentsProvider(invoiceId));
          onRefresh();
        },
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final Map<String, dynamic> payment;
  final VoidCallback onDelete;
  const _PaymentRow({required this.payment, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final method = payment['method'] as String? ?? '—';
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final ref = payment['reference'] as String? ?? '';
    final date = payment['createdAt'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.payments_outlined, color: AppColors.positive, size: 16)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(method, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text('${ref.isNotEmpty ? ref : "—"} · ${date.isNotEmpty ? Fmt.date(DateTime.tryParse(date) ?? DateTime.now()) : ""}',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
        Text(Fmt.currency(amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.positive)),
        IconButton(icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey), onPressed: onDelete, padding: EdgeInsets.zero),
      ]),
    );
  }
}

class _AddPaymentDialog extends ConsumerStatefulWidget {
  final String invoiceId;
  final VoidCallback onAdded;
  const _AddPaymentDialog({required this.invoiceId, required this.onAdded});

  @override
  ConsumerState<_AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends ConsumerState<_AddPaymentDialog> {
  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _method = 'CASH';
  bool _loading = false;
  String? _error;

  static const _methods = ['CASH', 'VIREMENT', 'MOBILE_MONEY', 'CHEQUE', 'CARTE'];

  @override
  void dispose() { _amountCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountCtrl.text);
    if (amount == null || amount <= 0) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).addPayment(widget.invoiceId, {
        'method': _method,
        'amount': amount,
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
      title: const Text('Enregistrer un paiement', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 360,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Mode de paiement'),
            items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _method = v!),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant (CDF)', suffixText: 'CDF'),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'Référence (optionnel)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Enregistrer'),
        ),
      ],
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  Color get _color {
    switch (status) {
      case 'CONFIRMED': return AppColors.positive;
      case 'PAID': return const Color(0xFF0EA5E9);
      case 'PARTIALLY_PAID': return AppColors.warning;
      case 'CANCELLED': return Colors.grey;
      case 'PENDING_DGI': return AppColors.primary;
      default: return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: _color.withValues(alpha: 0.3))),
      child: Text(status, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final bool isGrey;
  final Color? color;
  const _TotalRow(this.label, this.value, {this.isBold = false, this.isGrey = false, this.color});

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? (isGrey ? Colors.grey[600]! : const Color(0xFF1A1D23));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: textColor, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal))),
        Text(Fmt.currency(value), style: TextStyle(fontSize: 13, color: textColor, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
      ]),
    );
  }
}
