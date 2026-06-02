import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _ratesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCurrencyRates();
});

final _exposureProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCurrencyExposure();
});

final _revalPreviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  return ref.watch(apiClientProvider).previewRevaluation(today);
});

// ── Main tab ─────────────────────────────────────────────────────────────────

class CurrenciesTab extends ConsumerStatefulWidget {
  const CurrenciesTab({super.key});

  @override
  ConsumerState<CurrenciesTab> createState() => _CurrenciesTabState();
}

class _CurrenciesTabState extends ConsumerState<CurrenciesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
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
            Tab(text: 'Taux de change'),
            Tab(text: 'Exposition risque'),
            Tab(text: 'Réévaluation'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: const [
            _RatesView(),
            _ExposureView(),
            _RevaluationView(),
          ],
        ),
      ),
    ]);
  }
}

// ── Rates view ────────────────────────────────────────────────────────────────

class _RatesView extends ConsumerWidget {
  const _RatesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ratesAsync = ref.watch(_ratesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'fetch_bcc',
            onPressed: () => _fetchBcc(context, ref),
            tooltip: 'Récupérer taux BCC',
            backgroundColor: AppColors.accent,
            child: const Icon(Icons.cloud_download_outlined, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_rate',
            onPressed: () => _showAddRate(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Nouveau taux'),
            backgroundColor: AppColors.primary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_ratesProvider.future),
        child: ratesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (rates) => rates.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.currency_exchange_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucun taux enregistré', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Ajoutez un taux manuellement ou récupérez les taux BCC', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ]))
              : Column(children: [
                  // Convertisseur rapide
                  _QuickConvert(),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      itemCount: rates.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 6),
                      itemBuilder: (_, i) => _RateCard(rate: rates[i] as Map<String, dynamic>),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Future<void> _fetchBcc(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).fetchBccRates();
      ref.invalidate(_ratesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Taux BCC mis à jour'), backgroundColor: AppColors.positive));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
      }
    }
  }

  void _showAddRate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _AddRateDialog(
      onAdded: () => ref.invalidate(_ratesProvider),
    ));
  }
}

// ── Quick converter ───────────────────────────────────────────────────────────

class _QuickConvert extends ConsumerStatefulWidget {
  const _QuickConvert();

  @override
  ConsumerState<_QuickConvert> createState() => _QuickConvertState();
}

class _QuickConvertState extends ConsumerState<_QuickConvert> {
  final _amtCtrl = TextEditingController(text: '1000');
  String _from = 'USD';
  String _to = 'CDF';
  double? _result;
  bool _loading = false;

  @override
  void dispose() { _amtCtrl.dispose(); super.dispose(); }

  Future<void> _convert() async {
    final amount = double.tryParse(_amtCtrl.text);
    if (amount == null) return;
    setState(() { _loading = true; _result = null; });
    try {
      final r = await ref.read(apiClientProvider).convertAmount(amount, _from, _to);
      if (mounted) setState(() => _result = (r['result'] as num?)?.toDouble());
    } catch (_) {
      if (mounted) setState(() => _result = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(children: [
        Expanded(child: TextField(
          controller: _amtCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(fontSize: 14),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10), labelText: 'Montant'),
        )),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: _from,
          items: ['USD', 'EUR', 'CDF'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _from = v!),
          underline: const SizedBox(),
        ),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey[500])),
        DropdownButton<String>(
          value: _to,
          items: ['CDF', 'USD', 'EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (v) => setState(() => _to = v!),
          underline: const SizedBox(),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _loading ? null : _convert,
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
          child: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('=', style: TextStyle(fontSize: 16)),
        ),
        if (_result != null) ...[
          const SizedBox(width: 10),
          Flexible(child: Text(Fmt.currency(_result!, symbol: _to),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary),
            overflow: TextOverflow.ellipsis)),
        ],
      ]),
    );
  }
}

// ── Rate card ─────────────────────────────────────────────────────────────────

class _RateCard extends StatelessWidget {
  final Map<String, dynamic> rate;
  const _RateCard({required this.rate});

