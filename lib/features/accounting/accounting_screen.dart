import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/accounting/tabs/accounting_dashboard_tab.dart';
import 'package:proxima/features/accounting/tabs/chart_of_accounts_tab.dart';
import 'package:proxima/features/accounting/tabs/entries_tab.dart';
import 'package:proxima/features/accounting/tabs/fiscal_years_tab.dart';
import 'package:proxima/features/accounting/tabs/ledger_balance_tab.dart';
import 'package:proxima/features/accounting/tabs/statements_tab.dart';
import 'package:proxima/features/accounting/screens/fixed_assets_screen.dart';
import 'package:proxima/features/accounting/screens/budgets_screen.dart';
import 'package:proxima/features/accounting/screens/loans_screen.dart';
import 'package:proxima/features/accounting/screens/analytics_screen.dart';

class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Tableau de bord'),
                    Tab(icon: Icon(Icons.edit_note_outlined, size: 18), text: 'Écritures'),
                    Tab(icon: Icon(Icons.account_tree_outlined, size: 18), text: 'Plan comptable'),
                    Tab(icon: Icon(Icons.menu_book_outlined, size: 18), text: 'Grand livre'),
                    Tab(icon: Icon(Icons.bar_chart_outlined, size: 18), text: 'États financiers'),
                    Tab(icon: Icon(Icons.calendar_month_outlined, size: 18), text: 'Exercices'),
                  ],
                ),
                // Raccourcis modules secondaires
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      _ShortcutBtn('Immobilisations', Icons.factory_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FixedAssetsScreen()))),
                      const SizedBox(width: 8),
                      _ShortcutBtn('Budgets', Icons.account_balance_wallet_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BudgetsScreen()))),
                      const SizedBox(width: 8),
                      _ShortcutBtn('Emprunts', Icons.request_quote_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoansScreen()))),
                      const SizedBox(width: 8),
                      _ShortcutBtn('Analytique', Icons.analytics_outlined, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AccountingDashboardTab(),
                EntriesTab(),
                ChartOfAccountsTab(),
                LedgerBalanceTab(),
                StatementsTab(),
                FiscalYearsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShortcutBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _ShortcutBtn(this.label, this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        visualDensity: VisualDensity.compact,
        side: const BorderSide(color: Color(0xFFDDE1E7)),
      ),
    );
  }
}
