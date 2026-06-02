import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _bankAccountsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getBankAccounts();
});

final _selectedBankProvider = StateProvider.autoDispose<String?>((ref) => null);

final _suggestionsProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, bankId) async {
  return ref.watch(apiClientProvider).getReconciliationSuggestions(bankId);
});

final _bankLinesProvider = FutureProvider.autoDispose.family<List<dynamic>, String>((ref, bankId) async {
  return ref.watch(apiClientProvider).getReconciliationBankLines(bankId);
});

final _reconcReportProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, bankId) async {
  return ref.watch(apiClientProvider).getReconciliationReport(bankId);
});

// ── Main tab ─────────────────────────────────────────────────────────────────

class ReconciliationTab extends ConsumerWidget {
  const ReconciliationTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final banksAsync = ref.watch(_bankAccountsProvider);
    final selectedId = ref.watch(_selectedBankProvider);

    return banksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (banks) {
        if (banks.isEmpty) {
          return const Center(child: Text('Aucun compte bancaire. Créez-en un dans l\'onglet Banques.'));
        }
        final effectiveId = selectedId ?? (banks.first as Map)['id'] as String;
        return Column(children: [
          _BankSelector(banks: banks, selectedId: effectiveId),
          Expanded(child: _ReconciliationBody(bankId: effectiveId)),
        ]);
      },
    );
  }
}

// ── Bank selector ─────────────────────────────────────────────────────────────

class _BankSelector extends ConsumerWidget {
  final List<dynamic> banks;
  final String selectedId;
  const _BankSelector({required this.banks, required this.selectedId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        const Text('Compte : ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        Expanded(
          child: DropdownButton<String>(
            value: selectedId,
            isExpanded: true,
            underline: const SizedBox(),
            items: banks.map((b) {
              final m = b as Map<String, dynamic>;
              return DropdownMenuItem<String>(
                value: m['id'] as String,
                child: Text('${m['bankName'] ?? m['name']} — ${m['accountNumber'] ?? ''}',
                  style: const TextStyle(fontSize: 13)),
              );
            }).toList(),
            onChanged: (v) => ref.read(_selectedBankProvider.notifier).state = v,
          ),
        ),
      ]),
    );
  }
}

// ── Body with inner tabs ──────────────────────────────────────────────────────

class _ReconciliationBody extends ConsumerStatefulWidget {
  final String bankId;
  const _ReconciliationBody({required this.bankId});

  @override
  ConsumerState<_ReconciliationBody> createState() => _ReconciliationBodyState();
}

class _ReconciliationBodyState extends ConsumerState<_ReconciliationBody>
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
    return Column(children: [
      Container(
        color: Colors.white,
        child: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Suggestions'),
            Tab(text: 'Lignes non rapprochées'),
            Tab(text: 'Rapport'),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [
            _SuggestionsView(bankId: widget.bankId),
            _BankLinesView(bankId: widget.bankId),
            _ReportView(bankId: widget.bankId),
          ],
        ),
      ),
    ]);
  }
}

// ── Suggestions view ──────────────────────────────────────────────────────────

