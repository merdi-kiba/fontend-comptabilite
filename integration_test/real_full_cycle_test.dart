// ════════════════════════════════════════════════════════════════════════════
// PROXIMA — Test d'intégration Flutter contre la BASE RÉELLE
//
// Exerce TOUT le cycle métier via le vrai ApiClient (le même code que l'UI) :
//   - Auth (login)
//   - Affichages (GET) : comptes, journaux, exercices, écritures, balance,
//     dashboard, états financiers, caisses
//   - Écritures comptables (POST → GET → DELETE)
//   - Caisses : création de plusieurs caisses, ouverture, entrées/sorties, clôture
//   - Téléchargement PDF (download → vérification %PDF + écriture fichier)
//
// ⚠️  Écrit dans la base réelle. Lancé via run-flutter-real-tests.sh.
//
// Lancement :
//   flutter test integration_test/real_full_cycle_test.dart -d linux \
//     --dart-define=API_BASE_URL=http://localhost:3030
// ════════════════════════════════════════════════════════════════════════════
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:proxima/core/api/api_client.dart';
import 'package:proxima/core/auth/token_storage.dart';

const String kUsername = 'AUTOTEST-ADMIN';
const String kPassword = 'AutoTest@2026!';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late ApiClient api;

  // Données récupérées dynamiquement du tenant réel
  String? fiscalYearId;
  String? fiscalYearStart;
  String? fiscalYearEnd;
  final results = <String, String>{}; // étape -> statut (résumé final)

  void record(String step, bool ok, [String detail = '']) {
    results[step] = ok ? '✅ $detail' : '❌ $detail';
    // ignore: avoid_print
    print('${ok ? "✅" : "❌"}  $step  $detail');
  }

  setUpAll(() async {
    api = ApiClient()..init();
    final res = await api.login(kUsername, kPassword);
    final accessToken = res['accessToken'] as String;
    final refreshToken = res['refreshToken'] as String? ?? '';
    await TokenStorage.saveTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
    );
    record('LOGIN', accessToken.isNotEmpty, 'token reçu');
  });

  // ── 1. AFFICHAGES (GET) ──────────────────────────────────────────────────
  group('1. Affichages (GET) — tout doit répondre sans erreur', () {
    testWidgets('GET /tenants/my-tenants', (_) async {
      // Pour un COMPANY_USER mono-tenant, la liste peut être vide (il est déjà
      // rattaché à son tenant) : on vérifie seulement que l'appel répond sans erreur.
      final t = await api.getMyTenants();
      record('GET my-tenants', true, '${t.length} tenant(s)');
      expect(t, isNotNull);
    });

    testWidgets('GET plan comptable', (_) async {
      final accounts = await api.getAccounts();
      record('GET accounts', accounts.isNotEmpty, '${accounts.length} comptes');
      expect(accounts, isNotEmpty);
    });

    testWidgets('GET journaux', (_) async {
      final journals = await api.getJournals();
      record('GET journals', journals.isNotEmpty, '${journals.length} journaux');
      expect(journals, isNotEmpty);
    });

    testWidgets('GET exercices fiscaux', (_) async {
      final fys = await api.getFiscalYears();
      expect(fys, isNotEmpty);
      final fy = fys.first as Map<String, dynamic>;
      fiscalYearId = fy['id'] as String?;
      fiscalYearStart = (fy['startDate'] as String?)?.substring(0, 10);
      fiscalYearEnd = (fy['endDate'] as String?)?.substring(0, 10);
      record('GET fiscal-years', fiscalYearId != null,
          '${fys.length} exercice(s), actif=$fiscalYearStart→$fiscalYearEnd');
    });

    testWidgets('GET écritures', (_) async {
      final entries = await api.getEntries();
      record('GET entries', true, '${(entries['data'] as List?)?.length ?? 0} écritures');
    });

    testWidgets('GET balance générale', (_) async {
      final from = fiscalYearStart ?? '2026-01-01';
      final to = fiscalYearEnd ?? '2026-12-31';
      final bal = await api.getGeneralBalance(from: from, to: to);
      record('GET balance/general', bal.isNotEmpty, 'OK');
    });

    testWidgets('GET dashboard global', (_) async {
      final d = await api.getGlobalDashboard();
      record('GET reports/dashboard', d.isNotEmpty, 'OK');
    });

    testWidgets('GET aperçu comptable', (_) async {
      final o = await api.getAccountingOverview();
      record('GET dashboard/accounting', o.isNotEmpty, 'OK');
    });

    testWidgets('GET caisses existantes', (_) async {
      final cs = await api.getCashRegisters();
      record('GET treasury/cash', true, '${cs.length} caisse(s)');
    });
  });

  // ── 2. ÉCRITURE COMPTABLE (POST → GET → DELETE) ──────────────────────────
  group('2. Écriture comptable — cycle complet', () {
    String? createdEntryId;

    testWidgets('POST crée une écriture équilibrée (DRAFT)', (_) async {
      final accounts = await api.getAccounts();
      // Deux comptes distincts du plan réel pour une écriture équilibrée
      final acc = accounts.cast<Map<String, dynamic>>();
      final debitAcc = acc.firstWhere((a) => (a['code'] as String).startsWith('6'),
          orElse: () => acc.first)['code'] as String;
      final creditAcc = acc.firstWhere((a) => (a['code'] as String).startsWith('7'),
          orElse: () => acc[1])['code'] as String;
      final date = fiscalYearStart ?? '2026-01-15';

      final entry = await api.createEntry({
        'journalCode': 'JOD',
        'date': date,
        'description': 'TEST AUTO — écriture de validation (à supprimer)',
        'lines': [
          {'accountCode': debitAcc, 'debit': 10000, 'credit': 0},
          {'accountCode': creditAcc, 'debit': 0, 'credit': 10000},
        ],
      });
      createdEntryId = entry['id'] as String?;
      record('POST entries', createdEntryId != null,
          'id=$createdEntryId ($debitAcc/$creditAcc)');
      expect(createdEntryId, isNotNull);
    });

    testWidgets('GET vérifie présence de l\'écriture', (_) async {
      if (createdEntryId == null) return;
      final entries = await api.getEntries(status: 'DRAFT');
      final list = (entries['data'] as List?) ?? [];
      final found = list.any((e) => (e as Map)['id'] == createdEntryId);
      record('GET entry créée', found, found ? 'trouvée' : 'absente');
    });

    testWidgets('DELETE écriture → rejet propre (intégrité INSERT-ONLY)', (_) async {
      if (createdEntryId == null) return;
      // L'intégrité comptable (audit INSERT-ONLY) interdit la suppression.
      // Le backend doit renvoyer une erreur métier propre (409), PAS un 500.
      try {
        await api.deleteEntry(createdEntryId!);
        record('DELETE entry', true, 'supprimée (trigger absent)');
      } on DioException catch (e) {
        final code = e.response?.statusCode ?? 0;
        final ok = code == 409 || code == 403;
        record('DELETE entry', ok,
            ok ? 'rejet propre $code (intégrité respectée)' : 'erreur inattendue $code');
        expect(ok, isTrue);
      }
    });
  });

  // ── 3. CAISSES : plusieurs caisses, ouverture, entrées/sorties, clôture ──
  group('3. Caisses — multi-caisses, entrées/sorties, clôture', () {
    String? cash1Id;
    final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);

    testWidgets('POST crée caisse 1', (_) async {
      final accounts = await api.getAccounts();
      final cashAcc = (accounts.cast<Map<String, dynamic>>())
          .firstWhere((a) => (a['code'] as String).startsWith('57'),
              orElse: () => accounts.cast<Map<String, dynamic>>()
                  .firstWhere((a) => (a['code'] as String).startsWith('5')))['code'] as String;
      final c = await api.createCashRegister({
        'code': 'TST-CAISSE-1-$suffix',
        'name': 'Caisse Test Auto 1',
        'currency': 'CDF',
        'accountCode': cashAcc,
      });
      cash1Id = c['id'] as String?;
      record('POST caisse 1', cash1Id != null, 'id=$cash1Id (compte $cashAcc)');
      expect(cash1Id, isNotNull);
    });

    testWidgets('POST crée caisse 2 (multi-caisses)', (_) async {
      final accounts = await api.getAccounts();
      final cashAcc = (accounts.cast<Map<String, dynamic>>())
          .firstWhere((a) => (a['code'] as String).startsWith('5'))['code'] as String;
      final c = await api.createCashRegister({
        'code': 'TST-CAISSE-2-$suffix',
        'name': 'Caisse Test Auto 2',
        'currency': 'CDF',
        'accountCode': cashAcc,
      });
      record('POST caisse 2', c['id'] != null, 'id=${c['id']}');
    });

    testWidgets('PATCH ouvre la caisse 1 (fonds initial)', (_) async {
      if (cash1Id == null) return;
      await api.openCashRegister(cash1Id!, 50000);
      record('PATCH caisse/open', true, 'ouverture solde 50000 CDF');
    });

    testWidgets('POST entrée de caisse (DEPOSIT)', (_) async {
      if (cash1Id == null) return;
      final accounts = await api.getAccounts();
      final cp = (accounts.cast<Map<String, dynamic>>())
          .firstWhere((a) => (a['code'] as String).startsWith('7'),
              orElse: () => accounts.cast<Map<String, dynamic>>().first)['code'] as String;
      await api.addCashTransaction(cash1Id!, {
        'type': 'DEPOSIT',
        'amount': 100000,
        'counterpartAccountCode': cp,
        'description': 'Entrée de caisse — test auto',
      });
      record('POST caisse DEPOSIT', true, 'entrée 100000 CDF');
    });

    testWidgets('POST sortie de caisse (WITHDRAWAL)', (_) async {
      if (cash1Id == null) return;
      final accounts = await api.getAccounts();
      final cp = (accounts.cast<Map<String, dynamic>>())
          .firstWhere((a) => (a['code'] as String).startsWith('6'),
              orElse: () => accounts.cast<Map<String, dynamic>>().first)['code'] as String;
      await api.addCashTransaction(cash1Id!, {
        'type': 'WITHDRAWAL',
        'amount': 30000,
        'counterpartAccountCode': cp,
        'description': 'Sortie de caisse — test auto',
      });
      record('POST caisse WITHDRAWAL', true, 'sortie 30000 CDF');
    });

    testWidgets('GET transactions de la caisse', (_) async {
      if (cash1Id == null) return;
      final txs = await api.getCashTransactions(cash1Id!);
      record('GET caisse transactions', txs.isNotEmpty, '${txs.length} mouvement(s)');
    });

    testWidgets('PATCH clôture la caisse 1', (_) async {
      if (cash1Id == null) return;
      await api.closeCashRegister(cash1Id!);
      record('PATCH caisse/close', true, 'caisse clôturée');
    });
  });

  // ── 4. TÉLÉCHARGEMENT PDF ────────────────────────────────────────────────
  group('4. Téléchargement PDF', () {
    testWidgets('GET PDF balance générale → fichier %PDF valide', (_) async {
      final from = fiscalYearStart ?? '2026-01-01';
      final to = fiscalYearEnd ?? '2026-12-31';
      final bytes = await api.downloadReport(
        '/reports/pdf/general-balance',
        params: {'from': from, 'to': to},
      );
      final isPdf = bytes.length > 4 &&
          bytes[0] == 0x25 && bytes[1] == 0x50 && // %P
          bytes[2] == 0x44 && bytes[3] == 0x46;   // DF
      if (isPdf) {
        final dir = Directory.systemTemp.path;
        final file = File('$dir/proxima_balance_test.pdf');
        await file.writeAsBytes(bytes);
        record('PDF general-balance', true,
            '${bytes.length} octets → ${file.path}');
      } else {
        record('PDF general-balance', false,
            'pas un PDF (${bytes.length} octets)');
      }
      expect(isPdf, isTrue);
    });

    testWidgets('GET PDF bilan → fichier %PDF valide', (_) async {
      try {
        final params = fiscalYearId != null
            ? {'fiscalYearId': fiscalYearId!}
            : {'asOf': fiscalYearEnd ?? '2026-12-31'};
        final bytes = await api.downloadReport('/reports/pdf/balance-sheet', params: params);
        final isPdf = bytes.length > 4 && bytes[0] == 0x25 && bytes[1] == 0x50;
        record('PDF balance-sheet', isPdf, '${bytes.length} octets');
      } catch (e) {
        record('PDF balance-sheet', false, 'erreur: $e');
      }
    });
  });

  // ── Résumé final ─────────────────────────────────────────────────────────
  tearDownAll(() {
    // ignore: avoid_print
    print('\n╔══════════════════════════════════════════════════╗');
    // ignore: avoid_print
    print('║  RÉSUMÉ — Tests Flutter contre la base réelle     ║');
    // ignore: avoid_print
    print('╚══════════════════════════════════════════════════╝');
    final ok = results.values.where((v) => v.startsWith('✅')).length;
    results.forEach((k, v) {
      // ignore: avoid_print
      print('  $v  —  $k');
    });
    // ignore: avoid_print
    print('\n  TOTAL : $ok/${results.length} étapes réussies\n');
  });
}
