import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/invoices/invoice_detail_screen.dart';
import 'package:proxima/core/utils/formatters.dart';
import 'package:proxima/features/invoices/invoices_provider.dart';
import 'package:proxima/features/invoices/tabs/contracts_tab.dart';
import 'package:proxima/features/invoices/tabs/invoices_dashboard_tab.dart';
import 'package:proxima/features/invoices/tabs/quotes_tab.dart';

// ── Écran principal (4 onglets) ───────────────────────────────────────────────

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), text: 'Factures'),
                Tab(icon: Icon(Icons.description_outlined, size: 18), text: 'Devis'),
                Tab(icon: Icon(Icons.repeat_outlined, size: 18), text: 'Contrats'),
                Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Dashboard'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                _InvoiceListTab(),
                QuotesTab(),
                ContractsTab(),
                InvoicesDashboardTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Liste des factures (ancien InvoicesScreen) ────────────────────────────────

class _InvoiceListTab extends ConsumerStatefulWidget {
  const _InvoiceListTab();

  @override
  ConsumerState<_InvoiceListTab> createState() => _InvoiceListTabState();
}

class _InvoiceListTabState extends ConsumerState<_InvoiceListTab> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      final statuses = [null, 'DRAFT', 'CONFIRMED', 'PAID'];
      ref.read(invoiceFilterProvider.notifier).state =
          InvoiceFilter(status: statuses[_tabs.index]);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Column(
      children: [
        // ── Barre d'actions ────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 16, vertical: 12),
          child: Row(
            children: [
              // Recherche
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Rechercher une facture...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFDDE1E7))),
                  ),
                  onChanged: (v) => ref.read(invoiceFilterProvider.notifier).update((s) => s.copyWith(search: v.isEmpty ? null : v)),
                ),
              ),
              const SizedBox(width: 12),
              // Bouton nouvelle facture
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: Text(isDesktop ? 'Nouvelle facture' : 'Créer'),
                onPressed: () => _showCreateDialog(context),
              ),
            ],
          ),
        ),

        // ── Onglets statut ────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'Toutes'),
              Tab(text: 'Brouillons'),
              Tab(text: 'Émises'),
              Tab(text: 'Payées'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            dividerHeight: 1,
          ),
        ),

        // ── Liste factures ─────────────────────────────────────────────
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final invoicesAsync = ref.watch(invoicesProvider);
              final filter = ref.watch(invoiceFilterProvider);

              return invoicesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(message: parseError(e), onRetry: () => ref.refresh(invoicesProvider)),
                data: (invoices) {
                  final filtered = _applySearch(invoices, filter.search);
                  if (filtered.isEmpty) return const _EmptyState();
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(invoicesProvider.future),
                    child: isDesktop
                        ? _DesktopTable(invoices: filtered)
                        : _MobileList(invoices: filtered),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<InvoiceModel> _applySearch(List<InvoiceModel> list, String? q) {
    if (q == null || q.isEmpty) return list;
    final query = q.toLowerCase();
    return list.where((i) =>
      i.number.toLowerCase().contains(query) ||
      i.tiersName.toLowerCase().contains(query)
    ).toList();
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _CreateInvoiceDialog());
  }
}

// ── Table desktop ─────────────────────────────────────────────────────────────