  @override
  Widget build(BuildContext context) {
    final from = rate['fromCurrency'] as String? ?? '—';
    final to = rate['toCurrency'] as String? ?? '—';
    final r = (rate['rate'] as num?)?.toDouble() ?? 0;
    final source = rate['source'] as String? ?? '—';
    final date = (rate['effectiveDate'] as String? ?? '').substring(0, 10.clamp(0, (rate['effectiveDate'] as String? ?? '').length));
    final isBcc = source.toUpperCase() == 'BCC';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.currency_exchange_outlined, color: AppColors.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('$from → $to', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isBcc ? AppColors.positive : AppColors.neutral).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(source, style: TextStyle(fontSize: 9, color: isBcc ? AppColors.positive : AppColors.neutral, fontWeight: FontWeight.w700)),
              ),
            ]),
            Text(date, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          Text('1 $from = ${r.toStringAsFixed(2)} $to',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.primary)),
        ]),
      ),
    );
  }
}

// ── Exposure view ─────────────────────────────────────────────────────────────

class _ExposureView extends ConsumerWidget {
  const _ExposureView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exposureAsync = ref.watch(_exposureProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_exposureProvider.future),
      child: exposureAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (data) {
          final positions = (data['positions'] as List? ?? data['byCurrency'] as List? ?? []);
          if (positions.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.balance_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text('Aucune exposition en devises étrangères', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 4),
              Text('Toutes vos créances sont en CDF', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
            ]));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: positions.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _ExposureCard(position: positions[i] as Map<String, dynamic>),
          );
        },
      ),
    );
  }
}

// ── Exposure card ─────────────────────────────────────────────────────────────

class _ExposureCard extends StatelessWidget {
  final Map<String, dynamic> position;
  const _ExposureCard({required this.position});

  @override
  Widget build(BuildContext context) {
    final currency = position['currency'] as String? ?? '—';
    final arForeign = (position['arForeign'] as num?)?.toDouble() ?? 0.0;
    final arCdf = (position['arCdf'] as num?)?.toDouble() ?? 0.0;
    final currentValueCdf = (position['currentValueCdf'] as num?)?.toDouble() ?? 0.0;
    final unrealized = (position['unrealizedGainLoss'] as num?)?.toDouble() ?? (currentValueCdf - arCdf);
    final isGain = unrealized >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: (isGain ? AppColors.positive : AppColors.negative).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(child: Text(currency, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13,
                color: isGain ? AppColors.positive : AppColors.negative))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Exposition $currency', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${Fmt.compact(arForeign)} $currency en créances',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${isGain ? '+' : ''}${Fmt.compact(unrealized)} CDF',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                  color: isGain ? AppColors.positive : AppColors.negative)),
              Text('Plus/moins-value latente', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ]),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            _exposureDetail('Valeur d\'origine', arCdf),
            const SizedBox(width: 16),
            _exposureDetail('Valeur actuelle', currentValueCdf),
          ]),
        ]),
      ),
    );
  }

  Widget _exposureDetail(String label, double value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        const SizedBox(height: 2),
        Text(Fmt.compact(value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('CDF', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ]),
    ),
  );
}

// ── Revaluation view ──────────────────────────────────────────────────────────

class _RevaluationView extends ConsumerStatefulWidget {
  const _RevaluationView();

  @override
  ConsumerState<_RevaluationView> createState() => _RevaluationViewState();
}

class _RevaluationViewState extends ConsumerState<_RevaluationView> {
  bool _posting = false;

