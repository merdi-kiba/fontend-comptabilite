import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

class StatementsTab extends ConsumerStatefulWidget {
  const StatementsTab({super.key});

  @override
  ConsumerState<StatementsTab> createState() => _StatementsTabState();
}

class _StatementsTabState extends ConsumerState<StatementsTab> with SingleTickerProviderStateMixin {
  late final TabController _inner;
  String _fyId = '';
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _inner = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() { _inner.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sélecteur exercice + période
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(children: [
            Expanded(child: TextFormField(
              decoration: const InputDecoration(labelText: 'ID Exercice', hintText: 'uuid...', isDense: true),
              onChanged: (v) => setState(() => _fyId = v.trim()),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 70, child: TextFormField(
              initialValue: '$_year',
              decoration: const InputDecoration(labelText: 'Année', isDense: true),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => _year = int.tryParse(v) ?? _year),
            )),
            const SizedBox(width: 8),
            SizedBox(width: 60, child: TextFormField(
              initialValue: '$_month',
              decoration: const InputDecoration(labelText: 'Mois', isDense: true),
              keyboardType: TextInputType.number,
              onChanged: (v) => setState(() => _month = int.tryParse(v) ?? _month),
            )),
          ]),
        ),

        TabBar(
          controller: _inner,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Bilan'),
            Tab(text: 'Résultat'),
            Tab(text: 'TVA'),
            Tab(text: 'TAFIRE'),
          ],
        ),

        Expanded(child: TabBarView(
          controller: _inner,
          children: [
            _BalanceSheetView(fyId: _fyId),
            _IncomeStatementView(fyId: _fyId),
            _VatReturnView(year: _year, month: _month),
            _TafireView(fyId: _fyId),
          ],
        )),
      ],
    );
  }
}

// ── Bilan ─────────────────────────────────────────────────────────────────────

class _BalanceSheetView extends ConsumerStatefulWidget {
  final String fyId;
  const _BalanceSheetView({required this.fyId});

  @override
  ConsumerState<_BalanceSheetView> createState() => _BalanceSheetViewState();
}

class _BalanceSheetViewState extends ConsumerState<_BalanceSheetView> {
  Map<String, dynamic>? _data;
  bool _loading = false;

