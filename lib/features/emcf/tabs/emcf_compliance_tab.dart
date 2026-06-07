import 'dart:io';
import 'package:proxima/core/utils/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/core/utils/formatters.dart';

final _complianceDashProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfComplianceDashboard();
});

final _complianceStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfComplianceStats();
});

final _errorsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(apiClientProvider).getEmcfErrors();
});

class EmcfComplianceTab extends ConsumerStatefulWidget {
  const EmcfComplianceTab({super.key});

  @override
  ConsumerState<EmcfComplianceTab> createState() => _EmcfComplianceTabState();
}

class _EmcfComplianceTabState extends ConsumerState<EmcfComplianceTab> {
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final dashAsync = ref.watch(_complianceDashProvider);
    final errorsAsync = ref.watch(_errorsProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(_complianceDashProvider);
        ref.invalidate(_complianceStatsProvider);
        ref.invalidate(_errorsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(isDesktop ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPIs conformité
            dashAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => _ErrorBanner(parseError(e)),
              data: (data) => _ComplianceKpis(data: data, isDesktop: isDesktop),
            ),
            const SizedBox(height: 16),

            // Statistiques détaillées
            ref.watch(_complianceStatsProvider).whenData((stats) {
              if (stats.isEmpty) return const SizedBox();
              return _ComplianceStatsCard(stats: stats);
            }).value ?? const SizedBox(),
            const SizedBox(height: 20),

            // Export CSV + Réconciliation TVA
            _ExportCsvCard(from: _from, to: _to),
            const SizedBox(height: 12),
            _TvaReconciliationCard(from: _from, to: _to, onDateChanged: (f, t) => setState(() { _from = f; _to = t; })),
            const SizedBox(height: 20),

            // Factures en erreur
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 36, height: 36,
                          decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.error_outline, color: AppColors.negative, size: 18)),
                        const SizedBox(width: 12),
                        const Text('Factures en erreur DGI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        const Spacer(),
                        IconButton(icon: const Icon(Icons.refresh, size: 18), onPressed: () => ref.invalidate(_errorsProvider)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    errorsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => _ErrorBanner(parseError(e)),
                      data: (errors) => errors.isEmpty
                          ? Center(child: Padding(padding: const EdgeInsets.all(16),
                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                const Icon(Icons.check_circle_outline, color: AppColors.positive),
                                const SizedBox(width: 8),
                                Text('Aucune erreur DGI', style: TextStyle(color: Colors.grey[600])),
                              ])))
                          : Column(children: errors.map((e) => _ErrorRow(error: e as Map<String, dynamic>, ref: ref)).toList()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplianceKpis extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDesktop;
  const _ComplianceKpis({required this.data, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final rate = (data['complianceRate'] as num?)?.toDouble() ?? 0;
    final confirmed = data['confirmedCount'] as num? ?? 0;
    final pending = data['pendingCount'] as num? ?? 0;
    final errors = data['errorCount'] as num? ?? 0;
    final totalTva = (data['totalTva'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Taux de conformité — bandeau principal
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.8)]),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Taux de conformité e-MCF', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('${rate.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                  Text('Certifiées: $confirmed | Pending: $pending | Erreurs: $errors',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
              _CircularRate(rate: rate),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 3 : 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.0,
          children: [
            _KpiTile('Confirmées DGI', '$confirmed', AppColors.positive, Icons.verified_outlined),
            _KpiTile('En attente DGI', '$pending', AppColors.warning, Icons.pending_outlined),
            _KpiTile('TVA certifiée', Fmt.compact(totalTva), AppColors.primary, Icons.receipt_outlined),
          ],
        ),
      ],
    );
  }
}

class _CircularRate extends StatelessWidget {
  final double rate;
  const _CircularRate({required this.rate});

  @override
  Widget build(BuildContext context) {
    final color = rate >= 95 ? AppColors.positive : rate >= 80 ? AppColors.warning : AppColors.negative;
    return SizedBox(
      width: 72, height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: rate / 100, strokeWidth: 6, backgroundColor: Colors.white24,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          Text('${rate.toInt()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
      ),
    );
  }
}

class _TvaReconciliationCard extends ConsumerStatefulWidget {
  final DateTime from;
  final DateTime to;
  final void Function(DateTime, DateTime) onDateChanged;
  const _TvaReconciliationCard({required this.from, required this.to, required this.onDateChanged});

  @override
  ConsumerState<_TvaReconciliationCard> createState() => _TvaReconciliationCardState();
}

