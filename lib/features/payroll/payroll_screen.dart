import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/payroll/tabs/employees_tab.dart';
import 'package:proxima/features/payroll/tabs/payslips_tab.dart';
import 'package:proxima/features/payroll/tabs/leaves_tab.dart';
import 'package:proxima/features/payroll/tabs/expense_claims_tab.dart';
import 'package:proxima/features/payroll/tabs/declarations_tab.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabDefs = [
    (icon: Icons.people_outlined,            label: 'Employés'),
    (icon: Icons.receipt_long_outlined,      label: 'Fiches de paie'),
    (icon: Icons.beach_access_outlined,      label: 'Congés'),
    (icon: Icons.attach_money_outlined,      label: 'Notes de frais'),
    (icon: Icons.assignment_turned_in_outlined, label: 'Déclarations'),
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
        title: const Text('Paie & RH', style: TextStyle(fontWeight: FontWeight.w700)),
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
          EmployeesTab(),
          PayslipsTab(),
          LeavesTab(),
          ExpenseClaimsTab(),
          DeclarationsTab(),
        ],
      ),
    );
  }
}
