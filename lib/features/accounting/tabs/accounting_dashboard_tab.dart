import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _overviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAccountingOverview();
});

final _reminderStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getReminderStats();
});

class AccountingDashboardTab extends ConsumerWidget {
  const AccountingDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviewAsync = ref.watch(_overviewProvider);
    final reminderAsync = ref.watch(_reminderStatsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_overviewProvider);
        ref.invalidate(_reminderStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            overviewAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => _Banner(parseError(e), true),
              data: (data) => _OverviewKpis(data: data, isDesktop: isDesktop),
            ),
            const SizedBox(height: 20),
            reminderAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (stats) => _ReminderStats(stats: stats),
            ),
            const SizedBox(height: 20),
            _IntegrityCard(),
          ],
        ),
      ),
    );
  }
}

class _OverviewKpis extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _OverviewKpis({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final ytd = data['ytd'] as Map? ?? {};
    final revenue = (ytd['revenue'] as num?)?.toDouble() ?? 0;
    final expenses = (ytd['expenses'] as num?)?.toDouble() ?? 0;
    final netIncome = (ytd['netIncome'] as num?)?.toDouble() ?? 0;
    final cashBalance = (data['cashBalance'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Comptabilité — Vue d\'ensemble', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        Text('Cumul annuel (YTD)', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 16),

        // Résultat net bandeau
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: netIncome >= 0
                  ? [AppColors.positive, AppColors.positive.withValues(alpha: 0.8)]
                  : [AppColors.negative, AppColors.negative.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Résultat net YTD', style: TextStyle(color: Colors.white70, fontSize: 13)),
              Text(Fmt.currency(netIncome), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
              Text(netIncome >= 0 ? 'Bénéfice' : 'Déficit', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ])),
            Icon(netIncome >= 0 ? Icons.trending_up : Icons.trending_down, color: Colors.white, size: 48),
          ]),
        ),
        const SizedBox(height: 12),

        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 3 : 2,
          crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: isDesktop ? 2.0 : 1.5,
          children: [
            _KpiTile('Chiffre d\'affaires', Fmt.compact(revenue), AppColors.primary, Icons.trending_up),
            _KpiTile('Charges totales', Fmt.compact(expenses), AppColors.warning, Icons.trending_down),
            _KpiTile('Trésorerie', Fmt.compact(cashBalance), AppColors.positive, Icons.savings_outlined),
          ],
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
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
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
      ]),
    );
  }
}

class _ReminderStats extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ReminderStats({required this.stats});

  @override
  Widget build(BuildContext context) {
    final overdue = stats['overdueCount'] as num? ?? 0;
    final totalAmount = (stats['totalOverdueAmount'] as num?)?.toDouble() ?? 0;
    final sent = stats['remindersSentThisMonth'] as num? ?? 0;
    if (overdue == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.notification_important_outlined, color: AppColors.warning, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$overdue client(s) en retard · ${Fmt.compact(totalAmount)} CDF', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('$sent relance(s) envoyée(s) ce mois', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ])),
        ]),
      ),
    );
  }
}

class _IntegrityCard extends ConsumerStatefulWidget {
  @override
  ConsumerState<_IntegrityCard> createState() => _IntegrityCardState();
}

class _IntegrityCardState extends ConsumerState<_IntegrityCard> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _check() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final now = DateTime.now();
      final from = '${now.year}-01-01';
      final to = now.toIso8601String().substring(0, 10);
      final r = await ref.read(apiClientProvider).integrityCheck(from, to);
      setState(() => _result = r);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issues = _result?['issues'] as List? ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.verified_outlined, color: AppColors.primary, size: 18)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vérification d\'intégrité', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Détecte les écritures déséquilibrées YTD', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
            OutlinedButton.icon(
              onPressed: _loading ? null : _check,
              icon: _loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.play_arrow_outlined, size: 16),
              label: const Text('Vérifier'),
              style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ]),
          if (_error != null) ...[const SizedBox(height: 8), _Banner(_error!, true)],
          if (_result != null) ...[
            const SizedBox(height: 12),
            issues.isEmpty
                ? Row(children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 20),
                    const SizedBox(width: 8),
                    Text('Aucune anomalie détectée', style: TextStyle(color: Colors.grey[700])),
                  ])
                : Column(children: issues.map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_outlined, color: AppColors.warning, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(i.toString(), style: const TextStyle(fontSize: 12))),
                    ]),
                  )).toList()),
          ],
        ]),
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
