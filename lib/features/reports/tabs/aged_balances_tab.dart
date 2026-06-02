import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _clientsAgedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAgedClientsBalance();
});
final _suppliersAgedProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAgedSuppliersBalance();
});

class AgedBalancesTab extends ConsumerStatefulWidget {
  const AgedBalancesTab({super.key});

  @override
  ConsumerState<AgedBalancesTab> createState() => _AgedBalancesTabState();
}

class _AgedBalancesTabState extends ConsumerState<AgedBalancesTab>
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
            Tab(icon: Icon(Icons.people_outlined, size: 16), text: 'Créances clients'),
            Tab(icon: Icon(Icons.business_outlined, size: 16), text: 'Dettes fournisseurs'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _AgedView(provider: _clientsAgedProvider, type: 'clients'),
          _AgedView(provider: _suppliersAgedProvider, type: 'fournisseurs'),
        ]),
      ),
    ]);
  }
}

class _AgedView extends ConsumerWidget {
  final ProviderListenable<AsyncValue<Map<String, dynamic>>> provider;
  final String type;
  const _AgedView({required this.provider, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClients = type == 'clients';

    return ref.watch(provider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (data) {
        final total = (data['total'] as num?)?.toDouble() ?? 0;
        final buckets = data['byBucket'] as List? ?? data['buckets'] as List? ?? [];
        final lines = data['lines'] as List? ?? data['tiers'] as List? ?? [];

        return RefreshIndicator(
          onRefresh: () async {
            if (isClients) {
              ref.invalidate(_clientsAgedProvider);
            } else {
              ref.invalidate(_suppliersAgedProvider);
            }
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Total header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    isClients ? AppColors.positive : AppColors.negative,
                    (isClients ? AppColors.positive : AppColors.negative).withValues(alpha: 0.8),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total ${isClients ? 'créances' : 'dettes'} $type', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    Text(Fmt.currency(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  ])),
                  Icon(isClients ? Icons.people_outlined : Icons.business_outlined, color: Colors.white38, size: 40),
                ]),
              ),
              const SizedBox(height: 14),

              // Aging buckets
              if (buckets.isNotEmpty) ...[
                const Text('Répartition par ancienneté', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Card(child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: buckets.map((b) {
                    final m = b as Map<String, dynamic>;
                    final bucket = m['bucket'] as String? ?? m['label'] as String? ?? '—';
                    final amount = (m['amount'] as num?)?.toDouble() ?? 0;
                    final pct = total > 0 ? (amount / total) : 0.0;
                    final color = _bucketColor(bucket);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(_bucketLabel(bucket), style: const TextStyle(fontSize: 12))),
                          Text(Fmt.compact(amount), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: color)),
                        ]),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: pct.toDouble(), backgroundColor: color.withValues(alpha: 0.1), color: color, minHeight: 6),
                        ),
                      ]),
                    );
                  }).toList()),
                )),
                const SizedBox(height: 14),
              ],

              // Tiers lines
              if (lines.isNotEmpty) ...[
                Text('Détail par ${type == 'clients' ? 'client' : 'fournisseur'} (${lines.length})',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                ...lines.map((l) {
                  final m = l as Map<String, dynamic>;
                  final name = m['name'] as String? ?? m['tierName'] as String? ?? '—';
                  final amt = (m['total'] as num?)?.toDouble() ?? (m['amount'] as num?)?.toDouble() ?? 0;
                  final oldest = (m['oldest'] as String? ?? '').substring(0, 10.clamp(0, (m['oldest'] as String? ?? '').length));
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      dense: true,
                      leading: Icon(isClients ? Icons.person_outlined : Icons.business_outlined, size: 18, color: AppColors.neutral),
                      title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: oldest.isNotEmpty ? Text('Depuis le $oldest', style: const TextStyle(fontSize: 11)) : null,
                      trailing: Text(Fmt.compact(amt),
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                          color: isClients ? AppColors.positive : AppColors.negative)),
                    ),
                  );
                }),
              ],
            ]),
          ),
        );
      },
    );
  }

  Color _bucketColor(String b) {
    if (b.contains('current') || b.contains('0')) return AppColors.positive;
    if (b.contains('30') || b.contains('1–30')) return AppColors.warning;
    if (b.contains('60')) return const Color(0xFFE65100);
    return AppColors.negative;
  }

  String _bucketLabel(String b) {
    const m = {'current': 'Courant', '30days': '1–30 jours', '60days': '31–60 jours', '90days': '61–90 jours', 'over90': '> 90 jours'};
    return m[b] ?? b;
  }
}
