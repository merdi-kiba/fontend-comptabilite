import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _summaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getInvoicesSummary();
});
final _metricsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getInvoiceMetrics();
});
final _agedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getInvoiceAgedReceivable();
});
final _overdueProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getOverdueInvoices();
});

class InvoicesDashboardTab extends ConsumerWidget {
  const InvoicesDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_summaryProvider);
        ref.invalidate(_metricsProvider);
        ref.invalidate(_agedProvider);
        ref.invalidate(_overdueProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs principaux
            ref.watch(_summaryProvider).when(
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => _ErrorCard(parseError(e)),
              data: (s) => _SummaryKpis(data: s, isDesktop: isDesktop),
            ),
            const SizedBox(height: 16),

            // Métriques (taux paiement, confirmées, annulées)
            ref.watch(_metricsProvider).when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (m) => _MetricsCard(data: m),
            ),
            const SizedBox(height: 16),

            // Créances âgées
            ref.watch(_agedProvider).when(
              loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
              error: (e, _) => _ErrorCard(parseError(e)),
              data: (a) => _AgedReceivableCard(data: a),
            ),
            const SizedBox(height: 16),

            // Factures en retard
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.warning_amber_outlined, color: AppColors.negative, size: 18)),
                      const SizedBox(width: 12),
                      const Text('Factures en retard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                    const SizedBox(height: 12),
                    ref.watch(_overdueProvider).when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text(parseError(e), style: const TextStyle(color: AppColors.negative, fontSize: 12)),
                      data: (list) => list.isEmpty
                          ? Row(children: [
                              const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 20),
                              const SizedBox(width: 8),
                              Text('Aucune facture en retard', style: TextStyle(color: Colors.grey[600])),
                            ])
                          : Column(children: list.take(10).map((inv) {
                              final m = inv as Map<String, dynamic>;
                              return _OverdueRow(
                                number: m['number'] as String? ?? '—',
                                tiers: (m['tiers'] as Map?)?['name'] as String? ?? '—',
                                amount: (m['outstanding'] as num?)?.toDouble() ?? 0,
                                daysOverdue: m['daysOverdue'] as int? ?? 0,
                              );
                            }).toList()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryKpis extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _SummaryKpis({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final allTime = data['allTime'] as Map? ?? {};
    final currentMonth = data['currentMonth'] as Map? ?? {};
    final outstanding = (allTime['amount'] as Map?)?['outstanding'] as num? ?? 0;
    final overdue = (allTime['amount'] as Map?)?['overdue'] as num? ?? 0;
    final monthTotal = (currentMonth['amount'] as Map?)?['totalTTC'] as num? ?? 0;
    final monthCount = (currentMonth['count'] as Map?)?['total'] as num? ?? 0;

    return GridView.count(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isDesktop ? 1.8 : 1.4,
      children: [
        _KpiCard('CA ce mois', Fmt.compact(monthTotal.toDouble()), '$monthCount factures', AppColors.primary, Icons.trending_up),
        _KpiCard('Créances', Fmt.compact(outstanding.toDouble()), 'en attente', AppColors.warning, Icons.pending_outlined),
        _KpiCard('En retard', Fmt.compact(overdue.toDouble()), 'à recouvrer', AppColors.negative, Icons.warning_amber_outlined),
        _KpiCard('Payé ce mois', Fmt.compact(((currentMonth['amount'] as Map?)?['collected'] as num? ?? 0).toDouble()), 'encaissé', AppColors.positive, Icons.check_circle_outline),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;
  const _KpiCard(this.label, this.value, this.sub, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18)),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ]),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MetricsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final paymentRate = (data['paymentRate'] as num?)?.toDouble() ?? 0;
    final confirmed = data['confirmedCount'] as num? ?? 0;
    final cancelled = data['cancelledCount'] as num? ?? 0;
    final avgDays = data['avgPaymentDays'] as num? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Métriques de performance', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _MetricTile('Taux paiement', '${paymentRate.toStringAsFixed(1)}%', AppColors.positive)),
              Expanded(child: _MetricTile('Confirmées', '$confirmed', AppColors.primary)),
              Expanded(child: _MetricTile('Annulées', '$cancelled', AppColors.negative)),
              Expanded(child: _MetricTile('Délai moyen', '${avgDays}j', AppColors.warning)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (paymentRate / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.positive.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.positive),
              ),
            ),
            const SizedBox(height: 4),
            Text('${paymentRate.toStringAsFixed(1)}% des factures confirmées sont payées',
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
    ]);
  }
}

class _AgedReceivableCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _AgedReceivableCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final buckets = [
      ('0 – 30j', data['bucket0_30'] as num? ?? 0, AppColors.positive),
      ('31 – 60j', data['bucket31_60'] as num? ?? 0, AppColors.warning),
      ('61 – 90j', data['bucket61_90'] as num? ?? 0, Colors.orange),
      ('> 90j', data['bucket90plus'] as num? ?? 0, AppColors.negative),
    ];
    final total = buckets.fold<double>(0, (s, b) => s + b.$2.toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.bar_chart_outlined, color: AppColors.primary, size: 18)),
              const SizedBox(width: 12),
              const Text('Créances âgées', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              Text(Fmt.compact(total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 16),
            ...buckets.map((b) {
              final pct = total > 0 ? (b.$2.toDouble() / total) : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(children: [
                      SizedBox(width: 60, child: Text(b.$1, style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Expanded(child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct.toDouble(),
                          minHeight: 8,
                          backgroundColor: b.$3.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(b.$3),
                        ),
                      )),
                      const SizedBox(width: 8),
                      SizedBox(width: 80, child: Text(Fmt.compact(b.$2.toDouble()), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: b.$3), textAlign: TextAlign.right)),
                    ]),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _OverdueRow extends StatelessWidget {
  final String number;
  final String tiers;
  final double amount;
  final int daysOverdue;
  const _OverdueRow({required this.number, required this.tiers, required this.amount, required this.daysOverdue});

  @override
  Widget build(BuildContext context) {
    final color = daysOverdue > 90 ? AppColors.negative : daysOverdue > 60 ? Colors.orange : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(tiers, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
          child: Text('$daysOverdue j', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 12),
        Text(Fmt.compact(amount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      ]),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Text(message, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
    );
  }
}
