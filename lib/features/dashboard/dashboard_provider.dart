import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';

class DashboardData {
  final Map<String, dynamic> global;
  final Map<String, dynamic> accounting;
  final Map<String, dynamic> invoices;
  final Map<String, dynamic> treasury;
  final List<dynamic> monthlyTrend;

  const DashboardData({
    required this.global,
    required this.accounting,
    required this.invoices,
    required this.treasury,
    required this.monthlyTrend,
  });
}

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final api = ref.watch(apiClientProvider);
  final auth = ref.watch(authProvider);

  if (!auth.hasTenant) {
    return DashboardData(global: {}, accounting: {}, invoices: {}, treasury: {}, monthlyTrend: []);
  }

  // Charger tout en parallèle
  final results = await Future.wait([
    api.getGlobalDashboard().catchError((_) => <String, dynamic>{}),
    api.getAccountingOverview().catchError((_) => <String, dynamic>{}),
    api.getInvoicesSummary().catchError((_) => <String, dynamic>{}),
    api.getTreasurySummary().catchError((_) => <String, dynamic>{}),
    api.getMonthlyTrend().catchError((_) => <dynamic>[]),
  ]);

  return DashboardData(
    global: results[0] as Map<String, dynamic>,
    accounting: results[1] as Map<String, dynamic>,
    invoices: results[2] as Map<String, dynamic>,
    treasury: results[3] as Map<String, dynamic>,
    monthlyTrend: results[4] as List<dynamic>,
  );
});
