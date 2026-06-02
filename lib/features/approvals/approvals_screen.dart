import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/approvals/tabs/pending_tab.dart';
import 'package:proxima/features/approvals/tabs/all_requests_tab.dart';
import 'package:proxima/features/approvals/tabs/workflows_tab.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabDefs = [
    (icon: Icons.pending_actions_outlined,  label: 'En attente'),
    (icon: Icons.history_outlined,          label: 'Toutes les demandes'),
    (icon: Icons.account_tree_outlined,     label: 'Workflows'),
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
        title: const Text('Approbations', style: TextStyle(fontWeight: FontWeight.w700)),
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
          PendingTab(),
          AllRequestsTab(),
          WorkflowsTab(),
        ],
      ),
    );
  }
}
