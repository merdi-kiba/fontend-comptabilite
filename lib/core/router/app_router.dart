import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proxima/core/auth/auth_provider.dart';
import 'package:proxima/features/auth/login/login_screen.dart';
import 'package:proxima/features/auth/mfa/mfa_screen.dart';
import 'package:proxima/features/auth/password/forgot_password_screen.dart';
import 'package:proxima/features/auth/password/reset_password_screen.dart';
import 'package:proxima/features/auth/tenant_select/tenant_select_screen.dart';
import 'package:proxima/features/dashboard/dashboard_screen.dart';
import 'package:proxima/features/accounting/accounting_screen.dart';
import 'package:proxima/features/cabinet/cabinet_screen.dart';
import 'package:proxima/features/emcf/emcf_screen.dart';
import 'package:proxima/features/invoices/invoices_screen.dart';
import 'package:proxima/features/settings/settings_screen.dart';
import 'package:proxima/features/approvals/approvals_screen.dart';
import 'package:proxima/features/reports/reports_screen.dart';
import 'package:proxima/features/payroll/payroll_screen.dart';
import 'package:proxima/features/purchases/purchases_screen.dart';
import 'package:proxima/features/treasury/treasury_screen.dart';
import 'package:proxima/shared/layouts/main_layout.dart';

/// Écran de chargement affiché pendant la restauration de session (AuthStatus.unknown).
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const mfa = '/mfa';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const tenantSelect = '/tenant-select';
  static const dashboard = '/dashboard';
  static const invoices = '/invoices';
  static const accounting = '/accounting';
  static const treasury = '/treasury';
  static const purchases = '/purchases';
  static const approvals = '/approvals';
  static const payroll = '/payroll';
  static const reports = '/reports';
  static const cabinet = '/cabinet';
  static const emcf = '/emcf';
  static const settings = '/settings';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.dashboard,
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final hasTenant = authState.hasTenant;
      final isLoginRoute = state.matchedLocation == AppRoutes.login;
      final isTenantRoute = state.matchedLocation == AppRoutes.tenantSelect;

      final isMfaRoute = state.matchedLocation == AppRoutes.mfa;
      final isPasswordRoute = state.matchedLocation == AppRoutes.forgotPassword ||
          state.matchedLocation == AppRoutes.resetPassword;

      // Pendant la restauration de session, afficher l'écran de chargement
      if (authState.status == AuthStatus.unknown) return AppRoutes.splash;
      // MFA en attente → autoriser seulement /mfa
      if (authState.isMfaPending) return isMfaRoute ? null : AppRoutes.mfa;
      // Non authentifié → autoriser login, forgot, reset
      if (!isAuth) return (isLoginRoute || isPasswordRoute) ? null : AppRoutes.login;
      if (isAuth && !hasTenant) return isTenantRoute ? null : AppRoutes.tenantSelect;
      if (isLoginRoute || isTenantRoute || isMfaRoute) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (context, _) => const _SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (context, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.mfa, builder: (context, _) => const MfaScreen()),
      GoRoute(path: AppRoutes.forgotPassword, builder: (context, _) => const ForgotPasswordScreen()),
      GoRoute(path: AppRoutes.resetPassword, builder: (context, _) => const ResetPasswordScreen()),
      GoRoute(path: AppRoutes.tenantSelect, builder: (context, _) => const TenantSelectScreen()),
      ShellRoute(
        builder: (context, state, child) => MainLayout(child: child),
        routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (context, _) => const DashboardScreen()),
          GoRoute(path: AppRoutes.invoices, builder: (context, _) => const InvoicesScreen()),
          GoRoute(path: AppRoutes.accounting, builder: (context, _) => const AccountingScreen()),
          GoRoute(path: AppRoutes.treasury, builder: (context, _) => const TreasuryScreen()),
          GoRoute(path: AppRoutes.purchases, builder: (context, _) => const PurchasesScreen()),
          GoRoute(path: AppRoutes.approvals, builder: (context, _) => const ApprovalsScreen()),
          GoRoute(path: AppRoutes.cabinet, builder: (context, _) => const CabinetScreen()),
          GoRoute(path: AppRoutes.emcf, builder: (context, _) => const EmcfScreen()),
          GoRoute(path: AppRoutes.payroll, builder: (context, _) => const PayrollScreen()),
          GoRoute(path: AppRoutes.reports, builder: (context, _) => const ReportsScreen()),
          GoRoute(path: AppRoutes.settings, builder: (context, _) => const SettingsScreen()),
        ],
      ),
    ],
  );
});
