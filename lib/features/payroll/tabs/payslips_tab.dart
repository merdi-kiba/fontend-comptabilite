import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _selectedMonthProvider = StateProvider.autoDispose<({int year, int month})>((ref) {
  final now = DateTime.now();
  return (year: now.year, month: now.month);
});

final _payslipsProvider = FutureProvider.autoDispose.family<List<dynamic>, ({int year, int month})>((ref, ym) async {
  return ref.watch(apiClientProvider).getPayslips(year: ym.year, month: ym.month);
});

final _summaryProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, ({int year, int month})>((ref, ym) async {
  return ref.watch(apiClientProvider).getPayslipSummary(ym.year, ym.month);
});

class PayslipsTab extends ConsumerWidget {
  const PayslipsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ym = ref.watch(_selectedMonthProvider);
    final payslips = ref.watch(_payslipsProvider(ym));
    final summary = ref.watch(_summaryProvider(ym));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'gen_all',
            onPressed: () => _generateAll(context, ref, ym),
            tooltip: 'Générer toutes les fiches du mois',
            backgroundColor: AppColors.neutral,
            child: const Icon(Icons.auto_awesome_outlined, size: 18),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'gen_one',
            onPressed: () => _showGenerate(context, ref, ym),
            icon: const Icon(Icons.add),
            label: const Text('Nouvelle fiche'),
            backgroundColor: AppColors.primary,
          ),
        ],
      ),
      body: Column(children: [
        // Month selector
        _MonthSelector(ym: ym, onChanged: (y, m) => ref.read(_selectedMonthProvider.notifier).state = (year: y, month: m)),
        // Summary
        summary.when(
          loading: () => const SizedBox(height: 4),
          error: (_, __) => const SizedBox(),
          data: (s) => _SummaryBanner(data: s, ym: ym, onPostAll: () => _postAll(context, ref, ym)),
        ),
        // List
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(_payslipsProvider(ym));
              ref.invalidate(_summaryProvider(ym));
            },
            child: payslips.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (list) => list.isEmpty
                  ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucune fiche pour ${_monthName(ym.month)} ${ym.year}', style: TextStyle(color: Colors.grey[500])),
                      const SizedBox(height: 4),
                      Text('Générez toutes les fiches avec le bouton ✨', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final s = list[i] as Map<String, dynamic>;
                        return _PayslipCard(
                          slip: s,
                          onPost: s['status'] == 'DRAFT'
                              ? () => _post(context, ref, ym, s['id'] as String)
                              : null,
                        );
                      },
                    ),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _post(BuildContext context, WidgetRef ref, ({int year, int month}) ym, String id) async {
    try {
      await ref.read(apiClientProvider).postPayslip(id);
      ref.invalidate(_payslipsProvider(ym));
      ref.invalidate(_summaryProvider(ym));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiche validée — écriture paie générée'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  Future<void> _postAll(BuildContext context, WidgetRef ref, ({int year, int month}) ym) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Valider toutes les fiches'),
      content: Text('Poster toutes les fiches DRAFT de ${_monthName(ym.month)} ${ym.year} ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
        ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Valider tout')),
      ],
    ));
    if (ok != true) return;
    try {
      final r = await ref.read(apiClientProvider).postMonthlyPayslips(ym.year, ym.month);
      ref.invalidate(_payslipsProvider(ym));
      ref.invalidate(_summaryProvider(ym));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['posted'] ?? 0} fiches validées'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  Future<void> _generateAll(BuildContext context, WidgetRef ref, ({int year, int month}) ym) async {
    try {
      final r = await ref.read(apiClientProvider).generateMonthlyPayslips(ym.year, ym.month);
      ref.invalidate(_payslipsProvider(ym));
      ref.invalidate(_summaryProvider(ym));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['generated'] ?? 0} fiches générées'), backgroundColor: AppColors.positive));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  void _showGenerate(BuildContext context, WidgetRef ref, ({int year, int month}) ym) {
    showDialog(context: context, builder: (_) => _GenerateDialog(
      ym: ym,
      onGenerated: () { ref.invalidate(_payslipsProvider(ym)); ref.invalidate(_summaryProvider(ym)); },
    ));
  }
}

// ── Month selector ────────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final ({int year, int month}) ym;
  final void Function(int year, int month) onChanged;
  const _MonthSelector({required this.ym, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            final prev = DateTime(ym.year, ym.month - 1);
            onChanged(prev.year, prev.month);
          },
        ),
        Text('${_monthName(ym.month)} ${ym.year}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            final next = DateTime(ym.year, ym.month + 1);
            if (next.isBefore(DateTime.now().add(const Duration(days: 32)))) {
              onChanged(next.year, next.month);
            }
          },
        ),
      ]),
    );
  }
}

