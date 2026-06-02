import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/theme/app_theme.dart';
import 'package:proxima/features/cabinet/tabs/cabinet_dashboard_tab.dart';
import 'package:proxima/features/cabinet/tabs/cabinet_members_tab.dart';
import 'package:proxima/features/cabinet/tabs/cabinet_clients_tab.dart';
import 'package:proxima/features/cabinet/tabs/cabinet_alerts_tab.dart';
import 'package:proxima/features/cabinet/tabs/cabinet_profile_tab.dart';

class CabinetScreen extends ConsumerWidget {
  const CabinetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final isOwner = auth.role == 'CABINET_OWNER' || auth.role == 'SUPERADMIN';

    // Nombre d'onglets : 3 pour tous, +2 pour OWNER/SUPERADMIN
    final tabCount = isOwner ? 5 : 2;

    return DefaultTabController(
      length: tabCount,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              tabs: [
                const Tab(icon: Icon(Icons.dashboard_outlined, size: 18), text: 'Vue d\'ensemble'),
                const Tab(icon: Icon(Icons.business_outlined, size: 18), text: 'Clients'),
                if (isOwner) const Tab(icon: Icon(Icons.people_outline, size: 18), text: 'Membres'),
                if (isOwner) const Tab(icon: Icon(Icons.notifications_outlined, size: 18), text: 'Alertes'),
                if (isOwner) const Tab(icon: Icon(Icons.domain_outlined, size: 18), text: 'Profil'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                const CabinetDashboardTab(),
                const CabinetClientsTab(),
                if (isOwner) const CabinetMembersTab(),
                if (isOwner) const CabinetAlertsTab(),
                if (isOwner) const CabinetProfileTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
