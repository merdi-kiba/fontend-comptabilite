import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _alertSettingsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getAlertSettings();
});

class CabinetAlertsTab extends ConsumerWidget {
  const CabinetAlertsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(_alertSettingsProvider);

    return settingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(parseError(e), style: const TextStyle(color: AppColors.negative))),
      data: (settings) => _AlertsForm(
        settings: settings,
        onSaved: () => ref.invalidate(_alertSettingsProvider),
      ),
    );
  }
}

class _AlertsForm extends ConsumerStatefulWidget {
  final Map<String, dynamic> settings;
  final VoidCallback onSaved;
  const _AlertsForm({required this.settings, required this.onSaved});

  @override
  ConsumerState<_AlertsForm> createState() => _AlertsFormState();
}

class _AlertsFormState extends ConsumerState<_AlertsForm> {
  late final TextEditingController _cashCtrl;
  late final TextEditingController _emailCtrl;
  late bool _overdueInvoices30;
  late bool _overdueInvoices90;
  late bool _vatDueSoon;
  late bool _fiscalYearClose;
  late bool _largeUnusualEntry;
  late bool _bankReconciliation;
  late bool _budgetOverrun;
  bool _loading = false;
  bool _checking = false;
  String? _error;
  String? _success;

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _cashCtrl = TextEditingController(text: (s['lowCashThreshold'] ?? '').toString());
    _emailCtrl = TextEditingController(text: s['weeklyDigestEmail'] as String? ?? '');
    _overdueInvoices30 = s['overdueInvoices30'] as bool? ?? true;
    _overdueInvoices90 = s['overdueInvoices90'] as bool? ?? true;
    _vatDueSoon = s['vatDueSoon'] as bool? ?? true;
    _fiscalYearClose = s['fiscalYearClose'] as bool? ?? true;
    _largeUnusualEntry = s['largeUnusualEntry'] as bool? ?? true;
    _bankReconciliation = s['bankReconciliation'] as bool? ?? true;
    _budgetOverrun = s['budgetOverrun'] as bool? ?? true;
  }

  @override
  void dispose() {
    _cashCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() { _loading = true; _error = null; _success = null; });
    try {
      await ref.read(apiClientProvider).updateAlertSettings({
        'lowCashThreshold': double.tryParse(_cashCtrl.text) ?? 0,
        'overdueInvoices30': _overdueInvoices30,
        'overdueInvoices90': _overdueInvoices90,
        'vatDueSoon': _vatDueSoon,
        'fiscalYearClose': _fiscalYearClose,
        'largeUnusualEntry': _largeUnusualEntry,
        'bankReconciliation': _bankReconciliation,
        'budgetOverrun': _budgetOverrun,
        'weeklyDigestEmail': _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      });
      setState(() => _success = 'Paramètres sauvegardés.');
      widget.onSaved();
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _checkNow() async {
    setState(() { _checking = true; _success = null; _error = null; });
    try {
      await ref.read(apiClientProvider).checkCabinetAlerts();
      setState(() => _success = 'Vérification lancée. Les alertes seront mises à jour.');
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Paramètres d\'alertes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Configurez les seuils de surveillance automatique', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _checking ? null : _checkNow,
                icon: _checking
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_outlined, size: 18),
                label: const Text('Vérifier maintenant'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Seuil trésorerie
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seuil trésorerie (CDF)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Alerte LOW_CASH si la trésorerie passe sous ce montant', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cashCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.savings_outlined, size: 18),
                      hintText: 'Ex: 1000000',
                      suffixText: 'CDF',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Toggles alertes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alertes actives', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 12),
                  _AlertToggle(
                    label: 'Factures en retard +30j',
                    description: 'Alerte OVERDUE_30',
                    value: _overdueInvoices30,
                    onChanged: (v) => setState(() => _overdueInvoices30 = v),
                  ),
                  _AlertToggle(
                    label: 'Factures en retard +90j',
                    description: 'Alerte OVERDUE_90',
                    value: _overdueInvoices90,
                    onChanged: (v) => setState(() => _overdueInvoices90 = v),
                  ),
                  _AlertToggle(
                    label: 'Déclaration TVA imminente',
                    description: 'Alerte VAT_DUE_SOON — 7 jours avant échéance',
                    value: _vatDueSoon,
                    onChanged: (v) => setState(() => _vatDueSoon = v),
                  ),
                  _AlertToggle(
                    label: 'Clôture exercice proche',
                    description: 'Alerte FISCAL_YEAR_CLOSE — 30 jours avant',
                    value: _fiscalYearClose,
                    onChanged: (v) => setState(() => _fiscalYearClose = v),
                  ),
                  _AlertToggle(
                    label: 'Écriture inhabituelle',
                    description: 'Alerte LARGE_UNUSUAL_ENTRY — montant > 10× la moyenne',
                    value: _largeUnusualEntry,
                    onChanged: (v) => setState(() => _largeUnusualEntry = v),
                  ),
                  _AlertToggle(
                    label: 'Rapprochement bancaire en retard',
                    description: 'Alerte BANK_RECONCILIATION — relevé non réconcilié +30j',
                    value: _bankReconciliation,
                    onChanged: (v) => setState(() => _bankReconciliation = v),
                  ),
                  _AlertToggle(
                    label: 'Dépassement budgétaire',
                    description: 'Alerte BUDGET_OVERRUN — dépassement > 10%',
                    value: _budgetOverrun,
                    onChanged: (v) => setState(() => _budgetOverrun = v),
                    showDivider: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Email digest
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rapport hebdomadaire', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Envoi automatique chaque lundi matin', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                      hintText: 'manager@cabinet.cd',
                      labelText: 'Email destinataire',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_error != null) ...[
            _Banner(message: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          if (_success != null) ...[
            _Banner(message: _success!, isError: false),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Enregistrer les paramètres'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertToggle extends StatelessWidget {
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;
  const _AlertToggle({required this.label, required this.description, required this.value, required this.onChanged, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.negative : AppColors.positive;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}
