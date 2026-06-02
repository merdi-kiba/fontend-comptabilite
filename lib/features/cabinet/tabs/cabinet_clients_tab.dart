import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _clientsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCabinetClients();
});

const _allPermissions = [
  'COMPTABILITE', 'FACTURATION', 'VENTES', 'ACHATS',
  'RAPPORTS', 'PAIE', 'RH', 'ARTICLES', 'CONFIGURATION',
];

class CabinetClientsTab extends ConsumerWidget {
  const CabinetClientsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(_clientsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(_clientsProvider.future),
      child: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
        data: (clients) => clients.isEmpty
            ? _EmptyClients()
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: clients.length,
                separatorBuilder: (context, i) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _ClientCard(
                  client: clients[i] as Map<String, dynamic>,
                  onAssignAccess: () => _showAccessDialog(context, ref, clients[i] as Map<String, dynamic>),
                  onSwitch: () async {
                    final tenantId = clients[i]['id'] as String? ?? clients[i]['tenantId'] as String? ?? '';
                    final data = await ref.read(apiClientProvider).cabinetSwitchTenant(tenantId);
                    final newToken = data['accessToken'] as String?;
                    if (newToken != null) {
                      // ignore: use_build_context_synchronously
                    }
                  },
                ),
              ),
      ),
    );
  }

  void _showAccessDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> client) {
    showDialog(
      context: context,
      builder: (_) => _AssignAccessDialog(
        client: client,
        onAssigned: () => ref.invalidate(_clientsProvider),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Map<String, dynamic> client;
  final VoidCallback onAssignAccess;
  final VoidCallback onSwitch;
  const _ClientCard({required this.client, required this.onAssignAccess, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final name = client['companyName'] as String? ?? client['name'] as String? ?? '—';
    final nif = client['nif'] as String? ?? '—';
    final status = client['status'] as String? ?? '—';
    final accesses = client['accesses'] as List? ?? [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.business_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      Text('NIF: $nif', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),

            if (accesses.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Text('Accès membres (${accesses.length})', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: accesses.take(4).map((a) {
                  final u = a as Map<String, dynamic>;
                  return Chip(
                    label: Text(u['username'] as String? ?? '?', style: const TextStyle(fontSize: 11)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: onAssignAccess,
                  icon: const Icon(Icons.key_outlined, size: 16),
                  label: const Text('Assigner accès', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onSwitch,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Ouvrir', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'ACTIVE' ? AppColors.positive : status == 'SUSPENDED' ? AppColors.negative : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _AssignAccessDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> client;
  final VoidCallback onAssigned;
  const _AssignAccessDialog({required this.client, required this.onAssigned});

  @override
  ConsumerState<_AssignAccessDialog> createState() => _AssignAccessDialogState();
}

class _AssignAccessDialogState extends ConsumerState<_AssignAccessDialog> {
  final _userIdCtrl = TextEditingController();
  final Set<String> _selectedPerms = {'COMPTABILITE', 'FACTURATION', 'RAPPORTS'};
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _userIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tenantId = widget.client['id'] as String? ?? widget.client['tenantId'] as String? ?? '';
    final userId = _userIdCtrl.text.trim();
    if (userId.isEmpty || _selectedPerms.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).assignClientAccess(tenantId, userId, _selectedPerms.toList());
      widget.onAssigned();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.client['companyName'] as String? ?? '—';
    return AlertDialog(
      title: Text('Assigner accès — $name', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(controller: _userIdCtrl, decoration: const InputDecoration(labelText: 'UUID du membre', hintText: 'xxxxxxxx-xxxx-...')),
            const SizedBox(height: 16),
            const Text('Permissions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _allPermissions.map((p) {
                final selected = _selectedPerms.contains(p);
                return FilterChip(
                  label: Text(p, style: TextStyle(fontSize: 11, color: selected ? AppColors.primary : Colors.grey[700])),
                  selected: selected,
                  onSelected: (v) => setState(() => v ? _selectedPerms.add(p) : _selectedPerms.remove(p)),
                  selectedColor: AppColors.primary.withValues(alpha: 0.1),
                  checkmarkColor: AppColors.primary,
                  side: BorderSide(color: selected ? AppColors.primary.withValues(alpha: 0.4) : const Color(0xFFE0E0E0)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Assigner'),
        ),
      ],
    );
  }
}

class _EmptyClients extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucun client assigné', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Les clients s\'ajoutent via la gestion des tenants', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
        ],
      ),
    );
  }
}
