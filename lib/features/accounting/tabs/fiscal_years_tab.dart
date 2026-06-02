import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _fiscalYearsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getFiscalYears();
});

class FiscalYearsTab extends ConsumerWidget {
  const FiscalYearsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fyAsync = ref.watch(_fiscalYearsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateFY(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvel exercice'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_fiscalYearsProvider.future),
        child: fyAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (years) => years.isEmpty
              ? _EmptyFY(onAdd: () => _showCreateFY(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: years.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _FiscalYearCard(
                    fy: years[i] as Map<String, dynamic>,
                    onTap: () => _showFYDetail(context, ref, years[i] as Map<String, dynamic>),
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreateFY(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateFYDialog(
      onCreated: () => ref.invalidate(_fiscalYearsProvider),
    ));
  }

  void _showFYDetail(BuildContext context, WidgetRef ref, Map<String, dynamic> fy) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FYDetailSheet(fy: fy, ref: ref),
    );
  }
}

class _FiscalYearCard extends StatelessWidget {
  final Map<String, dynamic> fy;
  final VoidCallback onTap;
  const _FiscalYearCard({required this.fy, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = fy['name'] as String? ?? '—';
    final status = fy['status'] as String? ?? 'OPEN';
    final start = fy['startDate'] as String? ?? '';
    final end = fy['endDate'] as String? ?? '';

    return Card(
      child: ListTile(
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _statusColor(status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.calendar_month_outlined, color: _statusColor(status), size: 22),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
          '${start.length >= 10 ? start.substring(0, 10) : start} → ${end.length >= 10 ? end.substring(0, 10) : end}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          _StatusBadge(status),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
        ]),
        onTap: onTap,
      ),
    );
  }

  Color _statusColor(String s) => switch (s) {
    'OPEN' => AppColors.positive,
    'CLOSED' => Colors.grey,
    _ => AppColors.warning,
  };
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'OPEN' => AppColors.positive,
      'CLOSED' => Colors.grey,
      _ => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

// ── Détail exercice (périodes + checklist clôture) ────────────────────────────

class _FYDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> fy;
  final WidgetRef ref;
  const _FYDetailSheet({required this.fy, required this.ref});

  @override
  ConsumerState<_FYDetailSheet> createState() => _FYDetailSheetState();
}

class _FYDetailSheetState extends ConsumerState<_FYDetailSheet> {
  List<dynamic> _periods = [];
  Map<String, dynamic>? _checklist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPeriods();
  }

  Future<void> _loadPeriods() async {
    try {
      final fyId = widget.fy['id'] as String;
      final p = await ref.read(apiClientProvider).getFiscalYearPeriods(fyId);
      Map<String, dynamic>? cl;
      try { cl = await ref.read(apiClientProvider).getClosureChecklist(fyId); } catch (_) {}
      if (mounted) setState(() { _periods = p; _checklist = cl; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fyId = widget.fy['id'] as String;
    final name = widget.fy['name'] as String? ?? '—';
    final status = widget.fy['status'] as String? ?? 'OPEN';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
              _StatusBadge(status),
              if (status == 'OPEN')
                TextButton.icon(
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final cl = await ref.read(apiClientProvider).getClosureChecklist(fyId);
                    final issues = (cl['blockers'] as List?)?.cast<String>() ?? [];
                    if (!mounted) return;
                    if (issues.isNotEmpty) {
                      messenger.showSnackBar(SnackBar(content: Text('Bloqué: ${issues.join(", ")}'), backgroundColor: AppColors.negative));
                      return;
                    }
                    await ref.read(apiClientProvider).closeFiscalYear(fyId);
                    if (!mounted) return;
                    nav.pop();
                    ref.invalidate(_fiscalYearsProvider);
                  },
                  icon: const Icon(Icons.lock_outline, size: 16),
                  label: const Text('Clôturer'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.warning),
                ),
            ]),
            const Divider(),

            // Checklist clôture
            if (_checklist != null) ...[
              const Text('Checklist clôture', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 8),
              ...(_checklist!.entries.where((e) => e.value is bool).map((e) => Row(children: [
                Icon(e.value == true ? Icons.check_circle_outline : Icons.cancel_outlined,
                  size: 16, color: e.value == true ? AppColors.positive : AppColors.negative),
                const SizedBox(width: 6),
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
              ]))),
              const SizedBox(height: 12),
            ],

            const Text('Périodes mensuelles', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),

            _loading
                ? const Center(child: CircularProgressIndicator())
                : Expanded(
                    child: ListView.separated(
                      controller: ctrl,
                      itemCount: _periods.length,
                      separatorBuilder: (_, i) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final p = _periods[i] as Map<String, dynamic>;
                        final periodId = p['id'] as String;
                        final locked = p['isLocked'] as bool? ?? false;
                        final label = p['name'] as String? ?? p['month']?.toString() ?? '—';
                        return ListTile(
                          dense: true,
                          leading: Icon(locked ? Icons.lock_outline : Icons.lock_open_outlined,
                            size: 18, color: locked ? AppColors.warning : AppColors.positive),
                          title: Text(label, style: const TextStyle(fontSize: 13)),
                          trailing: TextButton(
                            onPressed: () async {
                              if (locked) {
                                await ref.read(apiClientProvider).unlockPeriod(periodId);
                              } else {
                                await ref.read(apiClientProvider).lockPeriod(periodId);
                              }
                              await _loadPeriods();
                            },
                            child: Text(locked ? 'Déverrouiller' : 'Verrouiller', style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _CreateFYDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateFYDialog({required this.onCreated});

  @override
  ConsumerState<_CreateFYDialog> createState() => _CreateFYDialogState();
}

class _CreateFYDialogState extends ConsumerState<_CreateFYDialog> {
  final _nameCtrl = TextEditingController();
  DateTime _start = DateTime(DateTime.now().year, 1, 1);
  DateTime _end = DateTime(DateTime.now().year, 12, 31);
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createFiscalYear({
        'name': _nameCtrl.text.trim(),
        'startDate': _start.toIso8601String().substring(0, 10),
        'endDate': _end.toIso8601String().substring(0, 10),
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
      title: const Text('Nouvel exercice fiscal', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom *', hintText: 'Ex: Exercice 2026')),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _start, firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (d != null) setState(() => _start = d);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Date de début'), child: Text(Fmt.date(_start))),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final d = await showDatePicker(context: context, initialDate: _end, firstDate: DateTime(2020), lastDate: DateTime(2030));
              if (d != null) setState(() => _end = d);
            },
            child: InputDecorator(decoration: const InputDecoration(labelText: 'Date de fin'), child: Text(Fmt.date(_end))),
          ),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer'),
        ),
      ],
    );
  }
}

class _EmptyFY extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFY({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.calendar_month_outlined, size: 64, color: Colors.grey[300]),
      const SizedBox(height: 16),
      Text('Aucun exercice fiscal', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
      const SizedBox(height: 8),
      ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Créer le premier exercice')),
    ]));
  }
}
