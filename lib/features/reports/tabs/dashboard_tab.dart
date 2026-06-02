import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _dashProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAccountingOverview();
});

final _trendProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getMonthlyTrend(year: DateTime.now().year);
});

final _kpiSelectedFyProvider = StateProvider.autoDispose<String?>((ref) => null);

final _kpiProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String?>((ref, fyId) async {
  final fiscalYears = await ref.watch(apiClientProvider).getFiscalYears();
  final id = fyId ?? (fiscalYears.isNotEmpty ? (fiscalYears.first as Map)['id'] as String? : null);
  if (id == null) throw Exception('Aucun exercice fiscal trouvé');
  return ref.watch(apiClientProvider).getKpiSummary(id);
});

class DashboardTab extends ConsumerWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_dashProvider);
    final trendAsync = ref.watch(_trendProvider);
    final selectedFy = ref.watch(_kpiSelectedFyProvider);
    final kpiAsync = ref.watch(_kpiProvider(selectedFy));
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_dashProvider);
        ref.invalidate(_trendProvider);
        ref.invalidate(_kpiProvider(selectedFy));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 20 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Dashboard KPIs
          dashAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            error: (e, _) => _ErrCard(parseError(e)),
            data: (d) => _DashKpis(data: d, isDesktop: isDesktop),
          ),
          const SizedBox(height: 20),

          // Tendance mensuelle
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.trending_up_outlined, color: AppColors.primary, size: 18)),
                const SizedBox(width: 12),
                Text('Tendance ${DateTime.now().year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
              const SizedBox(height: 12),
              trendAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrCard(parseError(e)),
                data: (months) => _TrendTable(months: months),
              ),
            ]),
          )),
          const SizedBox(height: 20),

          // KPIs financiers
          Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.analytics_outlined, color: AppColors.accent, size: 18)),
                const SizedBox(width: 12),
                const Expanded(child: Text('KPIs financiers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
                FutureBuilder<List<dynamic>>(
                  future: ref.read(apiClientProvider).getFiscalYears(),
                  builder: (ctx, snap) {
                    if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
                    final fys = snap.data!;
                    return DropdownButton<String>(
                      value: selectedFy ?? (fys.first as Map)['id'] as String?,
                      underline: const SizedBox(),
                      items: fys.map((fy) {
                        final m = fy as Map<String, dynamic>;
                        return DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] as String? ?? '—', style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (v) => ref.read(_kpiSelectedFyProvider.notifier).state = v,
                    );
                  },
                ),
              ]),
              const SizedBox(height: 12),
              kpiAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrCard(parseError(e)),
                data: (kpi) => _KpiGrid(kpi: kpi, isDesktop: isDesktop),
              ),
            ]),
          )),
        ]),
      ),
    );
  }
}

// ── Dashboard KPIs ────────────────────────────────────────────────────────────

class _DashKpis extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _DashKpis({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final cm = data['currentMonth'] as Map? ?? {};
    final ytd = data['ytd'] as Map? ?? {};
    final treasury = data['treasury'] as Map? ?? {};
    final revenue = (cm['revenue'] as num?)?.toDouble() ?? 0;
    final expenses = (cm['expenses'] as num?)?.toDouble() ?? 0;
    final net = (cm['netIncome'] as num?)?.toDouble() ?? (revenue - expenses);
    final treasuryTotal = (treasury['total'] as num?)?.toDouble() ?? 0;
    final ytdRevenue = (ytd['revenue'] as num?)?.toDouble() ?? 0;
    final overdueRec = (data['overdueReceivables'] as num?)?.toDouble() ?? 0;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Ce mois', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey)),
      const SizedBox(height: 8),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isDesktop ? 4 : 2,
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0,
        children: [
          _KpiCard('Revenus', revenue, AppColors.positive, Icons.trending_up),
          _KpiCard('Charges', expenses, AppColors.negative, Icons.trending_down),
          _KpiCard('Résultat net', net, net >= 0 ? AppColors.positive : AppColors.negative, Icons.account_balance_outlined),
          _KpiCard('Trésorerie', treasuryTotal, AppColors.primary, Icons.savings_outlined),
        ],
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _InfoTile('CA YTD', Fmt.compact(ytdRevenue), AppColors.neutral)),
        const SizedBox(width: 10),
        Expanded(child: _InfoTile('Créances échues', Fmt.compact(overdueRec), overdueRec > 0 ? AppColors.negative : AppColors.positive)),
      ]),
    ]);
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;
  const _KpiCard(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8ECF0))),
    child: Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 16)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(Fmt.compact(value), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ])),
    ]),
  );
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600]))),
      Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
    ]),
  );
}

