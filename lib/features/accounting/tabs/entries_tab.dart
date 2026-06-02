import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

// Key format: "journalCode|status" — String has content-based == so Riverpod
// won't recreate the provider on every widget rebuild (unlike Map which is identity-equal).
final _entriesProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, key) async {
  final parts = key.split('|');
  final journalCode = parts[0].isEmpty ? null : parts[0];
  final status = parts[1].isEmpty ? null : parts[1];
  return ref.watch(apiClientProvider).getEntries(
    journalCode: journalCode,
    status: status,
  );
});

final _journalsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getJournals();
});

class EntriesTab extends ConsumerStatefulWidget {
  const EntriesTab({super.key});

  @override
  ConsumerState<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends ConsumerState<EntriesTab> {
  String? _journalFilter;
  String? _statusFilter;

  String get _filterKey => '${_journalFilter ?? ''}|${_statusFilter ?? ''}';

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(_entriesProvider(_filterKey));
    final journalsAsync = ref.watch(_journalsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateEntry(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle écriture'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          // Filtres
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                // Filtre journal
                journalsAsync.when(
                  loading: () => const SizedBox(width: 120),
                  error: (e, _) => const SizedBox(),
                  data: (journals) => DropdownButton<String?>(
                    value: _journalFilter,
                    hint: const Text('Tous les journaux', style: TextStyle(fontSize: 13)),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Tous')),
                      ...journals.map((j) => DropdownMenuItem(
                        value: j['code'] as String?,
                        child: Text('${j['code']} - ${j['name']}', style: const TextStyle(fontSize: 13)),
                      )),
                    ],
                    onChanged: (v) => setState(() => _journalFilter = v),
                  ),
                ),
                const SizedBox(width: 12),
                // Filtre statut
                DropdownButton<String?>(
                  value: _statusFilter,
                  hint: const Text('Tous statuts', style: TextStyle(fontSize: 13)),
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tous')),
                    DropdownMenuItem(value: 'DRAFT', child: Text('Brouillon')),
                    DropdownMenuItem(value: 'POSTED', child: Text('Validée')),
                  ],
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(_entriesProvider(_filterKey).future),
              child: entriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
                data: (data) {
                  final entries = (data['data'] as List?) ?? (data is List ? data as List : []);
                  if (entries.isEmpty) {
                    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_long_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Aucune écriture', style: TextStyle(color: Colors.grey[600])),
                    ]));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: entries.length,
                    separatorBuilder: (_, i) => const SizedBox(height: 6),
                    itemBuilder: (_, i) => _EntryCard(
                      entry: entries[i] as Map<String, dynamic>,
                      onPost: () async {
                        await ref.read(apiClientProvider).postEntry(entries[i]['id'] as String);
                        ref.invalidate(_entriesProvider(_filterKey));
                      },
                      onDelete: () async {
                        await ref.read(apiClientProvider).deleteEntry(entries[i]['id'] as String);
                        ref.invalidate(_entriesProvider(_filterKey));
                      },
                      onReverse: () => _showReverseDialog(context, entries[i] as Map<String, dynamic>),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateEntry(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateEntryDialog(onCreated: () => ref.invalidate(_entriesProvider(_filterKey))),
    );
  }

  void _showReverseDialog(BuildContext context, Map<String, dynamic> entry) {
    showDialog(context: context, builder: (_) => _ReverseDialog(
      entry: entry,
      onReversed: () => ref.invalidate(_entriesProvider(_filterKey)),
    ));
  }
}

class _EntryCard extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onPost;
  final VoidCallback onDelete;
  final VoidCallback onReverse;
  const _EntryCard({required this.entry, required this.onPost, required this.onDelete, required this.onReverse});

  @override
  Widget build(BuildContext context) {
    final status = entry['status'] as String? ?? 'DRAFT';
    final journal = entry['journalCode'] as String? ?? '—';
    final number = entry['number'] as String? ?? entry['id'] as String? ?? '—';
    final desc = entry['description'] as String? ?? '—';
    final date = entry['date'] as String? ?? entry['createdAt'] as String? ?? '';
    final lines = entry['lines'] as List? ?? [];
    final totalDebit = lines.fold<double>(0, (s, l) => s + ((l as Map)['debit'] as num? ?? 0).toDouble());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _JournalBadge(journal),
            const SizedBox(width: 8),
            Expanded(child: Text(number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
            _StatusBadge(status),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (a) {
                if (a == 'post') { onPost(); }
                else if (a == 'delete') { onDelete(); }
                else if (a == 'reverse') { onReverse(); }
              },
              itemBuilder: (_) => [
                if (status == 'DRAFT') ...[
                  const PopupMenuItem(value: 'post', child: Text('Valider (SoD)')),
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer', style: TextStyle(color: AppColors.negative))),
                ],
                if (status == 'POSTED')
                  const PopupMenuItem(value: 'reverse', child: Text('Extourner')),
              ],
            ),
          ]),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(date.length >= 10 ? date.substring(0, 10) : date, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const Spacer(),
            Text('${lines.length} ligne(s) · ${Fmt.compact(totalDebit)} CDF', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
    );
  }
}

