import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _membersProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getCabinetMembers();
});

const _cabinetRoles = ['CABINET_OWNER', 'CABINET_MANAGER', 'CABINET_COMPTABLE', 'CABINET_AUDITEUR'];

class CabinetMembersTab extends ConsumerWidget {
  const CabinetMembersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_membersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showInviteDialog(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Inviter un membre'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_membersProvider.future),
        child: membersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (members) => members.isEmpty
              ? _EmptyMembers(onInvite: () => _showInviteDialog(context, ref))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: members.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _MemberCard(
                    member: members[i] as Map<String, dynamic>,
                    onChangeRole: (userId, role) async {
                      await ref.read(apiClientProvider).updateMemberRole(userId, role);
                      ref.invalidate(_membersProvider);
                    },
                    onRemove: (userId) async {
                      final confirm = await _confirmDialog(context, 'Retirer ce membre du cabinet ?');
                      if (confirm) {
                        await ref.read(apiClientProvider).removeMember(userId);
                        ref.invalidate(_membersProvider);
                      }
                    },
                  ),
                ),
        ),
      ),
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _InviteDialog(
      onInvited: () => ref.invalidate(_membersProvider),
    ));
  }

  Future<bool> _confirmDialog(BuildContext context, String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.negative),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ?? false;
  }
}

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> member;
  final Future<void> Function(String userId, String role) onChangeRole;
  final Future<void> Function(String userId) onRemove;
  const _MemberCard({required this.member, required this.onChangeRole, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final userId = member['userId'] as String? ?? member['id'] as String? ?? '';
    final username = member['username'] as String? ?? '—';
    final email = member['email'] as String? ?? '';
    final role = member['role'] as String? ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(username.substring(0, 1).toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            _RoleChip(role: role),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (action) async {
                if (action == 'remove') {
                  await onRemove(userId);
                } else {
                  await onChangeRole(userId, action);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'CABINET_OWNER', child: Text('CABINET_OWNER')),
                const PopupMenuItem(value: 'CABINET_MANAGER', child: Text('CABINET_MANAGER')),
                const PopupMenuItem(value: 'CABINET_COMPTABLE', child: Text('CABINET_COMPTABLE')),
                const PopupMenuItem(value: 'CABINET_AUDITEUR', child: Text('CABINET_AUDITEUR')),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'remove',
                  child: const Text('Retirer', style: TextStyle(color: AppColors.negative)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String role;
  const _RoleChip({required this.role});

  Color get _color {
    switch (role) {
      case 'CABINET_OWNER': return AppColors.primary;
      case 'CABINET_MANAGER': return AppColors.warning;
      case 'CABINET_COMPTABLE': return AppColors.positive;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(role.replaceAll('CABINET_', ''), style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w600)),
    );
  }
}

class _InviteDialog extends ConsumerStatefulWidget {
  final VoidCallback onInvited;
  const _InviteDialog({required this.onInvited});

  @override
  ConsumerState<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends ConsumerState<_InviteDialog> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _role = 'CABINET_COMPTABLE';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_usernameCtrl.text.isEmpty || _passCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(apiClientProvider).inviteMember({
        'username': _usernameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passCtrl.text,
        'role': _role,
      });
      widget.onInvited();
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
      title: const Text('Inviter un membre', style: TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(controller: _usernameCtrl, decoration: const InputDecoration(labelText: 'Nom d\'utilisateur')),
            const SizedBox(height: 12),
            TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optionnel)')),
            const SizedBox(height: 12),
            TextFormField(controller: _passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe temporaire')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: _cabinetRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _role = v!),
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
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Inviter'),
        ),
      ],
    );
  }
}

class _EmptyMembers extends StatelessWidget {
  final VoidCallback onInvite;
  const _EmptyMembers({required this.onInvite});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_add_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucun membre', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 8),
          ElevatedButton.icon(onPressed: onInvite, icon: const Icon(Icons.person_add_outlined), label: const Text('Inviter le premier membre')),
        ],
      ),
    );
  }
}
