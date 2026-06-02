import 'dart:async';
import 'package:dio/dio.dart';
import 'package:proxima/core/config/app_config.dart';
import 'package:proxima/core/auth/token_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  late final Dio _dio;

  /// Called by AuthNotifier on startup. Fires when the refresh token is
  /// expired/invalid so the app can redirect to login automatically.
  static void Function()? onSessionExpired;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _ErrorInterceptor(),
      LogInterceptor(
        request: false,
        requestHeader: false,
        responseBody: false,
        error: true,
      ),
    ]);
  }

  Dio get dio => _dio;

  // ── Auth ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password, {String? mfaCode}) async {
    final body = <String, dynamic>{'username': username, 'password': password};
    if (mfaCode != null) body['mfaCode'] = mfaCode;
    final res = await _dio.post('/auth/login', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setupMfa() async {
    final res = await _dio.get('/auth/mfa/setup');
    return res.data as Map<String, dynamic>;
  }

  Future<void> verifyMfa(String code) async {
    await _dio.post('/auth/mfa/verify', data: {'code': code});
  }

  Future<void> disableMfa(String code) async {
    await _dio.delete('/auth/mfa', data: {'code': code});
  }

  Future<Map<String, dynamic>> forgotPassword(String username) async {
    final res = await _dio.post('/auth/password/forgot', data: {'username': username});
    return res.data as Map<String, dynamic>;
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post('/auth/password/reset', data: {'token': token, 'newPassword': newPassword});
  }

  Future<List<dynamic>> getSessions() async {
    final res = await _dio.get('/auth/sessions');
    return res.data as List<dynamic>;
  }

  Future<void> revokeSession(String jti) async {
    await _dio.delete('/auth/sessions/$jti');
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.patch('/auth/password/change', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<Map<String, dynamic>> refresh(String refreshToken) async {
    final res = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});
    return res.data as Map<String, dynamic>;
  }

  Future<void> logout() async {
    try { await _dio.post('/auth/logout'); } catch (_) {}
  }

  // ── Tenants ───────────────────────────────────────────────────────

  Future<List<dynamic>> getMyTenants() async {
    final res = await _dio.get('/tenants/my-tenants');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getAllTenants({String? status, int page = 1, int limit = 50}) async {
    final params = <String, dynamic>{'page': page, 'limit': limit};
    if (status != null) params['status'] = status;
    final res = await _dio.get('/tenants', queryParameters: params);
    final data = res.data;
    if (data is List) return data;
    if (data is Map) return (data['data'] as List?) ?? [];
    return [];
  }

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> data) async {
    final res = await _dio.post('/tenants', data: data);
    return res.data as Map<String, dynamic>;
  }

  // Pour les membres de cabinet : POST /cabinet/switch/:id
  // Pour le SUPERADMIN : POST /tenants/:id/switch
  Future<Map<String, dynamic>> switchTenant(String tenantId, {bool asSuperAdmin = false}) async {
    final url = asSuperAdmin ? '/tenants/$tenantId/switch' : '/cabinet/switch/$tenantId';
    final res = await _dio.post(url);
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Chart of Accounts ───────────────────────────────

  Future<List<dynamic>> getAccounts({String? accountClass, String? search}) async {
    final p = <String, dynamic>{};
    if (accountClass != null) p['class'] = accountClass;
    if (search != null) p['search'] = search;
    final res = await _dio.get('/accounting/accounts', queryParameters: p.isEmpty ? null : p);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/accounts', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAccount(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/accounting/accounts/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAccountBalance(String id, String from, String to) async {
    final res = await _dio.get('/accounting/accounts/$id/balance', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Fiscal Years ─────────────────────────────────────

  Future<List<dynamic>> getFiscalYears() async {
    final res = await _dio.get('/accounting/fiscal-years');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createFiscalYear(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/fiscal-years', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getFiscalYearPeriods(String fyId) async {
    final res = await _dio.get('/accounting/fiscal-years/$fyId/periods');
    return res.data as List<dynamic>;
  }

  Future<void> lockPeriod(String periodId) async {
    await _dio.patch('/accounting/fiscal-years/periods/$periodId/lock');
  }

  Future<void> unlockPeriod(String periodId) async {
    await _dio.patch('/accounting/fiscal-years/periods/$periodId/unlock');
  }

  Future<Map<String, dynamic>> getClosureChecklist(String fyId) async {
    final res = await _dio.get('/accounting/fiscal-years/$fyId/closure-checklist');
    return res.data as Map<String, dynamic>;
  }

  Future<void> closeFiscalYear(String fyId) async {
    await _dio.post('/accounting/fiscal-years/$fyId/close');
  }

  Future<Map<String, dynamic>> getFiscalYearComparative(String fyId) async {
    final res = await _dio.get('/accounting/fiscal-years/$fyId/comparative');
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Journals ─────────────────────────────────────────

  Future<List<dynamic>> getJournals() async {
    final res = await _dio.get('/accounting/journals');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createJournal(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/journals', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Entries ──────────────────────────────────────────

  Future<Map<String, dynamic>> getEntries({String? journalCode, String? from, String? to, String? status, int page = 1, int limit = 20}) async {
    final p = <String, dynamic>{'page': page, 'limit': limit};
    if (journalCode != null) p['journalCode'] = journalCode;
    if (from != null) p['from'] = from;
    if (to != null) p['to'] = to;
    if (status != null) p['status'] = status;
    final res = await _dio.get('/accounting/entries', queryParameters: p);
    // Backend returns a raw array; normalise to {data:[...]} so the widget can handle both formats.
    if (res.data is List) return {'data': res.data as List, 'total': (res.data as List).length};
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createEntry(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/entries', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEntry(String id) async {
    final res = await _dio.get('/accounting/entries/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEntry(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/accounting/entries/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postEntry(String id) async {
    final res = await _dio.post('/accounting/entries/$id/post');
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteEntry(String id) async {
    await _dio.delete('/accounting/entries/$id');
  }

  Future<Map<String, dynamic>> reverseEntry(String id, String date) async {
    final res = await _dio.post('/accounting/entries/$id/reverse', data: {'date': date});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> integrityCheck(String from, String to) async {
    final res = await _dio.get('/accounting/entries/integrity-check', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Ledger ───────────────────────────────────────────

  Future<Map<String, dynamic>> getLedger({String? accountCode, String? from, String? to, String? tiersId}) async {
    final p = <String, dynamic>{};
    if (accountCode != null) p['accountCode'] = accountCode;
    if (from != null) p['from'] = from;
    if (to != null) p['to'] = to;
    if (tiersId != null) p['tiersId'] = tiersId;
    final res = await _dio.get('/accounting/ledger', queryParameters: p.isEmpty ? null : p);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTiersLedger(String tiersId) async {
    final res = await _dio.get('/accounting/ledger/tiers', queryParameters: {'tiersId': tiersId});
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Balance ──────────────────────────────────────────

  Future<Map<String, dynamic>> getGeneralBalance(String fyId) async {
    final res = await _dio.get('/accounting/balance/general', queryParameters: {'fiscalYearId': fyId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAgedClientsBalance() async {
    final res = await _dio.get('/accounting/balance/aged/clients');
    return _normalizeAgedBalance(res.data);
  }

  Future<Map<String, dynamic>> getAgedSuppliersBalance() async {
    final res = await _dio.get('/accounting/balance/aged/suppliers');
    return _normalizeAgedBalance(res.data);
  }

  /// Backend returns either a {total, byBucket, lines} map or a raw List of tiers.
  static Map<String, dynamic> _normalizeAgedBalance(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is List) {
      final total = data.fold<double>(0, (s, item) {
        final m = item as Map;
        return s + ((m['totalDue'] ?? m['balance'] ?? m['total'] ?? 0) as num).toDouble();
      });
      return {'total': total, 'lines': data, 'tiers': data};
    }
    return {'total': 0, 'lines': [], 'tiers': []};
  }

  // ── Accounting : Statements ───────────────────────────────────────

  Future<Map<String, dynamic>> getBalanceSheet(String fyId) async {
    final res = await _dio.get('/accounting/statements/balance-sheet', queryParameters: {'fiscalYearId': fyId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getIncomeStatement(String fyId) async {
    final res = await _dio.get('/accounting/statements/income-statement', queryParameters: {'fiscalYearId': fyId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCashFlow(String fyId) async {
    final res = await _dio.get('/accounting/statements/cash-flow', queryParameters: {'fiscalYearId': fyId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getVatReturn(int year, int month) async {
    final res = await _dio.get('/accounting/statements/vat-return', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTafire(String fyId) async {
    final res = await _dio.get('/accounting/tafire/$fyId');
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Tax Returns ──────────────────────────────────────

  Future<Map<String, dynamic>> getTvaHistory() async {
    final res = await _dio.get('/accounting/tax-returns/tva/history');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> saveTvaReturn(int year, int month) async {
    final res = await _dio.post('/accounting/tax-returns/tva/save', data: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<void> submitTvaReturn(String id) async {
    await _dio.post('/accounting/tax-returns/tva/submit', data: {'id': id});
  }

  Future<Map<String, dynamic>> getIprReturn(int year, int month) async {
    final res = await _dio.get('/accounting/tax-returns/ipr', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAnnualTaxDashboard(String fyId) async {
    final res = await _dio.get('/accounting/tax-returns/annual/$fyId');
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Budgets ──────────────────────────────────────────

  Future<List<dynamic>> getBudgets() async {
    final res = await _dio.get('/accounting/budgets');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/budgets', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> approveBudget(String id) async => _dio.post('/accounting/budgets/$id/approve');
  Future<void> lockBudget(String id) async => _dio.post('/accounting/budgets/$id/lock');

  Future<Map<String, dynamic>> getBudgetVsActual(String id) async {
    final res = await _dio.get('/accounting/budgets/$id/vs-actual');
    return res.data as Map<String, dynamic>;
  }

  // ── Accounting : Fixed Assets ─────────────────────────────────────

  Future<List<dynamic>> getFixedAssets() async {
    final res = await _dio.get('/accounting/fixed-assets');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createFixedAsset(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/fixed-assets', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> depreciateAsset(String id, int year, int month) async {
    await _dio.post('/accounting/fixed-assets/$id/depreciate/$year/$month');
  }

  Future<void> depreciateAll(int year, int month) async {
    await _dio.post('/accounting/fixed-assets/depreciate-all/$year/$month');
  }

  Future<void> disposeAsset(String id, double salePrice, String date) async {
    await _dio.post('/accounting/fixed-assets/$id/dispose', data: {'salePrice': salePrice, 'date': date});
  }

  Future<void> writeOffAsset(String id) async => _dio.post('/accounting/fixed-assets/$id/write-off');

  // ── Accounting : Loans ────────────────────────────────────────────

  Future<List<dynamic>> getLoans() async {
    final res = await _dio.get('/accounting/loans');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/loans', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLoan(String id) async {
    final res = await _dio.get('/accounting/loans/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> payLoanSchedule(String scheduleLineId) async {
    await _dio.post('/accounting/loans/schedule/$scheduleLineId/pay');
  }

  // ── Accounting : Lettrage ─────────────────────────────────────────

  Future<List<dynamic>> getOpenLines(String accountCode) async {
    final res = await _dio.get('/accounting/lettrage/open', queryParameters: {'accountCode': accountCode});
    return res.data as List<dynamic>;
  }

  Future<void> letterLines(List<String> lineIds, String ref) async {
    await _dio.post('/accounting/lettrage/letter', data: {'lineIds': lineIds, 'reconcileRef': ref});
  }

  Future<void> unletterLines(String reconcileRef) async {
    await _dio.post('/accounting/lettrage/unletter', data: {'reconcileRef': reconcileRef});
  }

  // ── Accounting : Reminders ────────────────────────────────────────

  Future<List<dynamic>> getOverdueReminders() async {
    final res = await _dio.get('/accounting/reminders/overdue');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getReminderStats() async {
    final res = await _dio.get('/accounting/reminders/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<void> sendReminder(String invoiceId, String channel, String message) async {
    await _dio.post('/accounting/reminders/invoice/$invoiceId/send', data: {'channel': channel, 'message': message});
  }

  Future<void> processReminders() async => _dio.post('/accounting/reminders/process');

  // ── Accounting : Cost Centers & Analytics ────────────────────────

  Future<List<dynamic>> getCostCenters() async {
    final res = await _dio.get('/accounting/analytics/cost-centers');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCostCenter(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/analytics/cost-centers', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCostCenterReport(String id, String from, String to) async {
    final res = await _dio.get('/accounting/analytics/cost-centers/$id/report', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getProjects() async {
    final res = await _dio.get('/accounting/analytics/projects');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createProject(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounting/analytics/projects', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getProjectReport(String id) async {
    final res = await _dio.get('/accounting/analytics/projects/$id/report');
    return res.data as Map<String, dynamic>;
  }

  Future<void> closeProject(String id) async => _dio.post('/accounting/analytics/projects/$id/close');

  // ── Accounting : Reconciliation ───────────────────────────────────

  Future<List<dynamic>> getReconciliationBankLines(String bankAccountId) async {
    final res = await _dio.get('/accounting/reconciliation/bank-lines', queryParameters: {'bankAccountId': bankAccountId});
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<List<dynamic>> getReconciliationSuggestions(String bankAccountId) async {
    final res = await _dio.get('/accounting/reconciliation/suggestions', queryParameters: {'bankAccountId': bankAccountId});
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<void> matchReconciliation(String bankLineId, String journalEntryLineId) async {
    await _dio.post('/accounting/reconciliation/match', data: {
      'bankLineId': bankLineId,
      'journalEntryLineId': journalEntryLineId,
    });
  }

  Future<void> unmatchReconciliation(String bankLineId) async {
    await _dio.delete('/accounting/reconciliation/match/$bankLineId');
  }

  Future<Map<String, dynamic>> autoReconcile(String bankAccountId, {String? from, String? to, int minScore = 85}) async {
    final params = <String, dynamic>{'bankAccountId': bankAccountId, 'minScore': minScore};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final res = await _dio.post('/accounting/reconciliation/auto-reconcile', queryParameters: params);
    return (res.data as Map<String, dynamic>? ?? {'matched': 0, 'skipped': 0});
  }

  Future<Map<String, dynamic>> getReconciliationReport(String bankAccountId) async {
    final res = await _dio.get('/accounting/reconciliation/report', queryParameters: {'bankAccountId': bankAccountId});
    return res.data as Map<String, dynamic>;
  }

  // ── Customers (Tiers) ─────────────────────────────────────────────

  Future<List<dynamic>> getCustomers({String? type, String? search}) async {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (search != null) params['search'] = search;
    final res = await _dio.get('/customers', queryParameters: params.isEmpty ? null : params);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    final res = await _dio.post('/customers', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCustomer(String id) async {
    final res = await _dio.get('/customers/$id');
    return res.data as Map<String, dynamic>;
  }

  // ── Products ──────────────────────────────────────────────────────

  Future<List<dynamic>> getProducts({String? search}) async {
    final params = <String, dynamic>{};
    if (search != null) params['search'] = search;
    final res = await _dio.get('/products', queryParameters: params.isEmpty ? null : params);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final res = await _dio.post('/products', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Invoices ──────────────────────────────────────────────────────

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoice(String id) async {
    final res = await _dio.get('/invoices/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitInvoice(String id, {String? edefId}) async {
    final res = await _dio.post('/invoices/$id/submit', data: edefId != null ? {'edefId': edefId} : null);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmInvoice(String id) async {
    final res = await _dio.post('/invoices/$id/confirm');
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelInvoice(String id) async {
    await _dio.post('/invoices/$id/cancel');
  }

  Future<Map<String, dynamic>> getInvoicePaymentStatus(String id) async {
    final res = await _dio.get('/invoices/$id/payment-status');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addPayment(String invoiceId, Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices/$invoiceId/payments', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPayments(String invoiceId) async {
    final res = await _dio.get('/invoices/$invoiceId/payments');
    return res.data as List<dynamic>;
  }

  Future<void> deletePayment(String invoiceId, String paymentId) async {
    await _dio.delete('/invoices/$invoiceId/payments/$paymentId');
  }

  Future<Map<String, dynamic>> setPaymentSchedule(String invoiceId, List<Map<String, dynamic>> lines) async {
    final res = await _dio.post('/invoices/$invoiceId/schedule', data: {'lines': lines});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getPaymentSchedule(String invoiceId) async {
    final res = await _dio.get('/invoices/$invoiceId/schedule');
    return res.data as List<dynamic>;
  }

  // Invoice reports & dashboard
  Future<Map<String, dynamic>> getInvoiceCashCollection(String from, String to) async {
    final res = await _dio.get('/invoices/reports/cash-collection', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getOverdueInvoices() async {
    final res = await _dio.get('/invoices/reports/overdue');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getInvoiceAgedReceivable() async {
    final res = await _dio.get('/invoices/dashboard/aged-receivable');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoiceMetrics() async {
    final res = await _dio.get('/invoices/dashboard/metrics');
    return res.data as Map<String, dynamic>;
  }

  // ── Quotes (Devis) ────────────────────────────────────────────────

  Future<List<dynamic>> getQuotes({String? status}) async {
    final res = await _dio.get('/invoices/quotes', queryParameters: status != null ? {'status': status} : null);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createQuote(Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices/quotes', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getQuote(String id) async {
    final res = await _dio.get('/invoices/quotes/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getQuoteStats() async {
    final res = await _dio.get('/invoices/quotes/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<void> sendQuote(String id) async => _dio.post('/invoices/quotes/$id/send');
  Future<void> acceptQuote(String id) async => _dio.post('/invoices/quotes/$id/accept');
  Future<void> rejectQuote(String id) async => _dio.post('/invoices/quotes/$id/reject');
  Future<Map<String, dynamic>> convertQuoteToInvoice(String id) async {
    final res = await _dio.post('/invoices/quotes/$id/convert');
    return res.data as Map<String, dynamic>;
  }
  Future<Map<String, dynamic>> convertQuoteToOrder(String id) async {
    final res = await _dio.post('/invoices/quotes/$id/convert-to-order');
    return res.data as Map<String, dynamic>;
  }

  // ── Contracts (Récurrents) ────────────────────────────────────────

  Future<List<dynamic>> getContracts({String? status}) async {
    final res = await _dio.get('/invoices/contracts', queryParameters: status != null ? {'status': status} : null);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createContract(Map<String, dynamic> data) async {
    final res = await _dio.post('/invoices/contracts', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getContract(String id) async {
    final res = await _dio.get('/invoices/contracts/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<void> billContractNow(String id) async => _dio.post('/invoices/contracts/$id/bill-now');
  Future<void> pauseContract(String id) async => _dio.post('/invoices/contracts/$id/pause');
  Future<void> resumeContract(String id) async => _dio.post('/invoices/contracts/$id/resume');
  Future<void> terminateContract(String id) async => _dio.post('/invoices/contracts/$id/terminate');

  // ── Tiers Statement ───────────────────────────────────────────────

  Future<List<dynamic>> getTiers() async {
    final res = await _dio.get('/invoices/tiers');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getTiersStatement(String tiersId, String from, String to) async {
    final res = await _dio.get('/invoices/tiers/$tiersId/statement', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  // ── Mail ──────────────────────────────────────────────────────────

  Future<void> sendInvoiceMail(String invoiceId) async => _dio.post('/mail/invoice/$invoiceId');
  Future<void> sendReminderMail(String invoiceId) async => _dio.post('/mail/reminder/$invoiceId');
  Future<void> sendStatementMail(String tiersId) async => _dio.post('/mail/statement/$tiersId');

  // ── Cabinet ───────────────────────────────────────────────────────

  Future<Map<String, dynamic>> registerCabinet(Map<String, dynamic> data) async {
    final res = await _dio.post('/cabinet/register', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCabinetProfile() async {
    final res = await _dio.get('/cabinet/me');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCabinetProfile(Map<String, dynamic> data) async {
    final res = await _dio.patch('/cabinet/me', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCabinetClientDetail(String tenantId) async {
    final res = await _dio.get('/cabinet/clients/$tenantId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCabinetDashboard() async {
    final res = await _dio.get('/cabinet/dashboard');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCabinetMembers() async {
    final res = await _dio.get('/cabinet/members');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> inviteMember(Map<String, dynamic> data) async {
    final res = await _dio.post('/cabinet/members', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateMemberRole(String userId, String role) async {
    final res = await _dio.patch('/cabinet/members/$userId/role', data: {'role': role});
    return res.data as Map<String, dynamic>;
  }

  Future<void> removeMember(String userId) async {
    await _dio.delete('/cabinet/members/$userId');
  }

  Future<List<dynamic>> getCabinetClients() async {
    final res = await _dio.get('/cabinet/clients');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> addClientToCabinet(String tenantId) async {
    final res = await _dio.post('/cabinet/clients', data: {'tenantId': tenantId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assignClientAccess(String tenantId, String userId, List<String> permissions) async {
    final res = await _dio.post('/cabinet/clients/$tenantId/access', data: {'userId': userId, 'permissions': permissions});
    return res.data as Map<String, dynamic>;
  }

  Future<void> removeClientAccess(String tenantId, String userId) async {
    await _dio.delete('/cabinet/clients/$tenantId/access/$userId');
  }

  Future<Map<String, dynamic>> cabinetSwitchTenant(String tenantId) async {
    final res = await _dio.post('/cabinet/switch/$tenantId');
    return res.data as Map<String, dynamic>;
  }

  Future<void> checkCabinetAlerts() async {
    await _dio.post('/cabinet/alerts/check');
  }

  Future<Map<String, dynamic>> getAlertSettings() async {
    final res = await _dio.get('/settings/alerts');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAlertSettings(Map<String, dynamic> data) async {
    final res = await _dio.post('/settings/alerts', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Treasury : Bank ───────────────────────────────────────────────

  Future<List<dynamic>> getBankAccounts() async {
    final res = await _dio.get('/treasury/bank');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBankAccount(Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/bank', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBankAccount(String id) async {
    final res = await _dio.get('/treasury/bank/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateBankAccount(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/treasury/bank/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addBankTransaction(String bankId, Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/bank/$bankId/transactions', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getBankStatement(String bankId, String from, String to) async {
    final res = await _dio.get('/treasury/bank/$bankId/statement', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importBankStatement(String bankId, List<int> fileBytes, String fileName) async {
    final formData = {'file': fileBytes};
    final res = await _dio.post('/treasury/bank/$bankId/import', data: formData);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getImportSummary(String bankId) async {
    final res = await _dio.get('/treasury/bank/$bankId/import/summary');
    return res.data as Map<String, dynamic>;
  }

  // ── Treasury : Cash ────────────────────────────────────────────────

  Future<List<dynamic>> getCashRegisters() async {
    final res = await _dio.get('/treasury/cash');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCashRegister(Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/cash', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCashRegister(String id) async {
    final res = await _dio.get('/treasury/cash/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> openCashRegister(String id, double openingBalance) async {
    final res = await _dio.patch('/treasury/cash/$id/open', data: {'openingBalance': openingBalance});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeCashRegister(String id) async {
    final res = await _dio.patch('/treasury/cash/$id/close');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addCashTransaction(String cashId, Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/cash/$cashId/transactions', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getCashTransactions(String cashId, {String? from}) async {
    final p = from != null ? {'from': from} : null;
    final res = await _dio.get('/treasury/cash/$cashId/transactions', queryParameters: p);
    return res.data as List<dynamic>;
  }

  // ── Treasury : Mobile Money ────────────────────────────────────────

  Future<void> configureMobileMoney(String operator, Map<String, dynamic> data) async {
    await _dio.post('/treasury/mobile-money/config/$operator', data: data);
  }

  Future<Map<String, dynamic>> requestMobilePayment(Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/mobile-money/request-payment', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disburseMobileMoney(Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/mobile-money/disburse', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getMobileTransactionStatus(String ref) async {
    final res = await _dio.get('/treasury/mobile-money/transactions/$ref/status');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMobileTransactions({String? operator, String? status}) async {
    final p = <String, dynamic>{};
    if (operator != null) p['operator'] = operator;
    if (status != null) p['status'] = status;
    final res = await _dio.get('/treasury/mobile-money/transactions', queryParameters: p.isEmpty ? null : p);
    return res.data as List<dynamic>;
  }

  // ── Treasury : Currency ────────────────────────────────────────────

  Future<List<dynamic>> getCurrencyRates() async {
    final res = await _dio.get('/treasury/currencies');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCurrencyRate(Map<String, dynamic> data) async {
    final res = await _dio.post('/treasury/currencies', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getLatestRate(String from, String to) async {
    final res = await _dio.get('/treasury/currencies/latest', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertAmount(double amount, String from, String to) async {
    final res = await _dio.get('/treasury/currencies/convert', queryParameters: {'amount': amount, 'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<void> fetchBccRates() async => _dio.post('/treasury/currencies/fetch-bcc');

  Future<Map<String, dynamic>> getCurrencyExposure() async {
    final res = await _dio.get('/treasury/currencies/exposure');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> previewRevaluation(String date) async {
    final res = await _dio.get('/treasury/currencies/revaluation/preview', queryParameters: {'date': date});
    return res.data as Map<String, dynamic>;
  }

  Future<void> postRevaluation(String date, String fyId) async {
    await _dio.post('/treasury/currencies/revaluation/post', data: {'date': date, 'fiscalYearId': fyId});
  }

  // ── Treasury : Dashboard ───────────────────────────────────────────

  Future<Map<String, dynamic>> getTreasuryDashboard() async {
    final res = await _dio.get('/treasury/dashboard/summary');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getAllAccountsBalance() async {
    final res = await _dio.get('/treasury/dashboard/accounts/balance');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getCashFlowForecast({int horizon = 30}) async {
    final res = await _dio.get('/treasury/cash-flow-forecast', queryParameters: {'horizon': horizon});
    return res.data as Map<String, dynamic>;
  }

  // ── Purchases : Requisitions ──────────────────────────────────────

  Future<List<dynamic>> getRequisitions({String? status}) async {
    final res = await _dio.get('/purchases/requisitions',
        queryParameters: status != null ? {'status': status} : null);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createRequisition(Map<String, dynamic> data) async {
    final res = await _dio.post('/purchases/requisitions', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getRequisition(String id) async {
    final res = await _dio.get('/purchases/requisitions/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitRequisition(String id) async {
    final res = await _dio.post('/purchases/requisitions/$id/submit');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveRequisition(String id) async {
    final res = await _dio.post('/purchases/requisitions/$id/approve');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectRequisition(String id, String reason) async {
    final res = await _dio.post('/purchases/requisitions/$id/reject', data: {'reason': reason});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> convertRequisitionToPO(String id, String tiersId) async {
    final res = await _dio.post('/purchases/requisitions/$id/convert-to-po', data: {'tiersId': tiersId});
    return res.data as Map<String, dynamic>;
  }

  // ── Purchases : Orders (BC) ───────────────────────────────────────

  Future<List<dynamic>> getPurchaseOrders({String? status}) async {
    final res = await _dio.get('/purchases/orders',
        queryParameters: status != null ? {'status': status} : null);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> data) async {
    final res = await _dio.post('/purchases/orders', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPurchaseOrder(String id) async {
    final res = await _dio.get('/purchases/orders/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitPurchaseOrderApproval(String id) async {
    final res = await _dio.post('/purchases/orders/$id/submit-approval');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approvePurchaseOrder(String id) async {
    final res = await _dio.post('/purchases/orders/$id/approve');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmPurchaseOrder(String id) async {
    final res = await _dio.post('/purchases/orders/$id/confirm');
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelPurchaseOrder(String id) async {
    await _dio.post('/purchases/orders/$id/cancel');
  }

  Future<Map<String, dynamic>> getThreeWayMatch(String orderId) async {
    final res = await _dio.get('/purchases/orders/$orderId/three-way-match');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> linkGrToFa(String faEntryId, String goodsReceiptId) async {
    final res = await _dio.post('/purchases/$faEntryId/link-gr', data: {'goodsReceiptId': goodsReceiptId});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getSupplierBalance(String tiersId) async {
    final res = await _dio.get('/purchases/orders/supplier/$tiersId/balance');
    return res.data as Map<String, dynamic>;
  }

  // ── Purchases : Receipts (BR) ─────────────────────────────────────

  Future<List<dynamic>> getReceipts() async {
    final res = await _dio.get('/purchases/receipts');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createReceipt(Map<String, dynamic> data) async {
    final res = await _dio.post('/purchases/receipts', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getReceipt(String id) async {
    final res = await _dio.get('/purchases/receipts/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> confirmReceipt(String id) async {
    final res = await _dio.post('/purchases/receipts/$id/confirm');
    return res.data as Map<String, dynamic>;
  }

  // ── Purchases : Payments ──────────────────────────────────────────

  Future<Map<String, dynamic>> paySupplierInvoice(String journalEntryId, Map<String, dynamic> data) async {
    final res = await _dio.post('/purchases/$journalEntryId/pay', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getSupplierPayments(String journalEntryId) async {
    final res = await _dio.get('/purchases/$journalEntryId/payments');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getAgedPayables() async {
    final res = await _dio.get('/purchases/aged-payables');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createDebitNote(Map<String, dynamic> data) async {
    final res = await _dio.post('/purchases/debit-note', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Stock ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getStock() async {
    final res = await _dio.get('/stock');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getStockValuation() async {
    final res = await _dio.get('/stock/valuation');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getInventorySheet() async {
    final res = await _dio.get('/stock/inventory-sheet');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<List<dynamic>> getProductMovements(String productId, {String? from}) async {
    final p = from != null ? {'from': from} : null;
    final res = await _dio.get('/stock/products/$productId/movements', queryParameters: p);
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> postInventory(Map<String, dynamic> data) async {
    final res = await _dio.post('/stock/inventory', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> moveStock(Map<String, dynamic> data) async {
    final res = await _dio.post('/stock/move', data: data);
    return res.data as Map<String, dynamic>;
  }

  // ── Reports : Extended Dashboard ─────────────────────────────────

  Future<Map<String, dynamic>> getProfitLoss() async {
    final res = await _dio.get('/reports/dashboard/accounting/profit-loss');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDashboardAccountingBalance() async {
    final res = await _dio.get('/reports/dashboard/accounting/balance-sheet');
    return res.data as Map<String, dynamic>;
  }

  // ── Reports : DGI ────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDgiReportX(String date) async {
    final res = await _dio.get('/reports/dgi/x', queryParameters: {'date': date});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDgiReportZ(String date) async {
    final res = await _dio.get('/reports/dgi/z', queryParameters: {'date': date});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDgiReportP(int year, int month) async {
    final mm = month.toString().padLeft(2, '0');
    final lastDay = DateTime(year, month + 1, 0).day;
    final from = '$year-$mm-01';
    final to = '$year-$mm-${lastDay.toString().padLeft(2, '0')}';
    final res = await _dio.get('/reports/dgi/p', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDgiReportA(int year) async {
    final res = await _dio.get('/reports/dgi/a', queryParameters: {'year': year});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateLiasseFiscale(String fiscalYearId) async {
    final res = await _dio.post('/reports/liasse-fiscale', data: {'fiscalYearId': fiscalYearId});
    return res.data as Map<String, dynamic>;
  }

  // ── Reports : Custom ─────────────────────────────────────────────

  Future<List<dynamic>> getCustomReportTemplates() async {
    final res = await _dio.get('/custom-reports/templates');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCustomReportTemplate(Map<String, dynamic> data) async {
    final res = await _dio.post('/custom-reports/templates', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteCustomReportTemplate(String id) async {
    await _dio.delete('/custom-reports/templates/$id');
  }

  Future<Map<String, dynamic>> executeCustomReport(String id, {String? fiscalYearId, String? from, String? to}) async {
    final body = <String, dynamic>{};
    if (fiscalYearId != null) body['fiscalYearId'] = fiscalYearId;
    if (from != null) body['from'] = from;
    if (to != null) body['to'] = to;
    final res = await _dio.post('/custom-reports/templates/$id/execute', data: body);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> validateReportFormula(String formula) async {
    final res = await _dio.post('/custom-reports/validate-formula', data: {'formula': formula});
    return res.data as Map<String, dynamic>;
  }

  // ── Reports : Consolidation ───────────────────────────────────────

  Future<List<dynamic>> getConsolidationGroups() async {
    final res = await _dio.get('/consolidation/groups');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createConsolidationGroup(Map<String, dynamic> data) async {
    final res = await _dio.post('/consolidation/groups', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConsolidatedBalanceSheet(String groupId, String fiscalYearPrefix) async {
    final res = await _dio.get('/consolidation/groups/$groupId/balance-sheet', queryParameters: {'fiscalYearPrefix': fiscalYearPrefix});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getConsolidatedIncomeStatement(String groupId, String fiscalYearPrefix) async {
    final res = await _dio.get('/consolidation/groups/$groupId/income-statement', queryParameters: {'fiscalYearPrefix': fiscalYearPrefix});
    return res.data as Map<String, dynamic>;
  }

  // ── Reports : Downloads (bytes) ───────────────────────────────────

  Future<List<int>> downloadReport(String path, {Map<String, dynamic>? params}) async {
    final res = await _dio.get<List<int>>(
      path,
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data ?? [];
  }

  String buildReportUrl(String path, {Map<String, dynamic>? params}) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    if (params == null || params.isEmpty) return '$base$path';
    final q = params.entries.where((e) => e.value != null).map((e) => '${e.key}=${e.value}').join('&');
    return '$base$path?$q';
  }

  // ── Approvals : Workflows ─────────────────────────────────────────

  Future<List<dynamic>> getApprovalWorkflows({String? entityType}) async {
    final res = await _dio.get('/approvals/workflows',
        queryParameters: entityType != null ? {'entityType': entityType} : null);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createApprovalWorkflow(Map<String, dynamic> data) async {
    final res = await _dio.post('/approvals/workflows', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateApprovalWorkflow(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/approvals/workflows/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteApprovalWorkflow(String id) async {
    await _dio.delete('/approvals/workflows/$id');
  }

  // ── Approvals : Requests ──────────────────────────────────────────

  Future<Map<String, dynamic>> submitApproval(String entityType, String entityId, double amount) async {
    final res = await _dio.post('/approvals/submit', data: {
      'entityType': entityType,
      'entityId': entityId,
      'amount': amount,
    });
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMyPendingApprovals() async {
    final res = await _dio.get('/approvals/pending');
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<List<dynamic>> getAllApprovals({String? status, String? entityType}) async {
    final p = <String, dynamic>{};
    if (status != null) p['status'] = status;
    if (entityType != null) p['entityType'] = entityType;
    final res = await _dio.get('/approvals', queryParameters: p.isEmpty ? null : p);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> getApprovalRequest(String requestId) async {
    final res = await _dio.get('/approvals/$requestId');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getApprovalHistory(String requestId) async {
    final res = await _dio.get('/approvals/$requestId/history');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveRequest(String requestId, {String? comment}) async {
    final res = await _dio.post('/approvals/$requestId/approve',
        data: comment != null ? {'comment': comment} : null);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectRequest(String requestId, String comment) async {
    final res = await _dio.post('/approvals/$requestId/reject', data: {'comment': comment});
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelApprovalRequest(String requestId) async {
    await _dio.post('/approvals/$requestId/cancel');
  }

  Future<Map<String, dynamic>?> getEntityApprovalStatus(String entityId, String entityType) async {
    try {
      final res = await _dio.get('/approvals/status',
          queryParameters: {'entityId': entityId, 'entityType': entityType});
      return res.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Payroll : Employees ───────────────────────────────────────────

  Future<List<dynamic>> getEmployees({String? department, String? status}) async {
    final p = <String, dynamic>{};
    if (department != null) p['department'] = department;
    if (status != null) p['status'] = status;
    final res = await _dio.get('/payroll/employees', queryParameters: p.isEmpty ? null : p);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final res = await _dio.post('/payroll/employees', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmployee(String id) async {
    final res = await _dio.get('/payroll/employees/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployee(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/payroll/employees/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteEmployee(String id) async {
    await _dio.delete('/payroll/employees/$id');
  }

  // ── Payroll : Payslips ────────────────────────────────────────────

  Future<List<dynamic>> getPayslips({int? year, int? month, String? employeeId}) async {
    final p = <String, dynamic>{};
    if (year != null) p['year'] = year;
    if (month != null) p['month'] = month;
    if (employeeId != null) p['employeeId'] = employeeId;
    final res = await _dio.get('/payroll/payslips', queryParameters: p.isEmpty ? null : p);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> generatePayslip(String employeeId, int year, int month) async {
    final res = await _dio.post('/payroll/payslips/employee/$employeeId', data: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayslip(String id) async {
    final res = await _dio.get('/payroll/payslips/$id');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postPayslip(String id) async {
    final res = await _dio.post('/payroll/payslips/$id/post');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPayslipSummary(int year, int month) async {
    final res = await _dio.get('/payroll/payslips/summary', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> generateMonthlyPayslips(int year, int month) async {
    final res = await _dio.post('/payroll/payslips/monthly', data: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> postMonthlyPayslips(int year, int month) async {
    final res = await _dio.post('/payroll/payslips/monthly/post', data: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  // ── Payroll : Leaves ──────────────────────────────────────────────

  Future<List<dynamic>> getLeaveRequests({String? status, String? employeeId}) async {
    final p = <String, dynamic>{};
    if (status != null) p['status'] = status;
    if (employeeId != null) p['employeeId'] = employeeId;
    final res = await _dio.get('/payroll/leaves', queryParameters: p.isEmpty ? null : p);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<List<dynamic>> getLeaveBalances(String employeeId) async {
    final res = await _dio.get('/payroll/leaves/employees/$employeeId/balances');
    return res.data as List<dynamic>;
  }

  Future<void> initLeaveBalances(String employeeId, int year) async {
    await _dio.post('/payroll/leaves/employees/$employeeId/balances/init', data: {'year': year});
  }

  Future<Map<String, dynamic>> requestLeave(String employeeId, Map<String, dynamic> data) async {
    final res = await _dio.post('/payroll/leaves/employees/$employeeId/request', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approveLeave(String id) async {
    final res = await _dio.post('/payroll/leaves/$id/approve');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectLeave(String id, String reason) async {
    final res = await _dio.post('/payroll/leaves/$id/reject', data: {'reason': reason});
    return res.data as Map<String, dynamic>;
  }

  Future<void> cancelLeave(String id) async {
    await _dio.post('/payroll/leaves/$id/cancel');
  }

  // ── Payroll : Expense Claims ──────────────────────────────────────

  Future<List<dynamic>> getExpenseClaims({String? status, String? employeeId}) async {
    final p = <String, dynamic>{};
    if (status != null) p['status'] = status;
    if (employeeId != null) p['employeeId'] = employeeId;
    final res = await _dio.get('/payroll/expense-claims', queryParameters: p.isEmpty ? null : p);
    return (res.data is List ? res.data : (res.data as Map)['data'] ?? []) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createExpenseClaim(Map<String, dynamic> data) async {
    final res = await _dio.post('/payroll/expense-claims', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> submitExpenseClaim(String id) async {
    await _dio.post('/payroll/expense-claims/$id/submit');
  }

  Future<void> approveExpenseClaim(String id) async {
    await _dio.post('/payroll/expense-claims/$id/approve');
  }

  Future<void> rejectExpenseClaim(String id, String reason) async {
    await _dio.post('/payroll/expense-claims/$id/reject', data: {'reason': reason});
  }

  Future<void> payExpenseClaim(String id) async {
    await _dio.post('/payroll/expense-claims/$id/pay');
  }

  // ── Payroll : Declarations ────────────────────────────────────────

  Future<Map<String, dynamic>> getCnssDeclaration(int year, int month) async {
    final res = await _dio.get('/payroll/declarations/cnss', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOnemDeclaration(int year, int month) async {
    final res = await _dio.get('/payroll/declarations/onem', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getIprDeclaration(int year, int month) async {
    final res = await _dio.get('/payroll/declarations/ipr', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getDeclarationStatus(int year, int month) async {
    final res = await _dio.get('/payroll/declarations/status', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  Future<void> submitDeclarations(int year, int month, List<String> types) async {
    await _dio.post('/payroll/declarations/submit', data: {'year': year, 'month': month, 'types': types});
  }

  Future<Map<String, dynamic>> getMonthlyPayrollReport(int year, int month) async {
    final res = await _dio.get('/payroll/reports/monthly', queryParameters: {'year': year, 'month': month});
    return res.data as Map<String, dynamic>;
  }

  // ── e-MCF DGI ─────────────────────────────────────────────────────

  Future<void> setEmcfToken(String token) async {
    await _dio.post('/emcf/config/token', data: {'token': token});
  }

  Future<Map<String, dynamic>> getEmcfPendingCount() async {
    final res = await _dio.get('/emcf/pending-count');
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getEmcfTaxGroups() async {
    final res = await _dio.get('/emcf/info/tax-groups');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getEmcfInvoiceTypes() async {
    final res = await _dio.get('/emcf/info/invoice-types');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getEmcfPaymentTypes() async {
    final res = await _dio.get('/emcf/info/payment-types');
    return res.data as List<dynamic>;
  }

  Future<List<dynamic>> getEmcfCurrencyRates() async {
    final res = await _dio.get('/emcf/info/currency-rates');
    return res.data as List<dynamic>;
  }

  // EDEFs
  Future<List<dynamic>> getEdefs() async {
    final res = await _dio.get('/emcf/edefs');
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createEdef(Map<String, dynamic> data) async {
    final res = await _dio.post('/emcf/edefs', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEdef(String id, Map<String, dynamic> data) async {
    final res = await _dio.patch('/emcf/edefs/$id', data: data);
    return res.data as Map<String, dynamic>;
  }

  Future<void> deleteEdef(String id) async {
    await _dio.delete('/emcf/edefs/$id');
  }

  Future<Map<String, dynamic>> syncEdefsFromDgi() async {
    final res = await _dio.post('/emcf/edefs/sync-from-dgi');
    return res.data as Map<String, dynamic>;
  }

  // Queue
  Future<Map<String, dynamic>> getEmcfQueueStats() async {
    final res = await _dio.get('/emcf/queue/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<void> retryEmcfInvoice(String invoiceId) async {
    await _dio.post('/emcf/queue/retry', data: {'invoiceId': invoiceId});
  }

  Future<void> resetInvoiceToDraft(String invoiceId) async {
    await _dio.post('/emcf/queue/invoice/$invoiceId/reset-to-draft');
  }

  // Compliance
  Future<Map<String, dynamic>> getEmcfComplianceDashboard() async {
    final res = await _dio.get('/emcf/compliance/dashboard');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmcfComplianceStats() async {
    final res = await _dio.get('/emcf/compliance/stats');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getEmcfTvaReconciliation(String from, String to) async {
    final res = await _dio.get('/emcf/compliance/tva-reconciliation', queryParameters: {'from': from, 'to': to});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getEmcfErrors() async {
    final res = await _dio.get('/emcf/compliance/errors');
    return res.data as List<dynamic>;
  }

  Future<String> getEmcfComplianceExportUrl(String from, String to) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    return Future.value('$base/emcf/compliance/export-csv?from=$from&to=$to');
  }

  // ── Dashboard ─────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getGlobalDashboard() async {
    final res = await _dio.get('/reports/dashboard');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAccountingOverview() async {
    final res = await _dio.get('/reports/dashboard/accounting');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getInvoicesSummary() async {
    final res = await _dio.get('/invoices/dashboard/summary');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getTreasurySummary() async {
    final res = await _dio.get('/treasury/dashboard/summary');
    return res.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getKpiSummary(String fiscalYearId) async {
    final res = await _dio.get('/reports/kpi/summary', queryParameters: {'fiscalYearId': fiscalYearId});
    return res.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMonthlyTrend({int? year}) async {
    final res = await _dio.get('/reports/dashboard/accounting/monthly-trend',
        queryParameters: year != null ? {'year': year} : null);
    final data = res.data as Map<String, dynamic>;
    return data['months'] as List<dynamic>;
  }
}

// ── Auth Interceptor ──────────────────────────────────────────────────────────

class _AuthInterceptor extends Interceptor {
  // Serialise concurrent 401s: only one refresh runs at a time; others wait.
  // Without this, token rotation causes every concurrent retry to invalidate
  // the others' refresh tokens, then clear storage and log the user out.
  static Completer<String?>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await TokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final path = err.requestOptions.path;
    // Never refresh-retry auth endpoints — a 401 on login means wrong credentials,
    // not an expired session. Retrying would consume the refresh token for nothing.
    final isAuthEndpoint = path.contains('/auth/login') || path.contains('/auth/refresh');
    if (err.response?.statusCode == 401 && !isAuthEndpoint) {
      try {
        String? newAccess;

        if (_refreshCompleter != null) {
          // Another coroutine is already refreshing — wait for its result.
          newAccess = await _refreshCompleter!.future;
        } else {
          // We are the first: perform the refresh and broadcast the result.
          _refreshCompleter = Completer<String?>();
          try {
            final refreshToken = await TokenStorage.getRefreshToken();
            if (refreshToken != null) {
              final data = await ApiClient()._dio.post(
                '/auth/refresh',
                data: {'refreshToken': refreshToken},
                options: Options(headers: {'Authorization': ''}),
              );
              newAccess = data.data['accessToken'] as String;
              final newRefresh = data.data['refreshToken'] as String;
              await TokenStorage.saveTokens(accessToken: newAccess, refreshToken: newRefresh);
              _refreshCompleter!.complete(newAccess);
            } else {
              _refreshCompleter!.complete(null);
            }
          } catch (_) {
            await TokenStorage.clearAll();
            _refreshCompleter!.complete(null);
            // Refresh token expired or invalid — trigger automatic logout.
            ApiClient.onSessionExpired?.call();
          } finally {
            _refreshCompleter = null;
          }
        }

        if (newAccess != null) {
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccess';
          try {
            final retried = await ApiClient()._dio.fetch(err.requestOptions);
            return handler.resolve(retried);
          } on DioException catch (retryErr) {
            // Auth succeeded but the retried request failed (e.g. 500).
            // Propagate the retry error so the real problem is visible, not "Unauthorized".
            handler.next(retryErr);
            return;
          }
        }
      } catch (_) {
        // Refresh itself failed — fall through to propagate the original 401.
      }
    }
    handler.next(err);
  }
}

// ── Error Interceptor ─────────────────────────────────────────────────────────

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final message = _extractMessage(err);
    handler.next(DioException(
      requestOptions: err.requestOptions,
      response: err.response,
      type: err.type,
      error: message,
    ));
  }

  String _extractMessage(DioException err) {
    if (err.response?.data is Map) {
      final data = err.response!.data as Map;
      return data['message']?.toString() ?? data['error']?.toString() ?? 'Erreur serveur';
    }
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connexion trop lente. Vérifiez votre réseau.';
      case DioExceptionType.connectionError:
        return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
      default:
        return err.message ?? 'Erreur inconnue';
    }
  }
}
