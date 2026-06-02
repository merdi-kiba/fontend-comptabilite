import 'package:proxima/core/utils/error_utils.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';

final _exFyProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getFiscalYears();
});

class ExportsTab extends ConsumerStatefulWidget {
  const ExportsTab({super.key});

  @override
  ConsumerState<ExportsTab> createState() => _ExportsTabState();
}

class _ExportsTabState extends ConsumerState<ExportsTab> {
  String? _selectedFyId;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  final Map<String, bool> _loading = {};
  String? _lastDownload;
  String? _lastError;

  Future<void> _download(String key, String path, String filename, {Map<String, dynamic>? params}) async {
    setState(() { _loading[key] = true; _lastDownload = null; _lastError = null; });
    try {
      final bytes = await ref.read(apiClientProvider).downloadReport(path, params: params);
      if (bytes.isEmpty) throw Exception('Fichier vide retourné par le serveur');
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
      final downloadsDir = Directory('$home/Downloads');
      if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);
      final file = File('${downloadsDir.path}/$filename');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() => _lastDownload = file.path);
    } catch (e) {
      if (mounted) setState(() => _lastError = parseError(e));
    } finally {
      if (mounted) setState(() => _loading[key] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fyList = ref.watch(_exFyProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Fiscal year + period selectors
        Card(child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Paramètres d\'export', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: fyList.when(
                loading: () => const SizedBox(height: 36),
                error: (e, st) => const SizedBox(),
                data: (fys) {
                  final eid = _selectedFyId ?? (fys.isNotEmpty ? (fys.first as Map)['id'] as String? : null);
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Exercice fiscal'),
                    initialValue: eid,
                    items: fys.map((f) {
                      final m = f as Map<String, dynamic>;
                      return DropdownMenuItem<String>(value: m['id'] as String, child: Text(m['name'] as String? ?? '—'));
                    }).toList(),
                    onChanged: (v) => setState(() => _selectedFyId = v),
                  );
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Année'),
                initialValue: _year,
                items: [2024, 2025, 2026, 2027].map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
                onChanged: (v) => setState(() => _year = v!),
              )),
              const SizedBox(width: 12),
              Expanded(child: DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Mois'),
                initialValue: _month,
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_monthName(i + 1)))),
                onChanged: (v) => setState(() => _month = v!),
              )),
            ]),
          ]),
        )),

        // Feedback
        if (_lastDownload != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: AppColors.positive, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Téléchargé : $_lastDownload', style: const TextStyle(color: AppColors.positive, fontSize: 12))),
              IconButton(icon: const Icon(Icons.copy, size: 14), onPressed: () => Clipboard.setData(ClipboardData(text: _lastDownload ?? ''))),
            ]),
          ),
        ],
        if (_lastError != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(_lastError!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
          ),
        ],
        const SizedBox(height: 16),

        // Excel exports
        _SectionHeader('Exports Excel', Icons.table_chart_outlined, Colors.green[700]!),
        const SizedBox(height: 10),
        _ExportGrid(children: [
          _ExportTile('Balance générale', Icons.balance_outlined, Colors.green[700]!, isLoading: _loading['excel_balance'] == true,
            onTap: () => _download('excel_balance', '/reports/excel/balance', 'balance_$_year.xlsx', params: _selectedFyId != null ? {'fiscalYearId': _selectedFyId} : null)),
          _ExportTile('Grand livre', Icons.menu_book_outlined, Colors.green[700]!, isLoading: _loading['excel_ledger'] == true,
            onTap: () => _download('excel_ledger', '/reports/excel/ledger', 'grand_livre_$_year.xlsx', params: {'from': '$_year-01-01', 'to': '$_year-12-31'})),
          _ExportTile('Factures', Icons.receipt_long_outlined, Colors.green[700]!, isLoading: _loading['excel_invoices'] == true,
            onTap: () => _download('excel_invoices', '/reports/excel/invoices', 'factures_$_year.xlsx', params: {'from': '$_year-01-01', 'to': '$_year-12-31'})),
          _ExportTile('Stock valorisé', Icons.inventory_2_outlined, Colors.green[700]!, isLoading: _loading['excel_stock'] == true,
            onTap: () => _download('excel_stock', '/reports/excel/stock', 'stock_${DateTime.now().toIso8601String().substring(0, 10)}.xlsx')),
          _ExportTile('Masse salariale', Icons.people_outlined, Colors.green[700]!, isLoading: _loading['excel_payroll'] == true,
            onTap: () => _download('excel_payroll', '/reports/excel/payroll', 'paie_${_monthName(_month)}_$_year.xlsx', params: {'year': _year, 'month': _month})),
          _ExportTile('Déclaration CNSS', Icons.assignment_outlined, Colors.green[700]!, isLoading: _loading['excel_cnss'] == true,
            onTap: () => _download('excel_cnss', '/reports/excel/cnss', 'cnss_${_monthName(_month)}_$_year.xlsx', params: {'year': _year, 'month': _month})),
        ]),
        const SizedBox(height: 20),

        // PDF exports
        _SectionHeader('Exports PDF', Icons.picture_as_pdf_outlined, Colors.red[700]!),
        const SizedBox(height: 10),
        _ExportGrid(children: [
          _ExportTile('Bilan', Icons.account_balance_outlined, Colors.red[700]!, isLoading: _loading['pdf_bilan'] == true,
            onTap: () => _download('pdf_bilan', '/reports/pdf/balance-sheet', 'bilan_$_year.pdf', params: _selectedFyId != null ? {'fiscalYearId': _selectedFyId} : null)),
          _ExportTile('Compte de résultat', Icons.trending_up_outlined, Colors.red[700]!, isLoading: _loading['pdf_result'] == true,
            onTap: () => _download('pdf_result', '/reports/pdf/income-statement', 'resultat_$_year.pdf', params: _selectedFyId != null ? {'fiscalYearId': _selectedFyId} : null)),
          _ExportTile('Balance générale', Icons.balance_outlined, Colors.red[700]!, isLoading: _loading['pdf_balance'] == true,
            onTap: () => _download('pdf_balance', '/reports/pdf/general-balance', 'balance_generale_$_year.pdf', params: _selectedFyId != null ? {'fiscalYearId': _selectedFyId} : null)),
          _ExportTile('Immobilisations', Icons.business_center_outlined, Colors.red[700]!, isLoading: _loading['pdf_assets'] == true,
            onTap: () => _download('pdf_assets', '/reports/pdf/fixed-assets', 'immobilisations.pdf')),
          _ExportTile('Déclaration TVA', Icons.receipt_outlined, Colors.red[700]!, isLoading: _loading['pdf_tva'] == true,
            onTap: () => _download('pdf_tva', '/reports/pdf/vat-return', 'tva_${_monthName(_month)}_$_year.pdf', params: {'year': _year, 'month': _month})),
        ]),
        const SizedBox(height: 20),

        // DGI reports + liasse fiscale
        _SectionHeader('DGI & Liasse fiscale', Icons.verified_user_outlined, AppColors.warning),
        const SizedBox(height: 10),
        _DgiSection(year: _year, month: _month, selectedFyId: _selectedFyId, loading: _loading,
          onDownload: (k, p, f, pa) => _download(k, p, f, params: pa)),
      ]),
    );
  }
}