class _SuggestionsView extends ConsumerWidget {
  final String bankId;
  const _SuggestionsView({required this.bankId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggsAsync = ref.watch(_suggestionsProvider(bankId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'import',
            onPressed: () => _showImportDialog(context, ref),
            icon: const Icon(Icons.upload_file_outlined),
            label: const Text('Importer relevé'),
            backgroundColor: AppColors.neutral,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'auto',
            onPressed: () => _autoReconcile(context, ref),
            icon: const Icon(Icons.auto_awesome_outlined),
            label: const Text('Auto (score ≥ 85)'),
            backgroundColor: AppColors.primary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_suggestionsProvider(bankId).future),
        child: suggsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (suggs) => suggs.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_outline, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucune suggestion', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 4),
                  Text('Importez un relevé ou les comptes sont déjà rapprochés', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                  itemCount: suggs.length,
                  separatorBuilder: (_, _i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _SuggestionCard(
                    suggestion: suggs[i] as Map<String, dynamic>,
                    onMatch: () async {
                      await _confirmMatch(context, ref, suggs[i] as Map<String, dynamic>);
                      ref.invalidate(_suggestionsProvider(bankId));
                      ref.invalidate(_bankLinesProvider(bankId));
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _autoReconcile(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
    final to = now.toIso8601String().substring(0, 10);
    try {
      final result = await ref.read(apiClientProvider).autoReconcile(
        bankId, from: from, to: to, minScore: 85,
      );
      if (context.mounted) {
        final matched = result['matched'] ?? 0;
        final skipped = result['skipped'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✓ $matched rapprochés, $skipped ignorés (score < 85)'),
            backgroundColor: AppColors.positive),
        );
      }
      ref.invalidate(_suggestionsProvider(bankId));
      ref.invalidate(_bankLinesProvider(bankId));
      ref.invalidate(_reconcReportProvider(bankId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative),
        );
      }
    }
  }

  Future<void> _confirmMatch(BuildContext context, WidgetRef ref, Map<String, dynamic> sugg) async {
    final grouped = sugg['grouped'] as bool? ?? false;
    final bankLineId = sugg['bankLineId'] as String;

    try {
      if (grouped) {
        final ids = (sugg['journalEntryLineIds'] as List).cast<String>();
        for (final jId in ids) {
          await ref.read(apiClientProvider).matchReconciliation(bankLineId, jId);
        }
      } else {
        final jId = sugg['journalEntryLineId'] as String? ?? sugg['journalEntryLineIds']?[0] as String?;
        if (jId != null) await ref.read(apiClientProvider).matchReconciliation(bankLineId, jId);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rapprochement confirmé'),
          backgroundColor: AppColors.positive));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)),
          backgroundColor: AppColors.negative));
      }
    }
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _ImportDialog(
      bankId: bankId,
      onImported: () {
        ref.invalidate(_suggestionsProvider(bankId));
        ref.invalidate(_bankLinesProvider(bankId));
      },
    ));
  }
}

// ── Suggestion card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onMatch;
  const _SuggestionCard({required this.suggestion, required this.onMatch});

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.positive;
    if (score >= 60) return AppColors.warning;
    return AppColors.negative;
  }

  @override
  Widget build(BuildContext context) {
    final score = (suggestion['score'] as num?)?.toInt() ?? 0;
    final grouped = suggestion['grouped'] as bool? ?? false;
    final amount = (suggestion['amount'] as num?)?.toDouble()
        ?? (suggestion['amounts'] is List ? (suggestion['amounts'] as List).fold<double>(0.0, (s, a) => s + (a as num).toDouble()) : 0.0);
    final desc = suggestion['description'] as String? ?? suggestion['bankDescription'] as String? ?? '—';
    final date = (suggestion['date'] as String? ?? '').substring(0, 10.clamp(0, (suggestion['date'] as String? ?? '').length));
    final color = _scoreColor(score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // Score badge
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$score', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: color)),
              Text('pts', style: TextStyle(fontSize: 9, color: color)),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                overflow: TextOverflow.ellipsis)),
              if (grouped)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('2-en-1', style: TextStyle(fontSize: 9, color: AppColors.warning, fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 2),
            Text('$date · ${Fmt.currency(amount)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ])),
          IconButton(
            icon: const Icon(Icons.check_circle_outline, color: AppColors.positive),
            tooltip: 'Confirmer le rapprochement',
            onPressed: onMatch,
          ),
        ]),
      ),
    );
  }
}

// ── Bank lines view (unmatched) ───────────────────────────────────────────────