class _JournalBadge extends StatelessWidget {
  final String code;
  const _JournalBadge(this.code);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(code, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700)),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final color = status == 'POSTED' ? AppColors.positive : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status == 'POSTED' ? 'Validée' : 'Brouillon', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _CreateEntryDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateEntryDialog({required this.onCreated});

  @override
  ConsumerState<_CreateEntryDialog> createState() => _CreateEntryDialogState();
}

class _CreateEntryDialogState extends ConsumerState<_CreateEntryDialog> {
  final _descCtrl = TextEditingController();
  String _journal = 'OD';
  DateTime _date = DateTime.now();
  final List<Map<String, dynamic>> _lines = [
    {'accountCode': '', 'debit': 0.0, 'credit': 0.0},
    {'accountCode': '', 'debit': 0.0, 'credit': 0.0},
  ];
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _descCtrl.dispose(); super.dispose(); }

  double get _totalDebit => _lines.fold(0, (s, l) => s + (l['debit'] as double));
  double get _totalCredit => _lines.fold(0, (s, l) => s + (l['credit'] as double));
  bool get _isBalanced => (_totalDebit - _totalCredit).abs() < 0.01;

  Future<void> _submit() async {
    if (_descCtrl.text.isEmpty || !_isBalanced) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createEntry({
        'journalCode': _journal,
        'date': _date.toIso8601String().substring(0, 10),
        'description': _descCtrl.text.trim(),
        'lines': _lines.where((l) => (l['accountCode'] as String).isNotEmpty).map((l) => {
          'accountCode': l['accountCode'],
          'debit': l['debit'],
          'credit': l['credit'],
        }).toList(),
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
      title: const Text('Nouvelle écriture', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: DropdownButtonFormField<String>(
                initialValue: _journal,
                decoration: const InputDecoration(labelText: 'Journal', isDense: true),
                items: ['AC','VE','BQ','CA','JV','OD','PAIE'].map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
                onChanged: (v) => setState(() => _journal = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: InkWell(
                onTap: () async {
                  final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date', isDense: true),
                  child: Text(_date.toIso8601String().substring(0, 10)),
                ),
              )),
            ]),
            const SizedBox(height: 12),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Libellé', isDense: true)),
            const SizedBox(height: 16),
            // Lignes
            Table(
              columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2)},
              children: [
                const TableRow(children: [
                  Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Compte', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Débit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Padding(padding: EdgeInsets.only(bottom: 4), child: Text('Crédit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ]),
                ..._lines.asMap().entries.map((e) => TableRow(children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, right: 4),
                    child: TextFormField(
                      initialValue: e.value['accountCode'] as String,
                      decoration: const InputDecoration(isDense: true, hintText: 'Ex: 601'),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _lines[e.key]['accountCode'] = v),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, right: 4),
                    child: TextFormField(
                      initialValue: e.value['debit'] == 0.0 ? '' : e.value['debit'].toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, hintText: '0'),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _lines[e.key]['debit'] = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: TextFormField(
                      initialValue: e.value['credit'] == 0.0 ? '' : e.value['credit'].toString(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, hintText: '0'),
                      style: const TextStyle(fontSize: 13),
                      onChanged: (v) => setState(() => _lines[e.key]['credit'] = double.tryParse(v) ?? 0.0),
                    ),
                  ),
                ])),
              ],
            ),
            // Totaux
            Row(children: [
              TextButton.icon(
                onPressed: () => setState(() => _lines.add({'accountCode': '', 'debit': 0.0, 'credit': 0.0})),
                icon: const Icon(Icons.add, size: 14), label: const Text('Ligne', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              Text('Débit: ${Fmt.compact(_totalDebit)}  Crédit: ${Fmt.compact(_totalCredit)}',
                style: TextStyle(fontSize: 12, color: _isBalanced ? AppColors.positive : AppColors.negative, fontWeight: FontWeight.w600)),
            ]),
            if (!_isBalanced) Text('Écriture déséquilibrée', style: const TextStyle(color: AppColors.negative, fontSize: 11)),
            if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: (_loading || !_isBalanced) ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer'),
        ),
      ],
    );
  }
}

class _ReverseDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onReversed;
  const _ReverseDialog({required this.entry, required this.onReversed});

  @override
  ConsumerState<_ReverseDialog> createState() => _ReverseDialogState();
}

class _ReverseDialogState extends ConsumerState<_ReverseDialog> {
  DateTime _date = DateTime.now();
  bool _loading = false;

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await ref.read(apiClientProvider).reverseEntry(widget.entry['id'] as String, _date.toIso8601String().substring(0, 10));
      widget.onReversed();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Extourner l\'écriture'),
      content: InkWell(
        onTap: () async {
          final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
          if (d != null) setState(() => _date = d);
        },
        child: InputDecorator(
          decoration: const InputDecoration(labelText: 'Date d\'extourne'),
          child: Text(_date.toIso8601String().substring(0, 10)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Extourner'),
        ),
      ],
    );
  }
}