// ── DGI section ───────────────────────────────────────────────────────────────

class _DgiSection extends ConsumerStatefulWidget {
  final int year;
  final int month;
  final String? selectedFyId;
  final Map<String, bool> loading;
  final Future<void> Function(String, String, String, Map<String, dynamic>?) onDownload;
  const _DgiSection({required this.year, required this.month, required this.selectedFyId, required this.loading, required this.onDownload});

  @override
  ConsumerState<_DgiSection> createState() => _DgiSectionState();
}

class _DgiSectionState extends ConsumerState<_DgiSection> {
  Map<String, dynamic>? _dgiData;
  String? _dgiError;
  bool _dgiLoading = false;
  bool _liasseLoading = false;
  String? _liasseUrl;

  Future<void> _loadDgi(String type) async {
    setState(() { _dgiLoading = true; _dgiData = null; _dgiError = null; });
    try {
      Map<String, dynamic> r;
      switch (type) {
        case 'X': r = await ref.read(apiClientProvider).getDgiReportX(DateTime.now().toIso8601String().substring(0, 10)); break;
        case 'Z': r = await ref.read(apiClientProvider).getDgiReportZ(DateTime.now().toIso8601String().substring(0, 10)); break;
        case 'P': r = await ref.read(apiClientProvider).getDgiReportP(widget.year, widget.month); break;
        default:  r = await ref.read(apiClientProvider).getDgiReportA(widget.year);
      }
      if (mounted) setState(() => _dgiData = r);
    } catch (e) {
      if (mounted) setState(() => _dgiError = parseError(e));
    } finally {
      if (mounted) setState(() => _dgiLoading = false);
    }
  }