// ── Summary banner ────────────────────────────────────────────────────────────

class _SummaryBanner extends StatelessWidget {
  final Map<String, dynamic> data;
  final ({int year, int month}) ym;
  final VoidCallback onPostAll;
  const _SummaryBanner({required this.data, required this.ym, required this.onPostAll});

  @override
  Widget build(BuildContext context) {
    final count = data['employeeCount'] as int? ?? 0;
    final totalGross = toDouble(data['totalGross']);
    final totalNet = toDouble(data['totalNet']);
    final statusMap = data['payslipStatus'] as Map? ?? {};
    final draftCount = statusMap['DRAFT'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.85)]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count employé(s) · ${_monthName(ym.month)} ${ym.year}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('Brut : ${Fmt.compact(totalGross)}  →  Net : ${Fmt.compact(totalNet)}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
        if (draftCount > 0)
          TextButton(
            onPressed: onPostAll,
            style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.white.withValues(alpha: 0.15)),
            child: Text('Valider $draftCount', style: const TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }
}

// ── Payslip card ──────────────────────────────────────────────────────────────

class _PayslipCard extends StatelessWidget {
  final Map<String, dynamic> slip;
  final VoidCallback? onPost;
  const _PayslipCard({required this.slip, required this.onPost});

  @override
  Widget build(BuildContext context) {
    final name = slip['employeeName'] as String? ?? '—';
    final gross = toDouble(slip['grossSalary']);
    final net = toDouble(slip['netSalary']);
    final ipr = toDouble(slip['ipr']);
    final cnssEmp = toDouble(slip['cnssEmployee']);
    final status = slip['status'] as String? ?? 'DRAFT';
    final isPosted = status == 'POSTED';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14))),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isPosted ? AppColors.positive : AppColors.warning).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(isPosted ? 'VALIDÉE' : 'BROUILLON',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: isPosted ? AppColors.positive : AppColors.warning)),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _chip('Brut', Fmt.compact(gross), Colors.grey[700]!),
            const SizedBox(width: 8),
            _chip('IPR', Fmt.compact(ipr), AppColors.warning),
            const SizedBox(width: 8),
            _chip('CNSS', Fmt.compact(cnssEmp), AppColors.neutral),
            const Spacer(),
            Text('Net : ${Fmt.compact(net)}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.positive)),
          ]),
          if (onPost != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight,
              child: ElevatedButton.icon(onPressed: onPost, icon: const Icon(Icons.check, size: 14), label: const Text('Valider'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)))),
          ],
        ]),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
    child: Column(children: [
      Text(label, style: TextStyle(fontSize: 9, color: color)),
      Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ── Generate dialog ───────────────────────────────────────────────────────────

class _GenerateDialog extends ConsumerStatefulWidget {
  final ({int year, int month}) ym;
  final VoidCallback onGenerated;
  const _GenerateDialog({required this.ym, required this.onGenerated});

  @override
  ConsumerState<_GenerateDialog> createState() => _GenerateDialogState();
}

class _GenerateDialogState extends ConsumerState<_GenerateDialog> {
  List<dynamic> _employees = [];
  String? _selectedEmpId;
  bool _loading = false;
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getEmployees(status: 'ACTIVE');
      if (mounted) setState(() { _employees = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    if (_selectedEmpId == null) return;
    setState(() { _generating = true; _error = null; });
    try {
      await ref.read(apiClientProvider).generatePayslip(_selectedEmpId!, widget.ym.year, widget.ym.month);
      widget.onGenerated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Fiche de paie — ${_monthName(widget.ym.month)} ${widget.ym.year}', style: const TextStyle(fontWeight: FontWeight.w700)),
    content: SizedBox(width: 360, child: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Employé *'),
              initialValue: _selectedEmpId,
              items: _employees.map((e) {
                final m = e as Map<String, dynamic>;
                final name = '${m['firstName']} ${m['lastName']}'.trim();
                return DropdownMenuItem<String>(value: m['id'] as String, child: Text(name));
              }).toList(),
              onChanged: (v) => setState(() => _selectedEmpId = v),
            ),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
          ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      ElevatedButton(onPressed: _generating ? null : _submit,
        child: _generating ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Générer')),
    ],
  );
}

String _monthName(int m) {
  const names = ['', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
  return m >= 1 && m <= 12 ? names[m] : '$m';
}
