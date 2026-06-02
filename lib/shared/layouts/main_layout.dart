import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/core/router/app_router.dart';
import 'package:proxima/core/theme/app_theme.dart';

class MainLayout extends ConsumerWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return isDesktop
        ? _DesktopLayout(child: child)
        : _MobileLayout(child: child);
  }
}

// ── DESKTOP : Sidebar + contenu ────────────────────────────────────────────────

class _DesktopLayout extends ConsumerWidget {
  final Widget child;
  const _DesktopLayout({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Row(
        children: [
          const _Sidebar(),
          Expanded(
            child: Column(
              children: [
                const _TopBar(),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── MOBILE : Bottom navigation ─────────────────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  final Widget child;
  const _MobileLayout({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROXIMA'),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),
      drawer: const _SidebarDrawer(),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex(location),
        onDestinationSelected: (i) => _navigate(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Factures'),
          NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance), label: 'Compta'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), selectedIcon: Icon(Icons.savings), label: 'Tréso'),
        ],
      ),
    );
  }

  int _bottomIndex(String location) {
    if (location.startsWith(AppRoutes.invoices)) return 1;
    if (location.startsWith(AppRoutes.accounting)) return 2;
    if (location.startsWith(AppRoutes.treasury)) return 3;
    return 0;
  }

  void _navigate(BuildContext context, int index) {
    switch (index) {
      case 0: context.go(AppRoutes.dashboard);
      case 1: context.go(AppRoutes.invoices);
      case 2: context.go(AppRoutes.accounting);
      case 3: context.go(AppRoutes.treasury);
    }
  }
}

// ── SIDEBAR ────────────────────────────────────────────────────────────────────

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      color: AppColors.sidebarBg,
      child: const _SidebarContent(),
    );
  }
}

class _SidebarDrawer extends StatelessWidget {
  const _SidebarDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.sidebarBg,
      child: const _SidebarContent(),
    );
  }
}

