import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _ccProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCostCenters();
});

final _projectsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getProjects();
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comptabilité analytique'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.hub_outlined, size: 16), text: 'Centres de coût'),
            Tab(icon: Icon(Icons.work_outline, size: 16), text: 'Projets'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _CostCentersView(),
          _ProjectsView(),
        ],
      ),
    );
  }
}

// ── Centres de coût ───────────────────────────────────────────────────────────

class _CostCentersView extends ConsumerWidget {
  const _CostCentersView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ccAsync = ref.watch(_ccProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau centre'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_ccProvider.future),
        child: ccAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (ccs) => ccs.isEmpty
              ? _Empty('Aucun centre de coût', Icons.hub_outlined, () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: ccs.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final cc = ccs[i] as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.hub_outlined, color: AppColors.primary, size: 20)),
                        title: Text('${cc['code']} – ${cc['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Text(cc['description'] as String? ?? '', style: const TextStyle(fontSize: 12)),
                        trailing: IconButton(
                          icon: const Icon(Icons.bar_chart_outlined, size: 18),
                          tooltip: 'Rapport',
                          onPressed: () => _showReport(context, ref, cc),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateCCDialog(onCreated: () => ref.invalidate(_ccProvider)));
  }

  void _showReport(BuildContext context, WidgetRef ref, Map<String, dynamic> cc) {
    showDialog(context: context, builder: (_) => _CCReportDialog(cc: cc));
  }
}

// ── Projets ───────────────────────────────────────────────────────────────────

class _ProjectsView extends ConsumerWidget {
  const _ProjectsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projAsync = ref.watch(_projectsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau projet'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_projectsProvider.future),
        child: projAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (projects) => projects.isEmpty
              ? _Empty('Aucun projet', Icons.work_outline, () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: projects.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final p = projects[i] as Map<String, dynamic>;
                    final status = p['status'] as String? ?? 'ACTIVE';
                    final budget = (p['budget'] as num?)?.toDouble() ?? 0;
                    final color = status == 'ACTIVE' ? AppColors.positive : Colors.grey;
                    return Card(
                      child: ListTile(
                        leading: Container(width: 40, height: 40,
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.work_outline, color: color, size: 20)),
                        title: Text('${p['code']} – ${p['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        subtitle: Row(children: [
                          Text('Budget: ${Fmt.compact(budget)} CDF', style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 8),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                            child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700))),
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.bar_chart_outlined, size: 18), tooltip: 'Rapport', onPressed: () => _showReport(context, ref, p)),
                          if (status == 'ACTIVE')
                            IconButton(icon: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.warning), tooltip: 'Clôturer',
                              onPressed: () async {
                                await ref.read(apiClientProvider).closeProject(p['id'] as String);
                                ref.invalidate(_projectsProvider);
                              }),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateProjectDialog(onCreated: () => ref.invalidate(_projectsProvider)));
  }

  void _showReport(BuildContext context, WidgetRef ref, Map<String, dynamic> project) {
    showDialog(context: context, builder: (_) => _ProjectReportDialog(project: project));
  }
}

// ── Dialogs ───────────────────────────────────────────────────────────────────

class _CCReportDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> cc;
  const _CCReportDialog({required this.cc});

  @override
  ConsumerState<_CCReportDialog> createState() => _CCReportDialogState();
}

class _CCReportDialogState extends ConsumerState<_CCReportDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final now = DateTime.now();
      final r = await ref.read(apiClientProvider).getCostCenterReport(
        widget.cc['id'] as String,
        '${now.year}-01-01',
        now.toIso8601String().substring(0, 10),
      );
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rapport: ${widget.cc['name']}'),
      content: SizedBox(
        width: 420, height: 300,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const Center(child: Text('Données non disponibles'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row('Charges imputées', (_data!['totalCharges'] as num?)?.toDouble() ?? 0, AppColors.negative),
                      _row('Produits imputés', (_data!['totalRevenue'] as num?)?.toDouble() ?? 0, AppColors.positive),
                      const Divider(),
                      _row('Résultat net', (_data!['netResult'] as num?)?.toDouble() ?? 0, AppColors.primary, bold: true),
                    ],
                  ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }

  Widget _row(String label, double value, Color color, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal))),
      Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _ProjectReportDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> project;
  const _ProjectReportDialog({required this.project});

  @override
  ConsumerState<_ProjectReportDialog> createState() => _ProjectReportDialogState();
}

class _ProjectReportDialogState extends ConsumerState<_ProjectReportDialog> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).getProjectReport(widget.project['id'] as String);
      if (mounted) setState(() { _data = r; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final budget = (_data?['budget'] as num?)?.toDouble() ?? (widget.project['budget'] as num?)?.toDouble() ?? 0;
    final spent = (_data?['totalSpent'] as num?)?.toDouble() ?? 0;
    final pct = budget > 0 ? (spent / budget).clamp(0.0, 1.5) : 0.0;

    return AlertDialog(
      title: Text('Rapport: ${widget.project['name']}'),
      content: SizedBox(
        width: 420, height: 280,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _projRow('Budget alloué', budget, AppColors.primary),
                  _projRow('Dépensé', spent, AppColors.negative),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      minHeight: 8,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(pct > 1 ? AppColors.negative : AppColors.positive),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${(pct * 100).toStringAsFixed(1)}% du budget consommé',
                    style: TextStyle(fontSize: 12, color: pct > 0.9 ? AppColors.negative : Colors.grey[600])),
                ],
              ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))],
    );
  }

  Widget _projRow(String label, double value, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
      Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

class _CreateCCDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateCCDialog({required this.onCreated});

  @override
  ConsumerState<_CreateCCDialog> createState() => _CreateCCDialogState();
}

class _CreateCCDialogState extends ConsumerState<_CreateCCDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_codeCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createCostCenter({'code': _codeCtrl.text.trim(), 'name': _nameCtrl.text.trim()});
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau centre de coût'),
      content: SizedBox(width: 360, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'VENTES')),
        const SizedBox(height: 10),
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Libellé *')),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}

class _CreateProjectDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateProjectDialog({required this.onCreated});

  @override
  ConsumerState<_CreateProjectDialog> createState() => _CreateProjectDialogState();
}

class _CreateProjectDialogState extends ConsumerState<_CreateProjectDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); _nameCtrl.dispose(); _budgetCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createProject({
        'code': _codeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'budget': double.tryParse(_budgetCtrl.text) ?? 0,
        'currency': 'CDF',
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouveau projet analytique'),
      content: SizedBox(width: 380, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'PROJ-001')),
        const SizedBox(height: 10),
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom *')),
        const SizedBox(height: 10),
        TextFormField(controller: _budgetCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Budget (CDF)', suffixText: 'CDF')),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onAdd;
  const _Empty(this.label, this.icon, this.onAdd);

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(icon, size: 64, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text(label, style: TextStyle(color: Colors.grey[600])),
    const SizedBox(height: 8),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer')),
  ]));
}