class _TvaReconciliationCardState extends ConsumerState<_TvaReconciliationCard> {
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ref.read(apiClientProvider).getEmcfTvaReconciliation(
        widget.from.year,
        widget.from.month,
      );
      setState(() => _data = r);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.balance_outlined, color: AppColors.primary, size: 18)),
                const SizedBox(width: 12),
                const Text('Réconciliation TVA DGI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const Spacer(),
                TextButton.icon(onPressed: _load, icon: const Icon(Icons.search, size: 16), label: const Text('Calculer')),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _DateField(label: 'Du', date: widget.from, onPicked: (d) => widget.onDateChanged(d, widget.to))),
              const SizedBox(width: 12),
              Expanded(child: _DateField(label: 'Au', date: widget.to, onPicked: (d) => widget.onDateChanged(widget.from, d))),
            ]),
            if (_loading) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
            if (_error != null) ...[const SizedBox(height: 8), _ErrorBanner(_error!)],
            if (_data != null) ...[
              const SizedBox(height: 16),
              _ReconciliationRow('TVA PROXIMA', (_data!['proximaTva'] as num?)?.toDouble() ?? 0, AppColors.primary),
              _ReconciliationRow('TVA DGI', (_data!['dgiTva'] as num?)?.toDouble() ?? 0, AppColors.positive),
              _ReconciliationRow('Écart', (_data!['gap'] as num?)?.toDouble() ?? 0, AppColors.negative),
            ],
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final void Function(DateTime) onPicked;
  const _DateField({required this.label, required this.date, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2020), lastDate: DateTime.now());
        if (d != null) onPicked(d);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(Icons.calendar_today_outlined, size: 16)),
        child: Text(Fmt.date(date), style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}

class _ReconciliationRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _ReconciliationRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(Fmt.currency(value), style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 14)),
        ],
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final Map<String, dynamic> error;
  final WidgetRef ref;
  const _ErrorRow({required this.error, required this.ref});

  @override
  Widget build(BuildContext context) {
    final invoiceId = error['invoiceId'] as String? ?? error['id'] as String? ?? '';
    final code = error['errorCode']?.toString() ?? '—';
    final msg = error['errorMessage'] as String? ?? error['message'] as String? ?? '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.negative.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.negative.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(invoiceId.length > 20 ? '${invoiceId.substring(0, 20)}…' : invoiceId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              Text('Code $code — $msg', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          )),
          TextButton.icon(
            onPressed: () async {
              await ref.read(apiClientProvider).retryEmcfInvoice(invoiceId);
            },
            icon: const Icon(Icons.refresh, size: 14),
            label: const Text('Retry', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _KpiTile(this.label, this.value, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE8ECF0))),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ])),
      ]),
    );
  }
}

class _ComplianceStatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _ComplianceStatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    final avgTime = stats['avgCertificationTimeMs'] as num?;
    final successRate = (stats['successRate'] as num?)?.toDouble() ?? 0;
    final totalSubmitted = stats['totalSubmitted'] as num? ?? 0;
    final totalConfirmed = stats['totalConfirmed'] as num? ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.analytics_outlined, color: AppColors.primary, size: 18)),
              const SizedBox(width: 12),
              const Text('Statistiques détaillées', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _StatLine('Soumises', '$totalSubmitted')),
              Expanded(child: _StatLine('Confirmées', '$totalConfirmed')),
              Expanded(child: _StatLine('Taux succès', '${successRate.toStringAsFixed(1)}%')),
              if (avgTime != null)
                Expanded(child: _StatLine('Délai moyen', '${(avgTime / 1000).toStringAsFixed(1)}s')),
            ]),
          ],
        ),
      ),
    );
  }
}

class _StatLine extends StatelessWidget {
  final String label;
  final String value;
  const _StatLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}

class _ExportCsvCard extends ConsumerStatefulWidget {
  final DateTime from;
  final DateTime to;
  const _ExportCsvCard({required this.from, required this.to});

  @override
  ConsumerState<_ExportCsvCard> createState() => _ExportCsvCardState();
}

class _ExportCsvCardState extends ConsumerState<_ExportCsvCard> {
  bool _loading = false;
  String? _savedPath;
  String? _error;

  Future<void> _export() async {
    setState(() { _loading = true; _savedPath = null; _error = null; });
    try {
      final fromStr = widget.from.toIso8601String().substring(0, 10);
      final toStr   = widget.to.toIso8601String().substring(0, 10);
      final bytes = await ref.read(apiClientProvider).downloadEmcfComplianceCsv(fromStr, toStr);
      final fileName = 'emcf_export_${fromStr}_$toStr.csv';
      final file = File('${Directory.systemTemp.path}/$fileName');
      await file.writeAsBytes(bytes);
      setState(() => _savedPath = file.path);
    } catch (e) {
      setState(() => _error = parseError(e));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: AppColors.positive.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.file_download_outlined, color: AppColors.positive, size: 18)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export CSV logs DGI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${Fmt.date(widget.from)} → ${Fmt.date(widget.to)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                if (_savedPath != null) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(child: SelectableText(_savedPath!,
                      style: const TextStyle(fontSize: 11, color: AppColors.positive))),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 14),
                      tooltip: 'Copier le chemin',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Clipboard.setData(ClipboardData(text: _savedPath!)),
                    ),
                  ]),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(_error!, style: const TextStyle(fontSize: 11, color: AppColors.negative)),
                ],
              ],
            )),
            ElevatedButton.icon(
              onPressed: _loading ? null : _export,
              icon: _loading
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.download_outlined, size: 16),
              label: const Text('Générer'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.positive),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.negative.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.negative.withValues(alpha: 0.2))),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.negative, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: AppColors.negative, fontSize: 12))),
      ]),
    );
  }
}
