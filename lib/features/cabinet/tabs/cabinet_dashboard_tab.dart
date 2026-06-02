import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _cabinetDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getCabinetDashboard();
});

class CabinetDashboardTab extends ConsumerWidget {
  const CabinetDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(_cabinetDashboardProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_cabinetDashboardProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: dashAsync.when(
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
          error: (e, _) => _ErrorView(message: parseError(e), onRetry: () => ref.refresh(_cabinetDashboardProvider.future)),
          data: (data) => _DashboardContent(data: data, isDesktop: isDesktop),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _DashboardContent({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final clientCount = data['clientCount'] as num? ?? 0;
    final activeClients = data['activeClients'] as num? ?? 0;
    final memberCount = data['memberCount'] as num? ?? 0;
    final pendingInvoices = data['pendingInvoices'] as num? ?? 0;
    final overdueAmount = (data['overdueAmount'] as num?)?.toDouble() ?? 0;
    final alerts = data['alerts'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cabinet — Vue d\'ensemble', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text('Synthèse de tous vos clients', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const SizedBox(height: 20),

        // KPI Cards
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 4 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isDesktop ? 1.8 : 1.4,
          children: [
            _KpiCard(label: 'Clients totaux', value: '$clientCount', icon: Icons.business_outlined, color: AppColors.primary),
            _KpiCard(label: 'Clients actifs', value: '$activeClients', icon: Icons.check_circle_outline, color: AppColors.positive),
            _KpiCard(label: 'Membres', value: '$memberCount', icon: Icons.people_outline, color: AppColors.warning),
            _KpiCard(label: 'Factures en attente', value: '$pendingInvoices', icon: Icons.receipt_long_outlined, color: const Color(0xFF7C3AED)),
          ],
        ),
        const SizedBox(height: 20),

        // Montant en retard
        if (overdueAmount > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.negative.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.negative.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_outlined, color: AppColors.negative, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Créances en retard', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text(Fmt.currency(overdueAmount), style: const TextStyle(color: AppColors.negative, fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Alertes clients
        if (alerts.isNotEmpty) ...[
          Text('Alertes actives (${alerts.length})', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          ...alerts.take(8).map((a) => _AlertRow(alert: a as Map<String, dynamic>)),
        ] else
          _EmptyAlerts(),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 18),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Map<String, dynamic> alert;
  const _AlertRow({required this.alert});

  @override
  Widget build(BuildContext context) {
    final type = alert['type'] as String? ?? '';
    final tenant = alert['tenantName'] as String? ?? alert['tenantId'] as String? ?? '—';
    final message = alert['message'] as String? ?? type;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.notification_important_outlined, color: AppColors.warning, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tenant, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(message, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(type, style: const TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.positive.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.positive.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 28),
          const SizedBox(width: 12),
          Text('Aucune alerte active sur vos clients', style: TextStyle(color: Colors.grey[700], fontSize: 14)),
        ],
      ),
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
          const Icon(Icons.wifi_off_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ],
      ),
    );
  }
}