class _BankLinesView extends ConsumerWidget {
  final String bankId;
  const _BankLinesView({required this.bankId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linesAsync = ref.watch(_bankLinesProvider(bankId));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_bankLinesProvider(bankId).future),
      child: linesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (lines) => lines.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.done_all_outlined, size: 56, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text('Toutes les lignes sont rapprochées', style: TextStyle(color: Colors.grey[500])),
              ]))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final l = lines[i] as Map<String, dynamic>;
                  final amount = (l['amount'] as num?)?.toDouble() ?? 0;
                  final direction = l['direction'] as String? ?? 'CREDIT';
                  final isCredit = direction == 'CREDIT';
                  final date = (l['date'] as String? ?? '').substring(0, 10.clamp(0, (l['date'] as String? ?? '').length));
                  return Card(
                    child: ListTile(
                      dense: true,
                      leading: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: isCredit ? AppColors.positive : AppColors.negative, size: 18),
                      title: Text(l['description'] as String? ?? '—', style: const TextStyle(fontSize: 13)),
                      subtitle: Text(date, style: const TextStyle(fontSize: 11)),
                      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('${isCredit ? '+' : '-'}${Fmt.compact(amount)}',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13,
                            color: isCredit ? AppColors.positive : AppColors.negative)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: const Text('NON RAPPROCHÉ', style: TextStyle(fontSize: 8, color: AppColors.warning, fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ── Report view ───────────────────────────────────────────────────────────────

class _ReportView extends ConsumerWidget {
  final String bankId;
  const _ReportView({required this.bankId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(_reconcReportProvider(bankId));

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_reconcReportProvider(bankId).future),
      child: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (r) {
          final bankBalance = (r['bankBalance'] as num?)?.toDouble() ?? 0.0;
          final bookBalance = (r['bookBalance'] as num?)?.toDouble() ?? 0.0;
          final diff = (r['difference'] as num?)?.toDouble() ?? (bankBalance - bookBalance);
          final matched = r['matchedLines'] as int? ?? 0;
          final unmatchedBank = r['unmatchedBankLines'] as int? ?? 0;
          final unmatchedBook = r['unmatchedBookLines'] as int? ?? 0;
          final isReconciled = diff.abs() < 0.01;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              // Status banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isReconciled ? AppColors.positive : AppColors.warning).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isReconciled ? AppColors.positive : AppColors.warning),
                ),
                child: Row(children: [
                  Icon(isReconciled ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                    color: isReconciled ? AppColors.positive : AppColors.warning),
                  const SizedBox(width: 10),
                  Text(isReconciled ? 'Compte rapproché' : 'Écart de rapprochement',
                    style: TextStyle(fontWeight: FontWeight.w700,
                      color: isReconciled ? AppColors.positive : AppColors.warning)),
                ]),
              ),
              const SizedBox(height: 16),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _row('Solde relevé bancaire', bankBalance),
                  _row('Solde comptable (521)', bookBalance),
                  const Divider(),
                  _row('Écart', diff, bold: true, color: isReconciled ? AppColors.positive : AppColors.negative),
                ]),
              )),
              const SizedBox(height: 12),
              Card(child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _countRow('Lignes rapprochées', matched, AppColors.positive),
                  _countRow('Lignes bancaires non rapprochées', unmatchedBank, AppColors.warning),
                  _countRow('Lignes comptables non rapprochées', unmatchedBook, AppColors.warning),
                ]),
              )),
            ]),
          );
        },
      ),
    );
  }

  Widget _row(String label, num value, {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: 13))),
      Text(Fmt.currency(value),
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: bold ? 16 : 13,
          color: color ?? (value >= 0 ? null : AppColors.negative))),
    ]),
  );

  Widget _countRow(String label, int count, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
      ),
    ]),
  );
}

// ── Import dialog ─────────────────────────────────────────────────────────────

class _ImportDialog extends ConsumerStatefulWidget {
  final String bankId;
  final VoidCallback onImported;
  const _ImportDialog({required this.bankId, required this.onImported});

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> _pickAndImport() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      // Pour desktop Flutter, on utilise un sélecteur de fichier simplifié.
      // En production, intégrer file_picker package.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélection fichier : intégrez le package file_picker')),
      );
      setState(() => _loading = false);
    } catch (e) {
      setState(() { _error = parseError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Importer un relevé bancaire', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFDDE1E7)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Format CSV attendu :', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 6),
            Text('DATE,DESCRIPTION,DEBIT,CREDIT,REFERENCE\n2026-05-01,"Virement",0,150000,VIR-001',
              style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey[700])),
          ]),
        ),
        const SizedBox(height: 16),
        if (_result != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 18),
              const SizedBox(width: 8),
              Text('${_result!['imported'] ?? 0} lignes importées', style: const TextStyle(color: AppColors.positive, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 8),
        ],
        if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _loading ? null : _pickAndImport,
            icon: _loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.upload_file_outlined),
            label: Text(_loading ? 'Import en cours…' : 'Sélectionner un fichier CSV/OFX'),
          ),
        ),
      ])),
      actions: [
        TextButton(onPressed: () { widget.onImported(); Navigator.pop(context); }, child: const Text('Fermer')),
      ],
    );
  }
}