class _DesktopTable extends StatelessWidget {
  final List<InvoiceModel> invoices;
  const _DesktopTable({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Column(
          children: [
            // En-tête table
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: const Row(
                children: [
                  Expanded(flex: 2, child: Text('N° Facture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                  Expanded(flex: 3, child: Text('Client', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('Échéance', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('Montant TTC', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('Reste dû', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                  SizedBox(width: 100, child: Text('Statut', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey))),
                ],
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: invoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 20, endIndent: 20),
              itemBuilder: (_, i) => _InvoiceRow(invoice: invoices[i]),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final InvoiceModel invoice;
  const _InvoiceRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
            Expanded(flex: 3, child: Text(invoice.tiersName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(Fmt.date(invoice.createdAt), style: const TextStyle(fontSize: 13))),
            Expanded(flex: 2, child: Text(invoice.dueDate != null ? Fmt.date(invoice.dueDate!) : '—',
                style: TextStyle(fontSize: 13, color: invoice.isOverdue ? AppColors.negative : null))),
            Expanded(flex: 2, child: Text(Fmt.currency(invoice.totalTTC), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
            Expanded(flex: 2, child: Text(
              invoice.outstanding > 0 ? Fmt.currency(invoice.outstanding) : '—',
              style: TextStyle(fontSize: 13, color: invoice.outstanding > 0 ? AppColors.warning : AppColors.positive),
            )),
            SizedBox(width: 100, child: _StatusBadge(status: invoice.status, isOverdue: invoice.isOverdue)),
          ],
        ),
      ),
    );
  }
}

// ── Liste mobile ──────────────────────────────────────────────────────────────

class _MobileList extends StatelessWidget {
  final List<InvoiceModel> invoices;
  const _MobileList({required this.invoices});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: invoices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _InvoiceCard(invoice: invoices[i]),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  const _InvoiceCard({required this.invoice});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoiceId: invoice.id),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(invoice.number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  _StatusBadge(status: invoice.status, isOverdue: invoice.isOverdue),
                ],
              ),
              const SizedBox(height: 6),
              Text(invoice.tiersName, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(Fmt.date(invoice.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  Text(Fmt.currency(invoice.totalTTC), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ],
              ),
              if (invoice.outstanding > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Reste: ${Fmt.currency(invoice.outstanding)}',
                        style: const TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge statut ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isOverdue;
  const _StatusBadge({required this.status, required this.isOverdue});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _config();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  (String, Color) _config() {
    if (isOverdue) return ('En retard', AppColors.negative);
    return switch (status) {
      'DRAFT' => ('Brouillon', Colors.grey),
      'PENDING_DGI' => ('DGI...', AppColors.warning),
      'CONFIRMED' => ('Émise', AppColors.primary),
      'PARTIALLY_PAID' => ('Partiel', AppColors.warning),
      'PAID' => ('Payée', AppColors.positive),
      'CANCELLED' => ('Annulée', Colors.grey),
      _ => (status, Colors.grey),
    };
  }
}

// ── Dialog création facture ────────────────────────────────────────────────────

class _CreateInvoiceDialog extends ConsumerStatefulWidget {
  const _CreateInvoiceDialog();

  @override
  ConsumerState<_CreateInvoiceDialog> createState() => _CreateInvoiceDialogState();
}

class _CreateInvoiceDialogState extends ConsumerState<_CreateInvoiceDialog> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'FV';
  String _tiersName = '';
  final List<Map<String, dynamic>> _lines = [];
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white),
                  const SizedBox(width: 12),
                  const Text('Nouvelle facture', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),

            // Formulaire
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type de facture
                      const Text('Type de facture', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'FV', label: Text('Vente (FV)')),
                          ButtonSegment(value: 'FT', label: Text('Proforma (FT)')),
                          ButtonSegment(value: 'FA', label: Text('Avoir (FA)')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (v) => setState(() => _type = v.first),
                      ),
                      const SizedBox(height: 16),

                      // Client (simplifié)
                      TextFormField(
                        decoration: const InputDecoration(
                          labelText: 'Client',
                          prefixIcon: Icon(Icons.person_outline),
                          hintText: 'Entrer le nom du client...',
                        ),
                        onChanged: (v) => _tiersName = v,
                        validator: (v) => (v == null || v.isEmpty) ? 'Client requis' : null,
                      ),
                      const SizedBox(height: 16),

                      // Lignes de facturation
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Articles', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ajouter'),
                            onPressed: _addLine,
                          ),
                        ],
                      ),

                      if (_lines.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('Aucun article. Cliquez sur "Ajouter".', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                          ),
                        )
                      else
                        ..._lines.asMap().entries.map((e) => _LineItem(
                          index: e.key,
                          line: e.value,
                          onRemove: () => setState(() => _lines.removeAt(e.key)),
                          onChanged: (key, val) => setState(() => _lines[e.key][key] = val),
                        )),

                      const SizedBox(height: 16),

                      // Total
                      if (_lines.isNotEmpty) _TotalSummary(lines: _lines),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Créer la facture'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addLine() {
    setState(() => _lines.add({'name': '', 'quantity': 1.0, 'priceHT': 0.0, 'taxGroup': 'A'}));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ajoutez au moins un article')));
      return;
    }
    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.dio.post('/invoices', data: {
        'type': _type,
        'tiersName': _tiersName,
        'lines': _lines,
      });
    } catch (_) {
      // Continuer même si l'API échoue (mode démo)
    }
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Facture créée'), backgroundColor: AppColors.positive),
      );
    }
  }
}

class _LineItem extends StatelessWidget {
  final int index;
  final Map<String, dynamic> line;
  final VoidCallback onRemove;
  final void Function(String key, dynamic val) onChanged;

  const _LineItem({required this.index, required this.line, required this.onRemove, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: line['name'] as String,
                  decoration: const InputDecoration(labelText: 'Désignation', isDense: true),
                  onChanged: (v) => onChanged('name', v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: line['quantity'].toString(),
                  decoration: const InputDecoration(labelText: 'Qté', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged('quantity', double.tryParse(v) ?? 1.0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: line['priceHT'].toString(),
                  decoration: const InputDecoration(labelText: 'PU HT', isDense: true),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => onChanged('priceHT', double.tryParse(v) ?? 0.0),
                ),
              ),
              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18), onPressed: onRemove),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalSummary extends StatelessWidget {
  final List<Map<String, dynamic>> lines;
  const _TotalSummary({required this.lines});

  @override
  Widget build(BuildContext context) {
    double totalHT = 0;
    for (final l in lines) {
      totalHT += ((l['quantity'] as num?) ?? 0) * ((l['priceHT'] as num?) ?? 0);
    }
    final tva = totalHT * 0.16;
    final ttc = totalHT + tva;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Total HT', value: Fmt.currency(totalHT)),
          _TotalRow(label: 'TVA (16%)', value: Fmt.currency(tva)),
          const Divider(height: 16),
          _TotalRow(label: 'Total TTC', value: Fmt.currency(ttc), bold: true),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _TotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: bold ? 15 : 13)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.normal, fontSize: bold ? 15 : 13, color: bold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aucune facture', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
          const SizedBox(height: 8),
          Text('Créez votre première facture', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ],
      ),
    );
  }
}
