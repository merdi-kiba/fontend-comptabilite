import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _mtnTxProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getMobileTransactions(operator: 'MTN');
});

final _airtelTxProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getMobileTransactions(operator: 'AIRTEL');
});

// ── Main tab ─────────────────────────────────────────────────────────────────

class MobileMoneyTab extends ConsumerStatefulWidget {
  const MobileMoneyTab({super.key});

  @override
  ConsumerState<MobileMoneyTab> createState() => _MobileMoneyTabState();
}

class _MobileMoneyTabState extends ConsumerState<MobileMoneyTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.signal_cellular_alt_outlined, size: 16), text: 'MTN MoMo'),
            Tab(icon: Icon(Icons.phone_android_outlined, size: 16), text: 'Airtel Money'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: const [
            _OperatorView(operator: 'MTN'),
            _OperatorView(operator: 'AIRTEL'),
          ],
        ),
      ),
    ]);
  }
}

// ── Operator view (transactions + actions) ────────────────────────────────────

class _OperatorView extends ConsumerWidget {
  final String operator;
  const _OperatorView({required this.operator});

  bool get isMtn => operator == 'MTN';

  Color get opColor => isMtn ? const Color(0xFFF5A623) : const Color(0xFFE02020);
  IconData get opIcon => isMtn ? Icons.signal_cellular_alt_outlined : Icons.phone_android_outlined;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = isMtn
        ? ref.watch(_mtnTxProvider)
        : ref.watch(_airtelTxProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: '${operator}_config',
            onPressed: () => _showConfigDialog(context, ref),
            tooltip: 'Configurer $operator',
            backgroundColor: AppColors.neutral,
            child: const Icon(Icons.settings_outlined, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: '${operator}_pay',
            onPressed: () => _showRequestPaymentDialog(context, ref),
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Collecter'),
            backgroundColor: AppColors.positive,
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: '${operator}_disburse',
            onPressed: () => _showDisburseDialog(context, ref),
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Décaisser'),
            backgroundColor: opColor,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => isMtn
            ? ref.refresh(_mtnTxProvider.future)
            : ref.refresh(_airtelTxProvider.future),
        child: txAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (txs) => txs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(opIcon, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucune transaction $operator', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Configurez $operator puis effectuez une opération', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: txs.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 6),
                  itemBuilder: (_, i) => _TxCard(
                    tx: txs[i] as Map<String, dynamic>,
                    opColor: opColor,
                    onCheckStatus: () => _checkStatus(context, ref, txs[i] as Map<String, dynamic>),
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _checkStatus(BuildContext context, WidgetRef ref, Map<String, dynamic> tx) async {
    final ref_ = tx['internalRef'] as String? ?? tx['reference'] as String? ?? '';
    if (ref_.isEmpty) return;
    try {
      final result = await ref.read(apiClientProvider).getMobileTransactionStatus(ref_);
      if (context.mounted) {
        showDialog(context: context, builder: (_) => AlertDialog(
          title: Text('Statut — $ref_'),
          content: Text('Statut : ${result['status'] ?? '—'}\nMontant : ${result['amount'] ?? '—'}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)),
          backgroundColor: AppColors.negative));
      }
    }
  }

  void _showConfigDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _ConfigDialog(operator: operator));
  }

  void _showRequestPaymentDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _RequestPaymentDialog(
      operator: operator,
      onDone: () => isMtn
          ? ref.invalidate(_mtnTxProvider)
          : ref.invalidate(_airtelTxProvider),
    ));
  }

  void _showDisburseDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _DisburseDialog(
      operator: operator,
      onDone: () => isMtn
          ? ref.invalidate(_mtnTxProvider)
          : ref.invalidate(_airtelTxProvider),
    ));
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final Color opColor;
  final VoidCallback onCheckStatus;
  const _TxCard({required this.tx, required this.opColor, required this.onCheckStatus});

  Color _statusColor(String? s) {
    switch (s?.toUpperCase()) {
      case 'SUCCESS': return AppColors.positive;
      case 'FAILED': return AppColors.negative;
      case 'PENDING': return AppColors.warning;
      default: return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final status = tx['status'] as String? ?? 'PENDING';
    final phone = tx['phone'] as String? ?? '—';
    final ref_ = tx['internalRef'] as String? ?? tx['reference'] as String? ?? '—';
    final desc = tx['description'] as String? ?? '—';
    final statusColor = _statusColor(status);
    final isCredit = (tx['type'] as String?)?.toUpperCase() != 'DISBURSE';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: opColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
              color: isCredit ? AppColors.positive : AppColors.negative, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('$phone · $ref_', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Fmt.currency(amount),
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                color: isCredit ? AppColors.positive : AppColors.negative)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(status, style: TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.w700)),
            ),
          ]),
          if (status.toUpperCase() == 'PENDING')
            IconButton(
              icon: const Icon(Icons.refresh_outlined, size: 16),
              tooltip: 'Vérifier statut',
              onPressed: onCheckStatus,
            ),
        ]),
      ),
    );
  }
}

