import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _templatesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCustomReportTemplates();
});

class CustomReportsTab extends ConsumerWidget {
  const CustomReportsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templates = ref.watch(_templatesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau rapport'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_templatesProvider.future),
        child: templates.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.analytics_outlined, size: 56, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(parseError(e).contains('404') || parseError(e).contains('not found')
                  ? 'Module rapports personnalisés non configuré'
                  : parseError(e),
                style: const TextStyle(color: AppColors.neutral), textAlign: TextAlign.center),
            ]),
          )),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text('Aucun rapport personnalisé', style: TextStyle(color: Colors.grey[600], fontSize: 15)),
                  const SizedBox(height: 6),
                  Text('Créez des rapports avec vos propres formules\n(ex: SUM(7xx), L1-L2, (L3/L1)*100)',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(onPressed: () => _showCreate(context, ref), icon: const Icon(Icons.add), label: const Text('Créer un rapport')),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _TemplateCard(
                    template: list[i] as Map<String, dynamic>,
                    onExecute: () => _showExecute(context, ref, list[i] as Map<String, dynamic>),
                    onDelete: () async {
                      try {
                        await ref.read(apiClientProvider).deleteCustomReportTemplate((list[i] as Map)['id'] as String);
                        ref.invalidate(_templatesProvider);
                      } catch (e) {
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _TemplateDialog(onCreated: () => ref.invalidate(_templatesProvider)));
  }

  void _showExecute(BuildContext context, WidgetRef ref, Map<String, dynamic> template) {
    showDialog(context: context, builder: (_) => _ExecuteDialog(template: template));
  }
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final Map<String, dynamic> template;
  final VoidCallback onExecute;
  final VoidCallback onDelete;
  const _TemplateCard({required this.template, required this.onExecute, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final name = template['name'] as String? ?? '—';
    final lines = template['lines'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.analytics_outlined, color: AppColors.accent, size: 18)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('${lines.length} ligne(s)', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ])),
          ]),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 4, children: lines.take(4).map((l) {
              final m = l as Map<String, dynamic>;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFDDE1E7))),
                child: Text('${m['label']}: ${m['formula']}', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
              );
            }).toList()),
          ],
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton.icon(onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.negative),
              label: const Text('Supprimer', style: TextStyle(color: AppColors.negative))),
            const SizedBox(width: 8),
            ElevatedButton.icon(onPressed: onExecute, icon: const Icon(Icons.play_arrow_outlined, size: 14),
              label: const Text('Exécuter'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8))),
          ]),
        ]),
      ),
    );
  }
}

// ── Execute dialog ────────────────────────────────────────────────────────────

class _ExecuteDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> template;
  const _ExecuteDialog({required this.template});

  @override
  ConsumerState<_ExecuteDialog> createState() => _ExecuteDialogState();
}

class _ExecuteDialogState extends ConsumerState<_ExecuteDialog> {
  String? _selectedFyId;
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  Future<void> _execute() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await ref.read(apiClientProvider).executeCustomReport(
        widget.template['id'] as String,
        fiscalYearId: _selectedFyId,
      );
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultLines = _result?['lines'] as List? ?? [];

    return AlertDialog(
      title: Text('Exécuter — ${widget.template['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 480, child: Column(mainAxisSize: MainAxisSize.min, children: [
        FutureBuilder<List<dynamic>>(
          future: ref.read(apiClientProvider).getFiscalYears(),
          builder: (ctx, snap) {
            if (!snap.hasData || snap.data!.isEmpty) return const SizedBox();
            return DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Exercice fiscal'),
              initialValue: _selectedFyId,
              items: snap.data!.map((f) {
                final m = f as Map<String, dynamic>;
                return DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] as String? ?? '—'));
              }).toList(),
              onChanged: (v) => setState(() => _selectedFyId = v),
            );
          },
        ),
        const SizedBox(height: 12),
        if (_loading) const Center(child: CircularProgressIndicator()),
        if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
        if (resultLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE8ECF0)), borderRadius: BorderRadius.circular(8)),
            child: Column(children: resultLines.map((l) {
              final m = l as Map<String, dynamic>;
              final value = (m['value'] as num?)?.toDouble() ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(children: [
                  Expanded(child: Text(m['label'] as String? ?? '—', style: const TextStyle(fontSize: 13))),
                  Text(Fmt.compact(value), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
                ]),
              );
            }).toList()),
          ),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        ElevatedButton(onPressed: _loading ? null : _execute, child: const Text('Calculer')),
      ],
    );
  }
}

// ── Create template dialog ────────────────────────────────────────────────────

class _TemplateDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _TemplateDialog({required this.onCreated});

  @override
  ConsumerState<_TemplateDialog> createState() => _TemplateDialogState();
}

class _TemplateDialogState extends ConsumerState<_TemplateDialog> {
  final _nameCtrl = TextEditingController();
  final List<Map<String, TextEditingController>> _lines = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _addLine();
  }

  void _addLine() {
    setState(() => _lines.add({
      'label': TextEditingController(),
      'formula': TextEditingController(),
    }));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final m in _lines) { m['label']?.dispose(); m['formula']?.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;
    final lines = _lines.map((m) => {
      'label': m['label']?.text.trim() ?? '',
      'formula': m['formula']?.text.trim() ?? '',
    }).where((l) => l['label']!.isNotEmpty).toList();
    if (lines.isEmpty) return;

    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createCustomReportTemplate({'name': _nameCtrl.text.trim(), 'lines': lines});
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
      title: const Text('Nouveau rapport personnalisé', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom du rapport *')),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(6)),
          child: const Text('Formules : SUM(7xx) = classe 7, SUM(641) = compte, L1 = ligne 1, L1-L2, (L1/L2)*100',
            style: TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Expanded(child: Text('Lignes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          TextButton.icon(onPressed: _addLine, icon: const Icon(Icons.add, size: 14), label: const Text('Ajouter')),
        ]),
        ..._lines.asMap().entries.map((entry) {
          final i = entry.key;
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Container(width: 20, height: 20, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)))),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: entry.value['label'],
                decoration: const InputDecoration(labelText: 'Label', isDense: true),
              )),
              const SizedBox(width: 8),
              Expanded(child: TextFormField(
                controller: entry.value['formula'],
                decoration: const InputDecoration(labelText: 'Formule', isDense: true, hintText: 'SUM(7xx)'),
              )),
              IconButton(icon: const Icon(Icons.delete_outline, size: 14, color: AppColors.negative),
                onPressed: () => setState(() => _lines.removeAt(i))),
            ]),
          );
        }),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}
