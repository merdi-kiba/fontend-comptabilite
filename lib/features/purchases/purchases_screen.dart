import 'package:flutter/material.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/purchases/tabs/requisitions_tab.dart';
import 'package:proxima/features/purchases/tabs/purchase_orders_tab.dart';
import 'package:proxima/features/purchases/tabs/receipts_tab.dart';
import 'package:proxima/features/purchases/tabs/aged_payables_tab.dart';
import 'package:proxima/features/purchases/tabs/stock_tab.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _tabDefs = [
    (icon: Icons.assignment_outlined,       label: 'Réquisitions'),
    (icon: Icons.shopping_cart_outlined,    label: 'Bons de commande'),
    (icon: Icons.local_shipping_outlined,   label: 'Réceptions'),
    (icon: Icons.payments_outlined,         label: 'Fournisseurs'),
    (icon: Icons.inventory_2_outlined,      label: 'Stock'),
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
        title: const Text('Achats & Stocks', style: TextStyle(fontWeight: FontWeight.w700)),
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
          RequisitionsTab(),
          PurchaseOrdersTab(),
          ReceiptsTab(),
          AgedPayablesTab(),
          StockTab(),
        ],
      ),
    );
  }
}