// ── Config dialog ─────────────────────────────────────────────────────────────

class _ConfigDialog extends ConsumerStatefulWidget {
  final String operator;
  const _ConfigDialog({required this.operator});

  @override
  ConsumerState<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends ConsumerState<_ConfigDialog> {
  final _keyCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  final _subCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  bool get isMtn => widget.operator == 'MTN';

  @override
  void dispose() { _keyCtrl.dispose(); _secretCtrl.dispose(); _subCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = isMtn
          ? {'apiKey': _keyCtrl.text.trim(), 'apiSecret': _secretCtrl.text.trim(), 'subscriptionKey': _subCtrl.text.trim()}
          : {'clientId': _keyCtrl.text.trim(), 'clientSecret': _secretCtrl.text.trim(), 'pin': _subCtrl.text.trim()};
      await ref.read(apiClientProvider).configureMobileMoney(widget.operator, data);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.operator} configuré avec succès'), backgroundColor: AppColors.positive));
      }
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configurer ${widget.operator}', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(
          controller: _keyCtrl,
          obscureText: true,
          decoration: InputDecoration(labelText: isMtn ? 'API Key' : 'Client ID'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _secretCtrl,
          obscureText: true,
          decoration: InputDecoration(labelText: isMtn ? 'API Secret' : 'Client Secret'),
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _subCtrl,
          obscureText: true,
          decoration: InputDecoration(labelText: isMtn ? 'Subscription Key' : 'PIN'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
          child: Text('Les credentials sont chiffrés AES-256 côté serveur.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
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

// ── Request payment dialog ─────────────────────────────────────────────────────

class _RequestPaymentDialog extends ConsumerStatefulWidget {
  final String operator;
  final VoidCallback onDone;
  const _RequestPaymentDialog({required this.operator, required this.onDone});

  @override
  ConsumerState<_RequestPaymentDialog> createState() => _RequestPaymentDialogState();
}

class _RequestPaymentDialogState extends ConsumerState<_RequestPaymentDialog> {
  final _phoneCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _currency = 'CDF';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _phoneCtrl.dispose(); _amtCtrl.dispose(); _descCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || _phoneCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).requestMobilePayment({
        'operator': widget.operator,
        'phone': _phoneCtrl.text.trim(),
        'amount': amount,
        'currency': _currency,
        'description': _descCtrl.text.trim(),
        if (_refCtrl.text.isNotEmpty) 'invoiceId': _refCtrl.text.trim(),
      });
      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande de paiement envoyée'), backgroundColor: AppColors.positive));
      }
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Collecter — ${widget.operator}', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Numéro *', hintText: '+243 81 234 5678')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _amtCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant *'))),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _currency,
            items: ['CDF', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _currency = v!),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
        const SizedBox(height: 10),
        TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'N° Facture (optionnel)')),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive),
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Envoyer'),
        ),
      ],
    );
  }
}

// ── Disburse dialog ───────────────────────────────────────────────────────────

class _DisburseDialog extends ConsumerStatefulWidget {
  final String operator;
  final VoidCallback onDone;
  const _DisburseDialog({required this.operator, required this.onDone});

  @override
  ConsumerState<_DisburseDialog> createState() => _DisburseDialogState();
}

class _DisburseDialogState extends ConsumerState<_DisburseDialog> {
  final _phoneCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  String _currency = 'CDF';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _phoneCtrl.dispose(); _amtCtrl.dispose(); _descCtrl.dispose(); _refCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null || _phoneCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).disburseMobileMoney({
        'operator': widget.operator,
        'phone': _phoneCtrl.text.trim(),
        'amount': amount,
        'currency': _currency,
        'description': _descCtrl.text.trim(),
        if (_refCtrl.text.isNotEmpty) 'invoiceId': _refCtrl.text.trim(),
      });
      widget.onDone();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Décaissement initié'), backgroundColor: AppColors.positive));
      }
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Décaisser — ${widget.operator}', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Numéro bénéficiaire *', hintText: '+243 97 000 0000')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _amtCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Montant *'))),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _currency,
            items: ['CDF', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _currency = v!),
          ),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Motif')),
        const SizedBox(height: 10),
        TextFormField(controller: _refCtrl, decoration: const InputDecoration(labelText: 'N° Facture (optionnel)')),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Décaisser'),
        ),
      ],
    );
  }
}