// ── Monthly trend table ───────────────────────────────────────────────────────

class _TrendTable extends StatelessWidget {
  final List<dynamic> months;
  const _TrendTable({required this.months});

  static const _monthNames = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) {
      return Text('Aucune donnée', style: TextStyle(color: Colors.grey[500]));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 16,
        headingRowHeight: 32,
        dataRowMinHeight: 32,
        columns: const [
          DataColumn(label: Text('Mois', style: TextStyle(fontSize: 12))),
          DataColumn(label: Text('Revenus', style: TextStyle(fontSize: 12)), numeric: true),
          DataColumn(label: Text('Charges', style: TextStyle(fontSize: 12)), numeric: true),
          DataColumn(label: Text('Résultat', style: TextStyle(fontSize: 12)), numeric: true),
        ],
        rows: months.map((m) {
          final month = m as Map<String, dynamic>;
          final idx = (month['month'] as int? ?? month['monthNumber'] as int? ?? 0);
          final rev = (month['revenue'] as num?)?.toDouble() ?? 0;
          final exp = (month['expenses'] as num?)?.toDouble() ?? 0;
          final net = rev - exp;
          final monthName = idx > 0 && idx <= 12 ? _monthNames[idx] : '$idx';
          return DataRow(cells: [
            DataCell(Text(monthName, style: const TextStyle(fontSize: 12))),
            DataCell(Text(Fmt.compact(rev), style: const TextStyle(fontSize: 12, color: AppColors.positive))),
            DataCell(Text(Fmt.compact(exp), style: const TextStyle(fontSize: 12, color: AppColors.negative))),
            DataCell(Text(Fmt.compact(net), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: net >= 0 ? AppColors.positive : AppColors.negative))),
          ]);
        }).toList(),
      ),
    );
  }
}

// ── KPI grid ──────────────────────────────────────────────────────────────────

class _KpiGrid extends StatelessWidget {
  final Map<String, dynamic> kpi;
  final bool isDesktop;
  const _KpiGrid({required this.kpi, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final ratios = kpi['ratios'] as Map? ?? {};
    final items = [
      ('Marge brute %', '${(ratios['grossMarginPct'] as num? ?? 0).toStringAsFixed(1)}%', AppColors.positive),
      ('Marge nette %', '${(ratios['netMarginPct'] as num? ?? 0).toStringAsFixed(1)}%', AppColors.positive),
      ('Croissance CA', '${(ratios['revenueGrowthPct'] as num? ?? 0).toStringAsFixed(1)}%', AppColors.accent),
      ('DSO (jours)', '${ratios['dso'] ?? '—'}j', AppColors.warning),
      ('DPO (jours)', '${ratios['dpo'] ?? '—'}j', AppColors.warning),
      ('Liquidité', (ratios['currentRatio'] as num? ?? 0).toStringAsFixed(2), AppColors.primary),
      ('Quick ratio', (ratios['quickRatio'] as num? ?? 0).toStringAsFixed(2), AppColors.primary),
      ('Endettement', (ratios['debtToEquity'] as num? ?? 0).toStringAsFixed(2), AppColors.neutral),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 4 : 2,
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.2,
      children: items.map((item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: item.$3.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(item.$2, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: item.$3)),
          Text(item.$1, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        ]),
      )).toList(),
    );
  }
}

class _ErrCard extends StatelessWidget {
  final String msg;
  const _ErrCard(this.msg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
    child: Text(msg, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
  );
}