  Future<void> _generateLiasse() async {
    if (widget.selectedFyId == null) return;
    setState(() { _liasseLoading = true; _liasseUrl = null; });
    try {
      final r = await ref.read(apiClientProvider).generateLiasseFiscale(widget.selectedFyId!);
      if (mounted) setState(() => _liasseUrl = r['url'] as String?);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(parseError(e)), backgroundColor: AppColors.negative));
    } finally {
      if (mounted) setState(() => _liasseLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // DGI report buttons
      Row(children: [
        Expanded(child: _DgiButton('Rapport X', 'Journalier', () => _loadDgi('X'), _dgiLoading)),
        const SizedBox(width: 8),
        Expanded(child: _DgiButton('Rapport Z', 'Clôture', () => _loadDgi('Z'), _dgiLoading)),
        const SizedBox(width: 8),
        Expanded(child: _DgiButton('Rapport P', 'Mensuel', () => _loadDgi('P'), _dgiLoading)),
        const SizedBox(width: 8),
        Expanded(child: _DgiButton('Rapport A', 'Annuel', () => _loadDgi('A'), _dgiLoading)),
      ]),
      if (_dgiError != null) ...[
        const SizedBox(height: 8),
        Text(_dgiError!, style: const TextStyle(color: AppColors.negative, fontSize: 12)),
      ],
      if (_dgiData != null) ...[
        const SizedBox(height: 10),
        Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Données DGI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 8),
            ..._dgiData!.entries.take(8).map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontSize: 12))),
                Text('${e.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            )),
          ]),
        )),
      ],
      const SizedBox(height: 14),
      // Liasse fiscale
      Card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.folder_zip_outlined, color: AppColors.warning, size: 18)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Liasse fiscale complète', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Bilan + CPC + TAFIRE + Balance + GL + TVA annuelle (ZIP)', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ])),
          ]),
          if (_liasseUrl != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.link, size: 14, color: AppColors.positive),
                const SizedBox(width: 6),
                Expanded(child: Text('URL MinIO prête (valide 24h)', style: const TextStyle(color: AppColors.positive, fontSize: 12))),
                IconButton(icon: const Icon(Icons.copy, size: 14), onPressed: () => Clipboard.setData(ClipboardData(text: _liasseUrl!))),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.selectedFyId == null || _liasseLoading ? null : _generateLiasse,
              icon: _liasseLoading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined),
              label: Text(_liasseLoading ? 'Génération en cours…' : 'Générer la liasse fiscale'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
            ),
          ),
        ]),
      )),
    ]);
  }
}

class _DgiButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;
  const _DgiButton(this.title, this.subtitle, this.onTap, this.loading);

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: loading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.warning))
          : Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.warning)),
        const SizedBox(height: 2),
        Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ]),
    ),
  );
}

// ── Export tile & grid ────────────────────────────────────────────────────────

class _ExportGrid extends StatelessWidget {
  final List<Widget> children;
  const _ExportGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isDesktop ? 3 : 2,
      crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4,
      children: children,
    );
  }
}

class _ExportTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isLoading;
  final VoidCallback onTap;
  const _ExportTile(this.label, this.icon, this.color, {required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: isLoading ? null : onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8ECF0)),
      ),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: isLoading
              ? Padding(padding: const EdgeInsets.all(6), child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, color: color, size: 16)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isLoading ? Colors.grey : null), overflow: TextOverflow.ellipsis),
          Text(isLoading ? 'Téléchargement…' : 'Télécharger', style: TextStyle(fontSize: 9, color: color)),
        ])),
      ]),
    ),
  );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader(this.title, this.icon, this.color);

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 18, color: color),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: color)),
  ]);
}

String _monthName(int m) {
  const names = ['', 'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun', 'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
  return m >= 1 && m <= 12 ? names[m] : '$m';
}
