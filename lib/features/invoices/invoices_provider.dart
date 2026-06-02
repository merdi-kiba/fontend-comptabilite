import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';

// ── Modèles ────────────────────────────────────────────────────────────────────

class InvoiceModel {
  final String id;
  final String number;
  final String type;
  final String status;
  final String tiersName;
  final double totalHT;
  final double totalTVA;
  final double totalTTC;
  final double amountPaid;
  final double outstanding;
  final DateTime createdAt;
  final DateTime? dueDate;

  const InvoiceModel({
    required this.id,
    required this.number,
    required this.type,
    required this.status,
    required this.tiersName,
    required this.totalHT,
    required this.totalTVA,
    required this.totalTTC,
    required this.amountPaid,
    required this.outstanding,
    required this.createdAt,
    this.dueDate,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      id: json['id'] as String,
      number: json['number'] as String,
      type: json['type'] as String? ?? 'FV',
      status: json['status'] as String? ?? 'DRAFT',
      tiersName: (json['tiers'] as Map?)?['name'] as String? ?? json['tiersId'] as String? ?? '—',
      totalHT: (json['totalHT'] as num?)?.toDouble() ?? 0,
      totalTVA: (json['totalTVA'] as num?)?.toDouble() ?? 0,
      totalTTC: (json['totalTTC'] as num?)?.toDouble() ?? 0,
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0,
      outstanding: (json['outstanding'] as num?)?.toDouble() ??
          ((json['totalTTC'] as num?)?.toDouble() ?? 0) - ((json['amountPaid'] as num?)?.toDouble() ?? 0),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      dueDate: json['dueDate'] != null ? DateTime.tryParse(json['dueDate'] as String) : null,
    );
  }

  bool get isOverdue => dueDate != null && dueDate!.isBefore(DateTime.now()) && status != 'PAID' && status != 'CANCELLED';
  bool get isPaid => status == 'PAID';
  bool get isDraft => status == 'DRAFT';
}

// ── Filtre factures ────────────────────────────────────────────────────────────

class InvoiceFilter {
  final String? status;
  final String? type;
  final String? search;
  final DateTime? from;
  final DateTime? to;

  const InvoiceFilter({this.status, this.type, this.search, this.from, this.to});

  InvoiceFilter copyWith({String? status, String? type, String? search, DateTime? from, DateTime? to}) =>
      InvoiceFilter(
        status: status ?? this.status,
        type: type ?? this.type,
        search: search ?? this.search,
        from: from ?? this.from,
        to: to ?? this.to,
      );
}

final invoiceFilterProvider = StateProvider<InvoiceFilter>((ref) => const InvoiceFilter());

// ── Provider liste factures ────────────────────────────────────────────────────

final invoicesProvider = FutureProvider.autoDispose<List<InvoiceModel>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final filter = ref.watch(invoiceFilterProvider);

  final params = <String, dynamic>{};
  if (filter.status != null) params['status'] = filter.status;
  if (filter.type != null) params['type'] = filter.type;

  try {
    final res = await api.dio.get('/invoices', queryParameters: params.isNotEmpty ? params : null);
    final list = (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List;
    return list.map((j) => InvoiceModel.fromJson(j as Map<String, dynamic>)).toList();
  } catch (_) {
    return [];
  }
});

// ── Provider détail facture ────────────────────────────────────────────────────

final invoiceDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/invoices/$id');
  return res.data as Map<String, dynamic>;
});
