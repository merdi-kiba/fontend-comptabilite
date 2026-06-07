import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _declYmProvider = StateProvider.autoDispose<({int year, int month})>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

final _cnssProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({int year, int month})>((ref, ym) async {
  return ref.watch(apiClientProvider).getCnssDeclaration(ym.year, ym.month);
});

final _onemProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({int year, int month})>((ref, ym) async {
  return ref.watch(apiClientProvider).getOnemDeclaration(ym.year, ym.month);
});

final _iprProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({int year, int month})>((ref, ym) async {
  return ref.watch(apiClientProvider).getIprDeclaration(ym.year, ym.month);
});

final _declStatusProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({int year, int month})>((ref, ym) async {
  return ref.watch(apiClientProvider).getDeclarationStatus(ym.year, ym.month);
});

class DeclarationsTab extends ConsumerStatefulWidget {
  const DeclarationsTab({super.key});

  @override
  ConsumerState<DeclarationsTab> createState() => _DeclarationsTabState();
}

class _DeclarationsTabState extends ConsumerState<DeclarationsTab>
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
    final ym = ref.watch(_declYmProvider);

    return Column(children: [
      // Month picker
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              final prev = DateTime(ym.year, ym.month - 1);
              ref.read(_declYmProvider.notifier).state = (year: prev.year, month: prev.month);
            },
          ),
          Text('${_monthName(ym.month)} ${ym.year}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final next = DateTime(ym.year, ym.month + 1);
              if (next.isBefore(DateTime.now().add(const Duration(days: 32)))) {
                ref.read(_declYmProvider.notifier).state = (year: next.year, month: next.month);
              }
            },
          ),
          const Spacer(),
          _SubmitButton(ym: ym),
        ]),
      ),
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'CNSS'),
            Tab(text: 'ONEM'),
            Tab(text: 'IPR'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(controller: _tabs, children: [
          _DeclarationView(provider: _cnssProvider(ym), type: 'CNSS', ym: ym),
          _DeclarationView(provider: _onemProvider(ym), type: 'ONEM', ym: ym),
          _DeclarationView(provider: _iprProvider(ym), type: 'IPR', ym: ym),
        ]),
      ),
    ]);
  }
}

// ── Submit button ─────────────────────────────────────────────────────────────

class _SubmitButton extends ConsumerStatefulWidget {
  final ({int year, int month}) ym;
  const _SubmitButton({required this.ym});

  @override
  ConsumerState<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends ConsumerState<_SubmitButton> {
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).submitDeclarations(widget.ym.year, widget.ym.month, ['CNSS', 'ONEM', 'IPR']);
      ref.invalidate(_declStatusProvider(widget.ym));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déclarations marquées comme soumises'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _loading ? null : _submit,
      icon: _loading
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.cloud_upload_outlined, size: 16),
      label: const Text('Soumettre'),
      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
    );
  }
}

// ── Declaration view ──────────────────────────────────────────────────────────

