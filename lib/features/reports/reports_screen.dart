import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/reports/tabs/dashboard_tab.dart';
import 'package:proxima/features/reports/tabs/statements_tab.dart';
import 'package:proxima/features/reports/tabs/aged_balances_tab.dart';
import 'package:proxima/features/reports/tabs/exports_tab.dart';
import 'package:proxima/features/reports/tabs/custom_reports_tab.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabDefs = [
    (icon: Icons.dashboard_outlined,           label: 'Tableau de bord'),
    (icon: Icons.account_balance_outlined,     label: 'États financiers'),
    (icon: Icons.hourglass_empty_outlined,     label: 'Balances âgées'),
    (icon: Icons.download_outlined,            label: 'Exports'),
    (icon: Icons.analytics_outlined,           label: 'Rapports perso'),
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
        title: const Text('Rapports & États financiers', style: TextStyle(fontWeight: FontWeight.w700)),
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
          DashboardTab(),
          StatementsTab(),
          AgedBalancesTab(),
          ExportsTab(),
          CustomReportsTab(),
        ],
      ),
    );
  }
}
