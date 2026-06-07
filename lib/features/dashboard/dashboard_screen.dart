import 'package:proxima/core/utils/error_utils.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';
import 'package:proxima/features/dashboard/dashboard_provider.dart';
import 'package:proxima/shared/widgets/stat_card.dart';

double _n(dynamic v) => v is num ? v.toDouble() : 0.0;

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(dashboardProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: dashAsync.when(
          loading: () => _LoadingLayout(isDesktop: isDesktop),
          error: (e, _) => _ErrorView(message: parseError(e), onRetry: () => ref.refresh(dashboardProvider.future)),
          data: (data) => _DashboardContent(data: data, isDesktop: isDesktop),
        ),
      ),
    );
  }
}

// ── Contenu principal ─────────────────────────────────────────────────────────

class _DashboardContent extends StatelessWidget {
  final DashboardData data;
  final bool isDesktop;

  const _DashboardContent({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final invoices = data.invoices;
    final accounting = data.accounting;
    final treasury = data.treasury;
    final global = data.global;

    // Extraire les valeurs
    final allTime = invoices['allTime'] as Map? ?? {};
    final currentMonth = invoices['currentMonth'] as Map? ?? {};
    final ytd = (accounting['ytd'] as Map?) ?? {};
    final totalBalance = toDouble(treasury['totalBalance']);

    final caYTD = _n(ytd['revenue']);
    final chargesYTD = _n(ytd['expenses']);
    final resultatYTD = _n(ytd['netIncome']);
    final facturesEnCours = _n((allTime['amount'] as Map?)?['outstanding']);
    final facturesEnRetard = _n((allTime['count'] as Map?)?['overdue']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Titre + Date
        _SectionHeader(
          title: 'Tableau de bord',
          subtitle: 'Aujourd\'hui · ${Fmt.date(DateTime.now())}',
        ),
        const SizedBox(height: 20),

        // ── KPI Cards ────────────────────────────────────────────────
        _ResponsiveGrid(
          isDesktop: isDesktop,
          columns: isDesktop ? 4 : 2,
          children: [
            StatCard(
              label: 'CA Annuel (YTD)',
              value: Fmt.currency(caYTD),
              icon: Icons.trending_up,
              iconColor: AppColors.positive,
              iconBg: AppColors.positive.withValues(alpha: 0.1),
              trend: resultatYTD >= 0 ? 'Bénéfice' : 'Déficit',
              trendPositive: resultatYTD >= 0,
            ),
            StatCard(
              label: 'Résultat Net',
              value: Fmt.currency(resultatYTD),
              icon: Icons.account_balance_wallet_outlined,
              iconColor: resultatYTD >= 0 ? AppColors.positive : AppColors.negative,
              iconBg: (resultatYTD >= 0 ? AppColors.positive : AppColors.negative).withValues(alpha: 0.1),
              subtitle: 'Charges: ${Fmt.compact(chargesYTD)} CDF',
            ),
            StatCard(
              label: 'Trésorerie',
              value: Fmt.currency(totalBalance),
              icon: Icons.savings_outlined,
              iconColor: AppColors.primary,
              iconBg: AppColors.primary.withValues(alpha: 0.1),
              subtitle: '${(treasury['accountCount'] ?? 0)} comptes',
            ),
            StatCard(
              label: 'Créances clients',
              value: Fmt.currency(facturesEnCours),
              icon: Icons.receipt_long_outlined,
              iconColor: AppColors.warning,
              iconBg: AppColors.warning.withValues(alpha: 0.1),
              trend: facturesEnRetard > 0 ? '$facturesEnRetard en retard' : 'OK',
              trendPositive: facturesEnRetard == 0,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Graphique CA mensuel + Alertes ────────────────────────────
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _MonthlyChart(months: data.monthlyTrend)),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _AlertsPanel(global: global, invoices: invoices)),
            ],
          )
        else ...[
          _MonthlyChart(months: data.monthlyTrend),
          const SizedBox(height: 16),
          _AlertsPanel(global: global, invoices: invoices),
        ],

        const SizedBox(height: 24),

        // ── Factures du mois ──────────────────────────────────────────
        _SectionHeader(title: 'Ce mois-ci', subtitle: 'Résumé facturation'),
        const SizedBox(height: 12),
        _ResponsiveGrid(
          isDesktop: isDesktop,
          columns: isDesktop ? 3 : 2,
          children: [
            _MiniStat(label: 'Factures émises', value: '${(currentMonth['count'] as Map?)?['total'] ?? 0}', color: AppColors.primary),
            _MiniStat(label: 'Montant facturé', value: Fmt.compact((currentMonth['amount'] as Map?)?['totalTTC'] as num? ?? 0), color: AppColors.positive),
            _MiniStat(label: 'En attente paiement', value: Fmt.compact((currentMonth['amount'] as Map?)?['outstanding'] as num? ?? 0), color: AppColors.warning),
          ],
        ),
      ],
    );
  }
}