class _DeclarationView extends ConsumerWidget {
  final ProviderListenable<AsyncValue<Map<String, dynamic>>> provider;
  final String type;
  final ({int year, int month}) ym;
  const _DeclarationView({required this.provider, required this.type, required this.ym});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(provider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Aucune donnée $type pour ${_monthName(ym.month)} ${ym.year}', style: TextStyle(color: Colors.grey[500])),
          const SizedBox(height: 4),
          Text('Générez et validez les fiches de paie du mois d\'abord.', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ]),
      )),
      data: (data) {
        final status = data['status'] as String? ?? 'DRAFT';
        final isSubmitted = status.toUpperCase() == 'SUBMITTED';
        final totalBase = toDouble(data['totalBase']);
        final totalEmp = toDouble(data['totalEmployee']);
        final totalEmpr = toDouble(data['totalEmployer']);
        final lines = data['lines'] as List? ?? [];

        return RefreshIndicator(
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Status & totals
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (isSubmitted ? AppColors.positive : AppColors.warning).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSubmitted ? AppColors.positive : AppColors.warning),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(isSubmitted ? Icons.check_circle_outline : Icons.pending_outlined,
                      color: isSubmitted ? AppColors.positive : AppColors.warning, size: 18),
                    const SizedBox(width: 8),
                    Text('Déclaration $type — ${_monthName(ym.month)} ${ym.year}',
                      style: TextStyle(fontWeight: FontWeight.w700, color: isSubmitted ? AppColors.positive : AppColors.warning)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: (isSubmitted ? AppColors.positive : AppColors.warning).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(isSubmitted ? 'SOUMISE' : 'BROUILLON',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: isSubmitted ? AppColors.positive : AppColors.warning)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _total('Base', totalBase),
                    const SizedBox(width: 12),
                    if (totalEmp > 0) _total('Employé', totalEmp),
                    if (totalEmpr > 0) ...[const SizedBox(width: 12), _total('Patronal', totalEmpr)],
                  ]),
                ]),
              ),
              if (lines.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('${lines.length} employé(s)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DataTable(
                  columnSpacing: 12,
                  headingRowHeight: 36,
                  columns: _columns(type),
                  rows: lines.map((l) => _dataRow(l as Map<String, dynamic>, type)).toList(),
                ),
              ],
            ]),
          ),
        );
      },
    );
  }

  List<DataColumn> _columns(String type) {
    final base = [
      const DataColumn(label: Text('Employé', style: TextStyle(fontSize: 12))),
      const DataColumn(label: Text('N° CNSS', style: TextStyle(fontSize: 12))),
      const DataColumn(label: Text('Brut', style: TextStyle(fontSize: 12)), numeric: true),
    ];
    if (type == 'CNSS') {
      return [...base,
        const DataColumn(label: Text('Salarié', style: TextStyle(fontSize: 12)), numeric: true),
        const DataColumn(label: Text('Patronal', style: TextStyle(fontSize: 12)), numeric: true),
      ];
    } else if (type == 'ONEM') {
      return [...base, const DataColumn(label: Text('ONEM', style: TextStyle(fontSize: 12)), numeric: true)];
    } else {
      return [...base, const DataColumn(label: Text('IPR', style: TextStyle(fontSize: 12)), numeric: true)];
    }
  }

  DataRow _dataRow(Map<String, dynamic> l, String type) {
    final name = l['name'] as String? ?? '${l['firstName'] ?? ''} ${l['lastName'] ?? ''}'.trim();
    final cnss = l['cnssNumber'] as String? ?? '—';
    final gross = toDouble(l['grossSalary']);
    final cells = [
      DataCell(Text(name, style: const TextStyle(fontSize: 12))),
      DataCell(Text(cnss, style: const TextStyle(fontSize: 11))),
      DataCell(Text(Fmt.compact(gross), style: const TextStyle(fontSize: 12))),
    ];
    if (type == 'CNSS') {
      final emp = toDouble(l['cnssEmployee']);
      final empr = toDouble(l['cnssEmployer']);
      cells.add(DataCell(Text(Fmt.compact(emp), style: const TextStyle(fontSize: 12))));
      cells.add(DataCell(Text(Fmt.compact(empr), style: const TextStyle(fontSize: 12))));
    } else if (type == 'ONEM') {
      final onem = toDouble(l['onem']) != 0 ? toDouble(l['onem']) : toDouble(l['onemEmployer']);
      cells.add(DataCell(Text(Fmt.compact(onem), style: const TextStyle(fontSize: 12))));
    } else {
      final ipr = toDouble(l['ipr']);
      cells.add(DataCell(Text(Fmt.compact(ipr), style: const TextStyle(fontSize: 12))));
    }
    return DataRow(cells: cells);
  }

  Widget _total(String label, double value) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
        Text(Fmt.compact(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      ]),
    ),
  );
}

String _monthName(int m) {
  const names = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
  return m >= 1 && m <= 12 ? names[m] : '$m';
}
