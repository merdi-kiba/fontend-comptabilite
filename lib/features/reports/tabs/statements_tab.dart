import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _fyListProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getFiscalYears();
});

final _selectedFyProvider = StateProvider.autoDispose<String?>((ref) => null);
final _selectedStatementProvider = StateProvider.autoDispose<int>((ref) => 0);

final _balanceSheetProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, fyId) async {
  return ref.watch(apiClientProvider).getBalanceSheet(fyId);
});
final _incomeStatementProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, fyId) async {
  return ref.watch(apiClientProvider).getIncomeStatement(fyId);
});
final _cashFlowProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, fyId) async {
  return ref.watch(apiClientProvider).getCashFlow(fyId);
});
final _tafireProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, fyId) async {
  return ref.watch(apiClientProvider).getTafire(fyId);
});

class StatementsTab extends ConsumerWidget {
  const StatementsTab({super.key});

  static const _statements = ['Bilan', 'Compte de résultat', 'Flux trésorerie', 'TAFIRE'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fyList = ref.watch(_fyListProvider);
    final selectedFyId = ref.watch(_selectedFyProvider);
    final statIdx = ref.watch(_selectedStatementProvider);

    return Column(children: [
      // Controls
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // Fiscal year selector
          Expanded(child: fyList.when(
            loading: () => const SizedBox(height: 36),
            error: (e, st) => const SizedBox(),
            data: (fys) {
              final effectiveId = selectedFyId ?? (fys.isNotEmpty ? (fys.first as Map)['id'] as String? : null);
              return DropdownButton<String>(
                isExpanded: true,
                underline: const SizedBox(),
                value: effectiveId,
                items: fys.map((fy) {
                  final m = fy as Map<String, dynamic>;
                  return DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] as String? ?? '—', style: const TextStyle(fontSize: 13)));
                }).toList(),
                onChanged: (v) => ref.read(_selectedFyProvider.notifier).state = v,
              );
            },
          )),
        ]),
      ),
      // Statement type tabs
      Container(
        color: Colors.white,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(children: List.generate(_statements.length, (i) {
            final selected = statIdx == i;
            return GestureDetector(
              onTap: () => ref.read(_selectedStatementProvider.notifier).state = i,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(_statements[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : Colors.grey[700])),
              ),
            );
          })),
        ),
      ),
      // Content
      Expanded(child: fyList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (fys) {
          final fyId = selectedFyId ?? (fys.isNotEmpty ? (fys.first as Map)['id'] as String? : null);
          if (fyId == null) return const Center(child: Text('Créez un exercice fiscal d\'abord'));
          switch (statIdx) {
            case 0: return _BalanceSheetView(fyId: fyId);
            case 1: return _IncomeStatementView(fyId: fyId);
            case 2: return _CashFlowView(fyId: fyId);
            case 3: return _TafireView(fyId: fyId);
            default: return const SizedBox();
          }
        },
      )),
    ]);
  }
}

// ── Balance sheet ─────────────────────────────────────────────────────────────

class _BalanceSheetView extends ConsumerWidget {
  final String fyId;
  const _BalanceSheetView({required this.fyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_balanceSheetProvider(fyId));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (d) {
        final actif = d['actif'] as Map? ?? {};
        final passif = d['passif'] as Map? ?? {};
        final balanced = d['balanced'] as bool? ?? false;
        final totalA = (actif['total'] as num?)?.toDouble() ?? 0;
        final totalP = (passif['total'] as num?)?.toDouble() ?? 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: (balanced ? AppColors.positive : AppColors.negative).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                Icon(balanced ? Icons.check_circle_outline : Icons.warning_outlined, size: 16,
                  color: balanced ? AppColors.positive : AppColors.negative),
                const SizedBox(width: 8),
                Text(balanced ? 'Bilan équilibré' : 'Bilan déséquilibré — vérifier les écritures',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: balanced ? AppColors.positive : AppColors.negative)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _FinancialSection('ACTIF', actif, totalA, AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _FinancialSection('PASSIF', passif, totalP, AppColors.accent)),
            ]),
          ]),
        );
      },
    );
  }
}