  @override
  Widget build(BuildContext context) {
    final previewAsync = ref.watch(_revalPreviewProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_revalPreviewProvider.future),
      child: previewAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (data) {
          final entries = (data['entries'] as List? ?? []);
          final totalGain = (data['totalGain'] as num?)?.toDouble() ?? 0.0;
          final totalLoss = (data['totalLoss'] as num?)?.toDouble() ?? 0.0;
          final net = totalGain - totalLoss;
          final today = DateTime.now().toIso8601String().substring(0, 10);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Summary card
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.autorenew_outlined, color: AppColors.warning, size: 18)),
                    const SizedBox(width: 12),
                    Text('Réévaluation au $today', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
                  const SizedBox(height: 14),
                  _summaryRow('Gains de change (476)', totalGain, AppColors.positive),
                  _summaryRow('Pertes de change (477)', totalLoss, AppColors.negative),
                  const Divider(),
                  _summaryRow('Position nette', net, net >= 0 ? AppColors.positive : AppColors.negative, bold: true),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: entries.isEmpty || _posting ? null : () => _postRevaluation(context, today),
                      icon: _posting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.post_add_outlined),
                      label: Text(_posting ? 'Comptabilisation…' : 'Comptabiliser la réévaluation'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                    ),
                  ),
                ]),
              )),
              if (entries.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Écritures générées (${entries.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...entries.map((e) {
                  final m = e as Map<String, dynamic>;
                  final amount = (m['amount'] as num?)?.toDouble() ?? 0.0;
                  final isGain = (m['type'] as String?)?.toUpperCase() == 'GAIN';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(isGain ? Icons.trending_up : Icons.trending_down,
                        color: isGain ? AppColors.positive : AppColors.negative, size: 18),
                      title: Text(m['description'] as String? ?? '—', style: const TextStyle(fontSize: 13)),
                      subtitle: Text('${m['currency'] ?? '—'} · ${m['accountCode'] ?? '—'}',
                        style: const TextStyle(fontSize: 11)),
                      trailing: Text(Fmt.compact(amount),
                        style: TextStyle(fontWeight: FontWeight.w700,
                          color: isGain ? AppColors.positive : AppColors.negative)),
                    ),
                  );
                }),
              ] else ...[
                const SizedBox(height: 24),
                Center(child: Column(children: [
                  Icon(Icons.check_circle_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 8),
                  Text('Aucune écriture de réévaluation nécessaire', style: TextStyle(color: Colors.grey[500])),
                ])),
              ],
            ]),
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, double value, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
      Text(Fmt.currency(value),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: bold ? 15 : 13, color: color)),
    ]),
  );

  Future<void> _postRevaluation(BuildContext context, String date) async {
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Confirmer la réévaluation'),
      content: Text('Comptabiliser les écritures d\'écart de change au $date ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
          child: const Text('Comptabiliser'),
        ),
      ],
    ));
    if (confirm != true) return;

    setState(() => _posting = true);
    try {
      await ref.read(apiClientProvider).postRevaluation(date, '');
      ref.invalidate(_revalPreviewProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réévaluation comptabilisée'), backgroundColor: AppColors.positive));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }
}

// ── Add rate dialog ───────────────────────────────────────────────────────────

class _AddRateDialog extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddRateDialog({required this.onAdded});

  @override
  ConsumerState<_AddRateDialog> createState() => _AddRateDialogState();
}

class _AddRateDialogState extends ConsumerState<_AddRateDialog> {
  final _rateCtrl = TextEditingController();
  String _from = 'USD';
  String _to = 'CDF';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _rateCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final rate = double.tryParse(_rateCtrl.text);
    if (rate == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createCurrencyRate({
        'fromCurrency': _from,
        'toCurrency': _to,
        'rate': rate,
        'source': 'MANUAL',
        'effectiveDate': _date.toIso8601String().substring(0, 10),
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
      title: const Text('Nouveau taux de change', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _from,
            decoration: const InputDecoration(labelText: 'De'),
            items: ['USD', 'EUR', 'GBP', 'CDF'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _from = v!),
          )),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.arrow_forward, size: 18, color: Colors.grey[500])),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _to,
            decoration: const InputDecoration(labelText: 'Vers'),
            items: ['CDF', 'USD', 'EUR', 'GBP'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _to = v!),
          )),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          controller: _rateCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Taux (1 $_from = ? $_to)', hintText: '2850.50'),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date effective', isDense: true),
            child: Text(_date.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 14)),
          ),
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
