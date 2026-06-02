import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _dashProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getTreasuryDashboard();
});

final _balancesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAllAccountsBalance();
});

final _forecastProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCashFlowForecast(horizon: 90);
});

class TreasuryDashboardTab extends ConsumerWidget {
  const TreasuryDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_dashProvider);
    final balancesAsync = ref.watch(_balancesProvider);
    final forecastAsync = ref.watch(_forecastProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_dashProvider);
        ref.invalidate(_balancesProvider);
        ref.invalidate(_forecastProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs principaux
            dashAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => _ErrBanner(parseError(e)),
              data: (d) => _DashKpis(data: d, isDesktop: isDesktop),
            ),
            const SizedBox(height: 20),

            // Soldes par compte
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.account_balance_outlined, color: AppColors.primary, size: 18)),
                      const SizedBox(width: 12),
                      const Text('Soldes par compte', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ]),
                    const SizedBox(height: 12),
                    balancesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _ErrBanner(parseError(e)),
                      data: (balances) => Column(
                        children: balances.map((b) {
                          final m = b as Map<String, dynamic>;
                          final name = m['name'] as String? ?? m['bankName'] as String? ?? '—';
                          final balance = (m['balance'] as num?)?.toDouble() ?? 0;
                          final currency = m['currency'] as String? ?? 'CDF';
                          final type = m['type'] as String? ?? 'BANK';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              Icon(type == 'CASH' ? Icons.account_balance_wallet_outlined : Icons.account_balance_outlined,
                                size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 10),
                              Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
                              Text(currency, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                              const SizedBox(width: 8),
                              Text(Fmt.currency(balance),
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                                  color: balance >= 0 ? AppColors.positive : AppColors.negative)),
                            ]),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Prévision cash-flow
            forecastAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (f) => _ForecastCard(data: f),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashKpis extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _DashKpis({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final bankBalance = (data['bankBalance'] as num?)?.toDouble() ?? 0;
    final cashBalance = (data['cashBalance'] as num?)?.toDouble() ?? 0;
    final totalBalance = (data['totalBalance'] as num?)?.toDouble() ?? (bankBalance + cashBalance);
    final accountCount = data['accountCount'] as num? ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Trésorerie totale', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(Fmt.currency(totalBalance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              Text('$accountCount compte(s) actif(s)', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            const Icon(Icons.savings_outlined, color: Colors.white54, size: 48),
          ]),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 2 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5,
          children: [
            _KpiTile('Banques', bankBalance, AppColors.primary, Icons.account_balance_outlined),
            _KpiTile('Caisses', cashBalance, AppColors.positive, Icons.account_balance_wallet_outlined),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _KpiTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8ECF0))),
      child: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(Fmt.compact(value), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
      ]),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ForecastCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final inflowsMap = data['inflows'] as Map? ?? {};
    final outflowsMap = data['outflows'] as Map? ?? {};
    final inflows = (inflowsMap['total'] as num?)?.toDouble()
        ?? (data['totalInflows'] as num?)?.toDouble() ?? 0;
    final outflows = (outflowsMap['total'] as num?)?.toDouble()
        ?? (data['totalOutflows'] as num?)?.toDouble() ?? 0;
    final net = (data['netCashFlow'] as num?)?.toDouble() ?? (inflows - outflows);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.timeline_outlined, color: AppColors.warning, size: 18)),
              const SizedBox(width: 12),
              const Text('Prévision de trésorerie', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            _fRow('Entrées prévues', inflows, AppColors.positive),
            _fRow('Sorties prévues', outflows, AppColors.negative),
            const Divider(),
            _fRow('Position nette', net, net >= 0 ? AppColors.positive : AppColors.negative, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _fRow(String label, double value, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
      Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: bold ? 16 : 13)),
    ]),
  );
}

class _ErrBanner extends StatelessWidget {
  final String msg;
  const _ErrBanner(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
    child: Text(msg, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
  );
}