// ── Graphique CA mensuel ───────────────────────────────────────────────────────

class _MonthlyChart extends StatelessWidget {
  final List<dynamic> months;
  const _MonthlyChart({required this.months});

  static const _monthLabels = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

  @override
  Widget build(BuildContext context) {
    final spots = months.asMap().entries.map((e) {
      final revenue = (e.value['revenue'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), revenue);
    }).toList();

    final maxY = spots.isEmpty ? 100.0 : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chiffre d\'affaires mensuel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Text('${DateTime.now().year}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? Center(child: Text('Aucune donnée', style: TextStyle(color: Colors.grey[400])))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: maxY,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, _) {
                                final i = value.toInt();
                                if (i < 0 || i >= _monthLabels.length) return const SizedBox();
                                return Text(_monthLabels[i], style: TextStyle(fontSize: 11, color: Colors.grey[600]));
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: AppColors.primary,
                            barWidth: 3,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0)],
                              ),
                            ),
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, p, bd, i) => FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: AppColors.primary,
                              ),
                            ),
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

// ── Panel alertes ──────────────────────────────────────────────────────────────

class _AlertsPanel extends StatelessWidget {
  final Map global;
  final Map invoices;
  const _AlertsPanel({required this.global, required this.invoices});

  @override
  Widget build(BuildContext context) {
    final overdueCount = (invoices['allTime'] as Map?)?['count']?['overdue'] as num? ?? 0;
    final overdueAmount = (invoices['allTime'] as Map?)?['amount']?['overdue'] as num? ?? 0;
    final alerts = global['alerts'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Alertes & Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 16),

            if (overdueCount > 0)
              _AlertTile(
                icon: Icons.warning_amber_outlined,
                color: AppColors.negative,
                title: '$overdueCount facture(s) en retard',
                subtitle: Fmt.currency((overdueAmount as num?)?.toDouble() ?? 0.0),
              ),

            if (overdueCount == 0)
              _AlertTile(
                icon: Icons.check_circle_outline,
                color: AppColors.positive,
                title: 'Aucune facture en retard',
                subtitle: 'Recouvrement à jour',
              ),

            if (alerts.isEmpty && overdueCount == 0) ...[
              const SizedBox(height: 8),
              _AlertTile(
                icon: Icons.info_outline,
                color: AppColors.primary,
                title: 'Tout est en ordre',
                subtitle: 'Aucune alerte active',
              ),
            ],

            ...alerts.take(3).map((a) => _AlertTile(
              icon: Icons.notification_important_outlined,
              color: AppColors.warning,
              title: a['title']?.toString() ?? 'Alerte',
              subtitle: a['message']?.toString() ?? '',
            )),
          ],
        ),
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _AlertTile({required this.icon, required this.color, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      ],
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final bool isDesktop;
  final int columns;
  const _ResponsiveGrid({required this.children, required this.isDesktop, required this.columns});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final cols = constraints.maxWidth > 600 ? columns : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.6 : 1.3,
          ),
          itemCount: children.length,
          itemBuilder: (_, i) => children[i],
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

class _LoadingLayout extends StatelessWidget {
  final bool isDesktop;
  const _LoadingLayout({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isDesktop ? 1.6 : 1.3,
          ),
          itemCount: 4,
          itemBuilder: (context, i) => const StatCardShimmer(),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text('Impossible de charger le tableau de bord', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }
}