class _FinancialSection extends StatelessWidget {
  final String title;
  final Map data;
  final double total;
  final Color color;
  const _FinancialSection(this.title, this.data, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.where((e) => e.key != 'total').toList();
    return Card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        const Divider(),
        ...entries.map((e) {
          // API returns nested objects {total, details} or plain numbers
          final raw = e.value is Map ? (e.value as Map)['total'] : e.value;
          final amount = (raw as num?)?.toDouble() ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(_labelify(e.key), style: const TextStyle(fontSize: 12))),
              Text(Fmt.compact(amount),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          );
        }),
        const Divider(),
        Row(children: [
          Expanded(child: Text('Total $title', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: color))),
          Text(Fmt.currency(total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
        ]),
      ]),
    ));
  }

  String _labelify(String key) {
    final map = {
      'immobilise': 'Immobilisations', 'immobilisations': 'Immobilisations',
      'stocks': 'Stocks', 'creances': 'Créances clients', 'creancesClients': 'Créances clients',
      'tresorerie': 'Trésorerie', 'capitauxPropres': 'Capitaux propres',
      'dettesFinancieres': 'Dettes financières', 'dettesExploitation': 'Dettes exploitation',
      'autresActifs': 'Autres actifs', 'autresPassifs': 'Autres passifs',
      'resultatNet': 'Résultat net', 'provisions': 'Provisions',
    };
    return map[key] ?? key;
  }
}

// ── Income statement ──────────────────────────────────────────────────────────

class _IncomeStatementView extends ConsumerWidget {
  final String fyId;
  const _IncomeStatementView({required this.fyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_incomeStatementProvider(fyId));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (d) {
        final produits = d['produits'] as Map? ?? {};
        final charges = d['charges'] as Map? ?? {};
        final resultat = (d['resultatNet'] as num?)?.toDouble() ?? 0;
        final isProfit = resultat >= 0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // Result banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  isProfit ? AppColors.positive : AppColors.negative,
                  (isProfit ? AppColors.positive : AppColors.negative).withValues(alpha: 0.8),
                ]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isProfit ? 'Bénéfice net' : 'Perte nette', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(Fmt.currency(resultat.abs()), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                ])),
                Icon(isProfit ? Icons.trending_up : Icons.trending_down, color: Colors.white38, size: 44),
              ]),
            ),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _FinancialSection('PRODUITS', produits, (produits['total'] as num?)?.toDouble() ?? 0, AppColors.positive)),
              const SizedBox(width: 12),
              Expanded(child: _FinancialSection('CHARGES', charges, (charges['total'] as num?)?.toDouble() ?? 0, AppColors.negative)),
            ]),
          ]),
        );
      },
    );
  }
}

// ── Cash flow ─────────────────────────────────────────────────────────────────

class _CashFlowView extends ConsumerWidget {
  final String fyId;
  const _CashFlowView({required this.fyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_cashFlowProvider(fyId));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (d) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _JsonDataCard('Flux de trésorerie', d),
      ),
    );
  }
}

// ── TAFIRE ────────────────────────────────────────────────────────────────────

class _TafireView extends ConsumerWidget {
  final String fyId;
  const _TafireView({required this.fyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(_tafireProvider(fyId));
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (d) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _JsonDataCard('TAFIRE', d),
      ),
    );
  }
}

// ── Generic JSON display card ─────────────────────────────────────────────────

class _JsonDataCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> data;
  const _JsonDataCard(this.title, this.data);

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();
    return Card(child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const Divider(),
        ...entries.map((e) {
          final val = e.value;
          if (val is Map) {
            return _SubSection(e.key, val);
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
              Text(
                val is num ? Fmt.compact(val.toDouble()) : '$val',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ]),
          );
        }),
      ]),
    ));
  }
}

class _SubSection extends StatelessWidget {
  final String title;
  final Map data;
  const _SubSection(this.title, this.data);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ...data.entries.map((e) => Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 0, 2),
          child: Row(children: [
            Expanded(child: Text('${e.key}', style: const TextStyle(fontSize: 12))),
            Text(e.value is num ? Fmt.compact((e.value as num).toDouble()) : '${e.value}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        )),
      ]),
    );
  }
}