  Future<void> _load() async {
    if (widget.fyId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getBalanceSheet(widget.fyId);
      setState(() => _data = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actif = _data?['actif'] as Map? ?? {};
    final passif = _data?['passif'] as Map? ?? {};
    final totalActif = (actif['total'] as num?)?.toDouble() ?? 0;
    final totalPassif = (passif['total'] as num?)?.toDouble() ?? 0;
    final balanced = (totalActif - totalPassif).abs() < 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Charger le bilan')),
          const SizedBox(height: 16),
          if (_data != null) ...[
            // Équilibre
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: balanced ? AppColors.positive.withValues(alpha: 0.06) : AppColors.negative.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: balanced ? AppColors.positive.withValues(alpha: 0.2) : AppColors.negative.withValues(alpha: 0.2)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Total ACTIF: ${Fmt.currency(totalActif)}', style: TextStyle(fontWeight: FontWeight.w700, color: balanced ? AppColors.positive : AppColors.negative)),
                Icon(balanced ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: balanced ? AppColors.positive : AppColors.negative),
                Text('Total PASSIF: ${Fmt.currency(totalPassif)}', style: TextStyle(fontWeight: FontWeight.w700, color: balanced ? AppColors.positive : AppColors.negative)),
              ]),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _StatementSection('ACTIF', actif, AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _StatementSection('PASSIF', passif, AppColors.warning)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Compte de résultat ────────────────────────────────────────────────────────

class _IncomeStatementView extends ConsumerStatefulWidget {
  final String fyId;
  const _IncomeStatementView({required this.fyId});

  @override
  ConsumerState<_IncomeStatementView> createState() => _IncomeStatementViewState();
}

class _IncomeStatementViewState extends ConsumerState<_IncomeStatementView> {
  Map<String, dynamic>? _data;
  bool _loading = false;

  Future<void> _load() async {
    if (widget.fyId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getIncomeStatement(widget.fyId);
      setState(() => _data = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final revenue = (_data?['totalRevenue'] as num?)?.toDouble() ?? 0;
    final expenses = (_data?['totalExpenses'] as num?)?.toDouble() ?? 0;
    final result = revenue - expenses;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          ElevatedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Charger le résultat')),
          const SizedBox(height: 16),
          if (_data != null) ...[
            _ResultCard('Chiffre d\'affaires', revenue, AppColors.positive),
            const SizedBox(height: 8),
            _ResultCard('Charges', expenses, AppColors.negative),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (result >= 0 ? AppColors.positive : AppColors.negative).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (result >= 0 ? AppColors.positive : AppColors.negative).withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(result >= 0 ? Icons.trending_up : Icons.trending_down, color: result >= 0 ? AppColors.positive : AppColors.negative),
                const SizedBox(width: 12),
                Expanded(child: Text(result >= 0 ? 'Bénéfice' : 'Déficit', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                Text(Fmt.currency(result.abs()), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: result >= 0 ? AppColors.positive : AppColors.negative)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Déclaration TVA ────────────────────────────────────────────────────────────

class _VatReturnView extends ConsumerStatefulWidget {
  final int year;
  final int month;
  const _VatReturnView({required this.year, required this.month});

  @override
  ConsumerState<_VatReturnView> createState() => _VatReturnViewState();
}

class _VatReturnViewState extends ConsumerState<_VatReturnView> {
  Map<String, dynamic>? _data;
  bool _loading = false;

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getVatReturn(widget.year, widget.month);
      setState(() => _data = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).saveTvaReturn(widget.year, widget.month);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Déclaration TVA sauvegardée')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collectee = (_data?['tvaCollectee'] as num?)?.toDouble() ?? 0;
    final deductible = (_data?['tvaDeductible'] as num?)?.toDouble() ?? 0;
    final net = (_data?['netPayable'] as num?)?.toDouble() ?? (collectee - deductible);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            ElevatedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.calculate_outlined, size: 16), label: const Text('Calculer')),
            const SizedBox(width: 8),
            if (_data != null)
              OutlinedButton.icon(onPressed: _loading ? null : _save, icon: const Icon(Icons.save_outlined, size: 16), label: const Text('Sauvegarder')),
          ]),
          const SizedBox(height: 16),
          if (_data != null) ...[
            _VatRow('TVA collectée (groupe B 16%)', collectee, AppColors.primary),
            _VatRow('TVA déductible', deductible, AppColors.positive),
            const Divider(),
            _VatRow('Net à payer à la DGI', net, net > 0 ? AppColors.negative : AppColors.positive, isBold: true),
          ],
        ],
      ),
    );
  }
}

// ── TAFIRE ────────────────────────────────────────────────────────────────────

class _TafireView extends ConsumerStatefulWidget {
  final String fyId;
  const _TafireView({required this.fyId});

  @override
  ConsumerState<_TafireView> createState() => _TafireViewState();
}

class _TafireViewState extends ConsumerState<_TafireView> {
  Map<String, dynamic>? _data;
  bool _loading = false;

  Future<void> _load() async {
    if (widget.fyId.isEmpty) return;
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).getTafire(widget.fyId);
      setState(() => _data = r);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh, size: 16), label: const Text('Charger TAFIRE')),
          const SizedBox(height: 16),
          if (_data != null) ...[
            const Text('TAFIRE — Tableau de Financement', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            ...(_data!.entries.where((e) => e.value is num).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 13))),
                Text(Fmt.currency((e.value as num).toDouble()), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ]),
            ))),
          ],
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _StatementSection extends StatelessWidget {
  final String title;
  final Map section;
  final Color color;
  const _StatementSection(this.title, this.section, this.color);

  @override
  Widget build(BuildContext context) {
    final items = section['items'] as List? ?? section['lines'] as List? ?? [];
    final total = (section['total'] as num?)?.toDouble() ?? 0;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: color)),
      const Divider(),
      ...items.map((i) {
        final m = i as Map<String, dynamic>;
        return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
          Expanded(child: Text(m['label'] as String? ?? m['name'] as String? ?? '—', style: const TextStyle(fontSize: 12))),
          Text(Fmt.compact((m['amount'] as num?)?.toDouble() ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]));
      }),
      const Divider(),
      Row(children: [
        const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w800))),
        Text(Fmt.currency(total), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
      ]),
    ])));
  }
}

class _ResultCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ResultCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8ECF0))),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
        Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: color)),
      ]),
    );
  }
}

class _VatRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isBold;
  const _VatRow(this.label, this.value, this.color, {this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
        Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, fontSize: isBold ? 16 : 13, color: color)),
      ]),
    );
  }
}
