import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _empProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmployees();
});

class EmployeesTab extends ConsumerWidget {
  const EmployeesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emps = ref.watch(_empProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context, ref),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Nouvel employé'),
        backgroundColor: AppColors.primary,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(_empProvider.future),
        child: emps.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
          data: (list) => list.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.people_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('Aucun employé', style: TextStyle(color: Colors.grey[500])),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(onPressed: () => _showCreate(context, ref), icon: const Icon(Icons.add), label: const Text('Ajouter un employé')),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: list.length,
                  separatorBuilder: (_, i) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _EmployeeCard(
                    emp: list[i] as Map<String, dynamic>,
                    onEdit: () => _showEdit(context, ref, list[i] as Map<String, dynamic>),
                  ),
                ),
        ),
      ),
    );
  }

  void _showCreate(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (_) => _EmployeeDialog(onSaved: () => ref.invalidate(_empProvider)));
  }

  void _showEdit(BuildContext context, WidgetRef ref, Map<String, dynamic> emp) {
    showDialog(context: context, builder: (_) => _EmployeeDialog(existing: emp, onSaved: () => ref.invalidate(_empProvider)));
  }
}

// ── Employee card ─────────────────────────────────────────────────────────────

class _EmployeeCard extends StatelessWidget {
  final Map<String, dynamic> emp;
  final VoidCallback onEdit;
  const _EmployeeCard({required this.emp, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final firstName = emp['firstName'] as String? ?? '';
    final lastName = emp['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final code = emp['code'] as String? ?? '—';
    final position = emp['position'] as String? ?? '—';
    final dept = emp['department'] as String? ?? '—';
    final gross = toDouble(emp['grossSalary']);
    final isActive = (emp['status'] as String?)?.toUpperCase() != 'INACTIVE';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
              if (!isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: const Text('INACTIF', style: TextStyle(fontSize: 9, color: AppColors.negative, fontWeight: FontWeight.w700)),
                ),
            ]),
            Text('$code · $position · $dept', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(Fmt.currency(gross), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ])),
          IconButton(icon: const Icon(Icons.edit_outlined, size: 18), tooltip: 'Modifier', onPressed: onEdit),
        ]),
      ),
    );
  }
}

// ── Employee dialog (create / edit) ───────────────────────────────────────────

class _EmployeeDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? existing;
  final VoidCallback onSaved;
  const _EmployeeDialog({this.existing, required this.onSaved});

  @override
  ConsumerState<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends ConsumerState<_EmployeeDialog> {
  late final TextEditingController _codeCtrl;
  late final TextEditingController _firstCtrl;
  late final TextEditingController _lastCtrl;
  late final TextEditingController _posCtrl;
  late final TextEditingController _deptCtrl;
  late final TextEditingController _grossCtrl;
  late final TextEditingController _cnssCtrl;
  late final TextEditingController _cinCtrl;
  late final TextEditingController _bankCtrl;
  late final TextEditingController _bankNameCtrl;
  String _currency = 'CDF';
  DateTime _startDate = DateTime.now();
  bool _loading = false;
  String? _error;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing ?? {};
    _codeCtrl = TextEditingController(text: e['code'] as String? ?? '');
    _firstCtrl = TextEditingController(text: e['firstName'] as String? ?? '');
    _lastCtrl = TextEditingController(text: e['lastName'] as String? ?? '');
    _posCtrl = TextEditingController(text: e['position'] as String? ?? '');
    _deptCtrl = TextEditingController(text: e['department'] as String? ?? '');
    _grossCtrl = TextEditingController(text: '${toDouble(e['grossSalary']).toInt()}');
    _cnssCtrl = TextEditingController(text: e['cnssNumber'] as String? ?? '');
    _cinCtrl = TextEditingController(text: e['cin'] as String? ?? '');
    _bankCtrl = TextEditingController(text: e['bankAccountNum'] as String? ?? '');
    _bankNameCtrl = TextEditingController(text: e['bankName'] as String? ?? '');
    _currency = e['currency'] as String? ?? 'CDF';
    if (e['startDate'] != null) {
      try { _startDate = DateTime.parse(e['startDate'] as String); } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final c in [_codeCtrl, _firstCtrl, _lastCtrl, _posCtrl, _deptCtrl, _grossCtrl, _cnssCtrl, _cinCtrl, _bankCtrl, _bankNameCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_firstCtrl.text.isEmpty || _lastCtrl.text.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = {
        'code': _codeCtrl.text.trim(),
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'position': _posCtrl.text.trim(),
        'department': _deptCtrl.text.trim(),
        'grossSalary': double.tryParse(_grossCtrl.text) ?? 0,
        'currency': _currency,
        'startDate': _startDate.toIso8601String().substring(0, 10),
        if (_cnssCtrl.text.isNotEmpty) 'cnssNumber': _cnssCtrl.text.trim(),
        if (_cinCtrl.text.isNotEmpty) 'cin': _cinCtrl.text.trim(),
        if (_bankCtrl.text.isNotEmpty) 'bankAccountNum': _bankCtrl.text.trim(),
        if (_bankNameCtrl.text.isNotEmpty) 'bankName': _bankNameCtrl.text.trim(),
      };
      if (isEdit) {
        await ref.read(apiClientProvider).updateEmployee(widget.existing!['id'] as String, data);
      } else {
        await ref.read(apiClientProvider).createEmployee(data);
      }
      widget.onSaved();
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
      title: Text(isEdit ? 'Modifier l\'employé' : 'Nouvel employé', style: const TextStyle(fontWeight: FontWeight.w700)),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: TextFormField(controller: _firstCtrl, decoration: const InputDecoration(labelText: 'Prénom *'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _lastCtrl, decoration: const InputDecoration(labelText: 'Nom *'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _codeCtrl, decoration: const InputDecoration(labelText: 'Code', hintText: 'EMP-001'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _posCtrl, decoration: const InputDecoration(labelText: 'Poste'))),
        ]),
        const SizedBox(height: 10),
        TextFormField(controller: _deptCtrl, decoration: const InputDecoration(labelText: 'Département', hintText: 'COMPTABILITE')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _grossCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Salaire brut *'))),
          const SizedBox(width: 10),
          DropdownButton<String>(
            value: _currency,
            items: ['CDF', 'USD'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _currency = v!),
            underline: const SizedBox(),
          ),
        ]),
        const SizedBox(height: 10),
        InkWell(
          onTap: () async {
            final d = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2000), lastDate: DateTime.now());
            if (d != null) setState(() => _startDate = d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date d\'entrée', isDense: true),
            child: Text(_startDate.toIso8601String().substring(0, 10), style: const TextStyle(fontSize: 14)),
          ),
        ),
        const Divider(height: 20),
        Row(children: [
          Expanded(child: TextFormField(controller: _cnssCtrl, decoration: const InputDecoration(labelText: 'N° CNSS'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _cinCtrl, decoration: const InputDecoration(labelText: 'CIN'))),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextFormField(controller: _bankCtrl, decoration: const InputDecoration(labelText: 'N° compte bancaire'))),
          const SizedBox(width: 10),
          Expanded(child: TextFormField(controller: _bankNameCtrl, decoration: const InputDecoration(labelText: 'Banque'))),
        ]),
        if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: AppColors.negative, fontSize: 12))],
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        ElevatedButton(onPressed: _loading ? null : _submit,
          child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(isEdit ? 'Enregistrer' : 'Créer')),
      ],
    );
  }
}
