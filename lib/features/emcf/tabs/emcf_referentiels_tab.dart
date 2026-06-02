import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _taxGroupsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfTaxGroups();
});
final _invoiceTypesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfInvoiceTypes();
});
final _paymentTypesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfPaymentTypes();
});
final _currencyRatesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfCurrencyRates();
});

class EmcfReferentielsTab extends ConsumerWidget {
  const EmcfReferentielsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Référentiels DGI', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Données de référence synchronisées depuis la DGI-RDC', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 20),

          _RefCard(
            title: 'Groupes TVA',
            icon: Icons.percent_outlined,
            color: AppColors.primary,
            asyncData: ref.watch(_taxGroupsProvider),
            itemBuilder: (item) {
              final m = item as Map<String, dynamic>;
              final group = m['group'] ?? m['code'] ?? '—';
              final rate = m['rate'] ?? m['tauxTva'] ?? '—';
              final label = m['label'] ?? m['description'] ?? '';
              return _RefRow('Groupe $group', '$rate%', label.toString());
            },
          ),
          const SizedBox(height: 12),

          _RefCard(
            title: 'Types de factures',
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF7C3AED),
            asyncData: ref.watch(_invoiceTypesProvider),
            itemBuilder: (item) {
              final m = item as Map<String, dynamic>;
              final code = m['code'] ?? '—';
              final label = m['label'] ?? m['description'] ?? '—';
              return _RefRow(code.toString(), '', label.toString());
            },
          ),
          const SizedBox(height: 12),

          _RefCard(
            title: 'Modes de paiement',
            icon: Icons.payment_outlined,
            color: AppColors.positive,
            asyncData: ref.watch(_paymentTypesProvider),
            itemBuilder: (item) {
              final m = item as Map<String, dynamic>;
              final code = m['code'] ?? '—';
              final label = m['label'] ?? m['description'] ?? '—';
              return _RefRow(code.toString(), '', label.toString());
            },
          ),
          const SizedBox(height: 12),

          _RefCard(
            title: 'Taux de change DGI',
            icon: Icons.currency_exchange_outlined,
            color: AppColors.warning,
            asyncData: ref.watch(_currencyRatesProvider),
            itemBuilder: (item) {
              final m = item as Map<String, dynamic>;
              final currency = m['currency'] ?? m['devise'] ?? '—';
              final rate = m['rate'] ?? m['taux'] ?? '—';
              final date = m['date'] ?? m['updatedAt'] ?? '';
              return _RefRow(currency.toString(), rate.toString(), date.toString());
            },
          ),
        ],
      ),
    );
  }
}

class _RefCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final AsyncValue<List<dynamic>> asyncData;
  final Widget Function(dynamic item) itemBuilder;

  const _RefCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.asyncData,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18)),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ]),
            const SizedBox(height: 12),
            const Divider(height: 1),
            asyncData.when(
              loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(12),
                child: Text(parseError(e), style: const TextStyle(color: AppColors.negative, fontSize: 12)),
              ),
              data: (items) => items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Aucune donnée — token DGI requis', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    )
                  : Column(children: items.map(itemBuilder).toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _RefRow extends StatelessWidget {
  final String code;
  final String value;
  final String label;
  const _RefRow(this.code, this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
          child: Text(code, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        if (value.isNotEmpty)
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }
}
