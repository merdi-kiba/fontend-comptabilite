import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _accountsProvider = FutureProvider.autoDispose.family<List<dynamic>, String?>((ref, cls) async {
  return ref.watch(apiClientProvider).getAccounts(accountClass: cls);
});

const _classes = ['1','2','3','4','5','6','7','8','9'];
const _classLabels = {
  '1': 'Capitaux', '2': 'Immob.', '3': 'Stocks', '4': 'Tiers',
  '5': 'Tréso.', '6': 'Charges', '7': 'Produits', '8': 'HAO', '9': 'Anal.',
};

class ChartOfAccountsTab extends ConsumerStatefulWidget {
  const ChartOfAccountsTab({super.key});

  @override
  ConsumerState<ChartOfAccountsTab> createState() => _ChartOfAccountsTabState();
}

class _ChartOfAccountsTabState extends ConsumerState<ChartOfAccountsTab> {
  String? _classFilter;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(_accountsProvider(_classFilter));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAccount(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau compte'),
        backgroundColor: AppColors.primary,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par code ou libellé...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Tous', style: TextStyle(fontSize: 12)),
                          selected: _classFilter == null,
                          onSelected: (_) => setState(() => _classFilter = null),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                      ..._classes.map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('$c – ${_classLabels[c]}', style: const TextStyle(fontSize: 11)),
                          selected: _classFilter == c,
                          onSelected: (_) => setState(() => _classFilter = c),
                          selectedColor: AppColors.primary.withValues(alpha: 0.15),
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: accountsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
              data: (accounts) {
                final filtered = _search.isEmpty ? accounts : accounts.where((a) {
                  final m = a as Map<String, dynamic>;
                  return (m['code'] as String? ?? '').toLowerCase().contains(_search) ||
                         (m['name'] as String? ?? '').toLowerCase().contains(_search);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final acc = filtered[i] as Map<String, dynamic>;
                    final code = acc['code'] as String? ?? '—';
                    final name = acc['name'] as String? ?? '—';
                    final type = acc['type'] as String? ?? '';
                    final cls = code.isNotEmpty ? code[0] : '?';
                    return ListTile(
                      dense: true,
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: _classColor(cls).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(cls, style: TextStyle(fontWeight: FontWeight.w800, color: _classColor(cls)))),
                      ),
                      title: Text('$code – $name', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(type, style: const TextStyle(fontSize: 11)),
                      trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _classColor(String cls) => switch (cls) {
    '1' => AppColors.primary,
    '2' => const Color(0xFF7C3AED),
    '3' => Colors.teal,
    '4' => AppColors.warning,
    '5' => AppColors.positive,
    '6' => AppColors.negative,
    '7' => const Color(0xFF0EA5E9),
    _ => Colors.grey,
  };

  void _showAddAccount(BuildContext context) {
    showDialog(context: context, builder: (_) => _AddAccountDialog(
      onAdded: () => ref.invalidate(_accountsProvider(_classFilter)),
    ));
  }
}

class _AddAccountDialog extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddAccountDialog({required this.onAdded});

  @override
  ConsumerState<_AddAccountDialog> createState() => _AddAccountDialogState();
}

class _AddAccountDialogState extends ConsumerState<_AddAccountDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  String _type = 'ACTIF';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); _nameCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_codeCtrl.text.isEmpty || _nameCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createAccount({
        'code': _codeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'class': int.tryParse(_codeCtrl.text.isNotEmpty ? _codeCtrl.text[0] : '1') ?? 1,
        'type': _type,
      });
      widget.onAdded();
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
      title: const Text('Nouveau compte', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 380,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code compte *', hintText: 'Ex: 4119')),
          const SizedBox(height: 12),
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Libellé *')),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: ['ACTIF','PASSIF','CHARGE','PRODUIT'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _type = v!),
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