class _SidebarContent extends ConsumerWidget {
  const _SidebarContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return Column(
      children: [
        // Logo
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_graph, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'PROXIMA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),

        // Tenant actif
        if (auth.tenantName != null)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.business_outlined, color: AppColors.sidebarText, size: 14),
                      const SizedBox(width: 6),
                      const Text('DOSSIER ACTIF', style: TextStyle(color: Color(0xFF546E7A), fontSize: 10, letterSpacing: 0.8)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: Text(
                    auth.tenantName!,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => context.go(AppRoutes.tenantSelect),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.swap_horiz, color: AppColors.primary, size: 14),
                        SizedBox(width: 6),
                        Text('Changer de dossier', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text('PRINCIPAL', style: TextStyle(color: Color(0xFF546E7A), fontSize: 11, letterSpacing: 1.2)),
        ),

        _NavItem(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Tableau de bord', route: AppRoutes.dashboard, currentLocation: location),
        _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Factures', route: AppRoutes.invoices, currentLocation: location),
        _NavItem(icon: Icons.account_balance_outlined, activeIcon: Icons.account_balance, label: 'Comptabilité', route: AppRoutes.accounting, currentLocation: location),
        _NavItem(icon: Icons.savings_outlined, activeIcon: Icons.savings, label: 'Trésorerie', route: AppRoutes.treasury, currentLocation: location),
        _NavItem(icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Achats & Stocks', route: AppRoutes.purchases, currentLocation: location),
        _NavItem(icon: Icons.pending_actions_outlined, activeIcon: Icons.pending_actions, label: 'Approbations', route: AppRoutes.approvals, currentLocation: location),

        // e-MCF DGI — visible pour ADMIN, SUPERADMIN, CABINET_OWNER
        if (_hasEmcfAccess(auth.role)) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('FISCALITÉ', style: TextStyle(color: Color(0xFF546E7A), fontSize: 11, letterSpacing: 1.2)),
          ),
          _NavItem(icon: Icons.verified_user_outlined, activeIcon: Icons.verified_user, label: 'e-MCF DGI', route: AppRoutes.emcf, currentLocation: location),
        ],

        // Cabinet — visible uniquement pour CABINET_OWNER, CABINET_MANAGER, SUPERADMIN
        if (_isCabinetRole(auth.role)) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text('CABINET', style: TextStyle(color: Color(0xFF546E7A), fontSize: 11, letterSpacing: 1.2)),
          ),
          _NavItem(icon: Icons.domain_outlined, activeIcon: Icons.domain, label: 'Mon Cabinet', route: AppRoutes.cabinet, currentLocation: location),
        ],

        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text('RH & PAIE', style: TextStyle(color: Color(0xFF546E7A), fontSize: 11, letterSpacing: 1.2)),
        ),

        _NavItem(icon: Icons.people_outline, activeIcon: Icons.people, label: 'Paie & RH', route: AppRoutes.payroll, currentLocation: location),

        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: Text('ANALYSE', style: TextStyle(color: Color(0xFF546E7A), fontSize: 11, letterSpacing: 1.2)),
        ),

        _NavItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Rapports', route: AppRoutes.reports, currentLocation: location),

        const Spacer(),

        const Divider(color: Color(0xFF263238), height: 1),
        _NavItem(icon: Icons.settings_outlined, activeIcon: Icons.settings, label: 'Paramètres', route: AppRoutes.settings, currentLocation: location),

        // Utilisateur connecté
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  (auth.email?.substring(0, 1) ?? 'U').toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auth.email ?? '', style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis),
                    Text(auth.role ?? '', style: const TextStyle(color: AppColors.sidebarText, fontSize: 10)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.sidebarText, size: 18),
                onPressed: () => ref.read(authProvider.notifier).logout(),
                tooltip: 'Déconnexion',
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isCabinetRole(String? role) {
    const cabinetRoles = {'SUPERADMIN', 'CABINET_OWNER', 'CABINET_MANAGER', 'CABINET_COMPTABLE', 'CABINET_AUDITEUR'};
    return cabinetRoles.contains(role);
  }

  bool _hasEmcfAccess(String? role) {
    const emcfRoles = {'SUPERADMIN', 'ADMIN', 'CABINET_OWNER', 'CABINET_MANAGER', 'CABINET_COMPTABLE'};
    return emcfRoles.contains(role);
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final String currentLocation;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.currentLocation,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentLocation.startsWith(route);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? AppColors.sidebarActive.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isActive ? Border.all(color: AppColors.sidebarActive.withValues(alpha: 0.4)) : null,
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          isActive ? activeIcon : icon,
          color: isActive ? Colors.white : AppColors.sidebarText,
          size: 20,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.sidebarText,
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => context.go(route),
      ),
    );
  }
}

// ── TOP BAR (Desktop) ──────────────────────────────────────────────────────────

class _TopBar extends ConsumerWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(
        children: [
          Text(
            _pageTitle(location),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1A1D23)),
          ),
          const Spacer(),
          // Bouton notifications
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
          // Avatar utilisateur
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary,
            child: Text(
              (auth.email?.substring(0, 1) ?? 'U').toUpperCase(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  String _pageTitle(String location) {
    if (location.startsWith(AppRoutes.invoices)) return 'Factures';
    if (location.startsWith(AppRoutes.accounting)) return 'Comptabilité';
    if (location.startsWith(AppRoutes.treasury)) return 'Trésorerie';
    if (location.startsWith(AppRoutes.purchases)) return 'Achats & Stocks';
    if (location.startsWith(AppRoutes.approvals)) return 'Approbations';
    if (location.startsWith(AppRoutes.payroll)) return 'Paie & RH';
    if (location.startsWith(AppRoutes.reports)) return 'Rapports';

    if (location.startsWith(AppRoutes.reports)) return 'Rapports';
    if (location.startsWith(AppRoutes.settings)) return 'Paramètres';
    return 'Tableau de bord';
  }
}
