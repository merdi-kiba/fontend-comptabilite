import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _assetsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getFixedAssets();
});

class FixedAssetsScreen extends ConsumerWidget {
  const FixedAssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(_assetsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Immobilisations'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _depreciateAll(context, ref),
            icon: const Icon(Icons.auto_fix_high_outlined, size: 16),
            label: const Text('Amortir ce mois'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle immobilisation'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_assetsProvider.future),
        child: assetsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (assets) => assets.isEmpty
              ? _Empty(onAdd: () => _showCreate(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: assets.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AssetCard(
                    asset: assets[i] as Map<String, dynamic>,
                    onDepreciate: () async {
                      final now = DateTime.now();
                      await ref.read(apiClientProvider).depreciateAsset(assets[i]['id'] as String, now.year, now.month);
                      ref.invalidate(_assetsProvider);
                    },
                    onDispose: () => _showDispose(context, ref, assets[i] as Map<String, dynamic>),
                    onWriteOff: () async {
                      await ref.read(apiClientProvider).writeOffAsset(assets[i]['id'] as String);
                      ref.invalidate(_assetsProvider);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _depreciateAll(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    try {
      await ref.read(apiClientProvider).depreciateAll(now.year, now.month);
      ref.invalidate(_assetsProvider);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amortissements du mois postés')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    }
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _CreateAssetDialog(onCreated: () => ref.invalidate(_assetsProvider)));
  }

  void _showDispose(BuildContext context, WidgetRef ref, Map<String, dynamic> asset) {
    showDialog(context: context, builder: (_) => _DisposeDialog(asset: asset, onDone: () => ref.invalidate(_assetsProvider)));
  }
}

class _AssetCard extends StatelessWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onDepreciate;
  final VoidCallback onDispose;
  final VoidCallback onWriteOff;
  const _AssetCard({required this.asset, required this.onDepreciate, required this.onDispose, required this.onWriteOff});

  @override
  Widget build(BuildContext context) {
    final name = asset['name'] as String? ?? '—';
    final code = asset['code'] as String? ?? '—';
    final cost = (asset['acquisitionCost'] as num?)?.toDouble() ?? 0;
    final nbv = (asset['netBookValue'] as num?)?.toDouble() ?? cost;
    final method = asset['depreciationMethod'] as String? ?? 'LINEAR';
    final status = asset['status'] as String? ?? 'ACTIVE';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.factory_outlined, color: AppColors.primary, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            Text('$code · $method', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Row(children: [
              Text('Coût: ${Fmt.compact(cost)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              const SizedBox(width: 8),
              Text('VNC: ${Fmt.compact(nbv)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ]),
          ])),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18),
            onSelected: (a) {
              if (a == 'depreciate') { onDepreciate(); }
              else if (a == 'dispose') { onDispose(); }
              else if (a == 'writeoff') { onWriteOff(); }
            },
            itemBuilder: (_) => [
              if (status == 'ACTIVE') ...[
                const PopupMenuItem(value: 'depreciate', child: Text('Amortir ce mois')),
                const PopupMenuItem(value: 'dispose', child: Text('Céder')),
                const PopupMenuItem(value: 'writeoff', child: Text('Mettre au rebut', style: TextStyle(color: AppColors.negative))),
              ],
            ],
          ),
        ]),
      ),
    );
  }
}

class _CreateAssetDialog extends ConsumerStatefulWidget {
  final VoidCallback onCreated;
  const _CreateAssetDialog({required this.onCreated});

  @override
  ConsumerState<_CreateAssetDialog> createState() => _CreateAssetDialogState();
}

class _CreateAssetDialogState extends ConsumerState<_CreateAssetDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _lifeCtrl = TextEditingController(text: '60');
  String _method = 'LINEAR';
  DateTime _date = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _codeCtrl.dispose(); _nameCtrl.dispose(); _costCtrl.dispose(); _lifeCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final cost = double.tryParse(_costCtrl.text);
    if (_nameCtrl.text.isEmpty || cost == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).createFixedAsset({
        'code': _codeCtrl.text.trim(),
        'name': _nameCtrl.text.trim(),
        'acquisitionCost': cost,
        'acquisitionDate': _date.toIso8601String().substring(0, 10),
        'usefulLifeMonths': int.tryParse(_lifeCtrl.text) ?? 60,
        'depreciationMethod': _method,
        'residualValue': 0,
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
      title: const Text('Nouvelle immobilisation', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'IMM-001')),
        const SizedBox(height: 10),
        TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Désignation *')),
        const SizedBox(height: 10),
        TextFormField(controller: _costCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Coût d\'acquisition *', suffixText: 'CDF')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _lifeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Durée (mois)'))),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Méthode'),
            items: ['LINEAR', 'DEGRESSIVE'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: (v) => setState(() => _method = v!),
          )),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(decoration: const InputDecoration(labelText: 'Date d\'acquisition'), child: Text(_date.toIso8601String().substring(0, 10))),
        ),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Créer')),
      ],
    );
  }
}

class _DisposeDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onDone;
  const _DisposeDialog({required this.asset, required this.onDone});

  @override
  ConsumerState<_DisposeDialog> createState() => _DisposeDialogState();
}

class _DisposeDialogState extends ConsumerState<_DisposeDialog> {
  final _priceCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void dispose() { _priceCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Céder: ${widget.asset['name']}'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: _priceCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prix de cession', suffixText: 'CDF')),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
          child: InputDecorator(decoration: const InputDecoration(labelText: 'Date de cession'), child: Text(_date.toIso8601String().substring(0, 10))),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : () async {
            final nav = Navigator.of(context);
            final messenger = ScaffoldMessenger.of(context);
            setState(() => _loading = true);
            try {
              await ref.read(apiClientProvider).disposeAsset(widget.asset['id'] as String, double.tryParse(_priceCtrl.text) ?? 0, _date.toIso8601String().substring(0, 10));
              widget.onDone();
              if (mounted) nav.pop();
            } catch (e) {
              if (mounted) messenger.showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
            } finally {
              if (mounted) setState(() => _loading = false);
            }
          },
          child: const Text('Céder'),
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final VoidCallback onAdd;
  const _Empty({required this.onAdd});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.factory_outlined, size: 64, color: Colors.grey[300]),
    const SizedBox(height: 16),
    Text('Aucune immobilisation', style: TextStyle(color: Colors.grey[600])),
    const SizedBox(height: 8),
    ElevatedButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: const Text('Ajouter')),
  ]));
}
