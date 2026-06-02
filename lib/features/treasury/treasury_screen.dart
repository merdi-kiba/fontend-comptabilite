import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/treasury/tabs/treasury_dashboard_tab.dart';
import 'package:proxima/features/treasury/tabs/bank_accounts_tab.dart';
import 'package:proxima/features/treasury/tabs/cash_registers_tab.dart';
import 'package:proxima/features/treasury/tabs/reconciliation_tab.dart';
import 'package:proxima/features/treasury/tabs/mobile_money_tab.dart';
import 'package:proxima/features/treasury/tabs/currencies_tab.dart';

class TreasuryScreen extends StatefulWidget {
  const TreasuryScreen({super.key});

  @override
  State<TreasuryScreen> createState() => _TreasuryScreenState();
}

class _TreasuryScreenState extends State<TreasuryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabDefs = [
    (icon: Icons.dashboard_outlined,        label: 'Tableau de bord'),
    (icon: Icons.account_balance_outlined,  label: 'Banques'),
    (icon: Icons.account_balance_wallet_outlined, label: 'Caisses'),
    (icon: Icons.compare_arrows_outlined,   label: 'Rapprochement'),
    (icon: Icons.phone_android_outlined,    label: 'Mobile Money'),
    (icon: Icons.currency_exchange_outlined, label: 'Devises'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabDefs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trésorerie', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.surfaceDark,
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabDefs.map((t) => Tab(icon: Icon(t.icon, size: 16), text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          TreasuryDashboardTab(),
          BankAccountsTab(),
          CashRegistersTab(),
          ReconciliationTab(),
          MobileMoneyTab(),
          CurrenciesTab(),
        ],
      ),
    );
  }
}
