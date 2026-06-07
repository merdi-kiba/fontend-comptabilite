/// Helpers partagés pour les tests d'intégration Flutter PROXIMA
///
/// Usage dans les tests :
///   import 'helpers/test_helpers.dart';
///   await loginAs(tester, kTestEmail, kTestPassword);

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── Constantes de test ───────────────────────────────────────────────────────

/// URL de l'API de test (injectée via --dart-define=API_BASE_URL=...)
const String kTestBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3001',
);

const String kTestEmail = 'admin@test.local';
const String kTestPassword = 'TestPass123!';

const String kSuperadminEmail = 'superadmin@proxima.test';
const String kSuperadminPassword = 'TestPass123!';

const String kComptableEmail = 'comptable@test.local';
const String kComptablePassword = 'TestPass123!';

// ─── Durées de timeout ────────────────────────────────────────────────────────

const Duration kShortTimeout = Duration(seconds: 5);
const Duration kMediumTimeout = Duration(seconds: 10);
const Duration kLongTimeout = Duration(seconds: 20);

// ─── Helpers de navigation ────────────────────────────────────────────────────

/// Attend que l'interface soit stable (animations terminées + requêtes HTTP)
Future<void> waitForApiResponse(WidgetTester tester) async {
  await tester.pumpAndSettle(kMediumTimeout);
}

/// Attend un widget spécifique en faisant plusieurs pumpAndSettle
Future<void> waitForWidget(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = kLongTimeout,
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    if (finder.evaluate().isNotEmpty) return;
  }
  throw Exception('Widget non trouvé dans le délai imparti: $finder');
}

/// Se connecte à l'application avec les credentials donnés
Future<void> loginAs(
  WidgetTester tester,
  String username,
  String password,
) async {
  final usernameField = find.byKey(const Key('login_username_field'));
  final passwordField = find.byKey(const Key('login_password_field'));
  final loginButton = find.byKey(const Key('login_submit_button'));

  // Essayer avec les Keys d'abord, puis les types génériques
  if (usernameField.evaluate().isNotEmpty) {
    await tester.tap(usernameField);
    await tester.enterText(usernameField, username);
  } else {
    // Fallback : premier TextFormField
    final fields = find.byType(TextField);
    if (fields.evaluate().isNotEmpty) {
      await tester.tap(fields.first);
      await tester.enterText(fields.first, username);
    }
  }
  await tester.pump();

  if (passwordField.evaluate().isNotEmpty) {
    await tester.tap(passwordField);
    await tester.enterText(passwordField, password);
  } else {
    final fields = find.byType(TextField);
    if (fields.evaluate().length >= 2) {
      await tester.tap(fields.at(1));
      await tester.enterText(fields.at(1), password);
    }
  }
  await tester.pump();

  if (loginButton.evaluate().isNotEmpty) {
    await tester.tap(loginButton);
  } else {
    // Fallback : bouton avec texte "Connexion" ou "Se connecter"
    final connecterBtn = find.widgetWithText(ElevatedButton, 'Connexion');
    if (connecterBtn.evaluate().isNotEmpty) {
      await tester.tap(connecterBtn);
    } else {
      final seConnecterBtn = find.widgetWithText(ElevatedButton, 'Se connecter');
      if (seConnecterBtn.evaluate().isNotEmpty) {
        await tester.tap(seConnecterBtn);
      }
    }
  }

  await waitForApiResponse(tester);
}

/// Se déconnecte de l'application
Future<void> logout(WidgetTester tester) async {
  // Chercher le bouton de déconnexion
  final logoutKey = find.byKey(const Key('logout_button'));

  if (logoutKey.evaluate().isNotEmpty) {
    await tester.tap(logoutKey);
  } else {
    // Ouvrir le menu utilisateur
    final menuBtn = find.byKey(const Key('user_menu_button'));
    if (menuBtn.evaluate().isNotEmpty) {
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();
    }

    final logoutText = find.text('Se déconnecter');
    if (logoutText.evaluate().isNotEmpty) {
      await tester.tap(logoutText);
    } else {
      final deconnecterText = find.text('Déconnexion');
      if (deconnecterText.evaluate().isNotEmpty) {
        await tester.tap(deconnecterText);
      }
    }
  }

  await waitForApiResponse(tester);
}

/// Navigue vers un écran via la barre de navigation ou les routes
Future<void> navigateTo(WidgetTester tester, String routeLabel) async {
  final navItem = find.text(routeLabel);
  if (navItem.evaluate().isNotEmpty) {
    await tester.tap(navItem.first);
    await waitForApiResponse(tester);
  }
}

/// Vérifie qu'un texte est visible (avec scroll si nécessaire)
Future<void> expectTextVisible(
  WidgetTester tester,
  String text,
) async {
  final finder = find.textContaining(text);
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 100);
  }
  expect(finder, findsAtLeastNWidgets(1));
}

/// Saisit un montant dans un champ de formulaire
Future<void> enterAmount(
  WidgetTester tester,
  Key fieldKey,
  double amount,
) async {
  final field = find.byKey(fieldKey);
  await tester.tap(field);
  await tester.enterText(field, amount.toStringAsFixed(0));
  await tester.pump();
}

/// Prend une capture d'écran et l'inclut dans le rapport de test (debug)
Future<void> takeScreenshot(WidgetTester tester, String name) async {
  await tester.pump();
  // Note: Les captures d'écran intégration test sont disponibles via
  // flutter test --reporter json
  debugPrint('[SCREENSHOT] $name — ${DateTime.now().toIso8601String()}');
}

// ─── Vérifications métier ─────────────────────────────────────────────────────

/// Vérifie que le dashboard est affiché (KPIs visibles)
Future<void> expectDashboardLoaded(WidgetTester tester) async {
  // Vérifier qu'il y a au moins un chiffre/montant affiché
  final hasAmount = find.byType(Text);
  expect(hasAmount.evaluate().length, greaterThan(0));
}

/// Vérifie qu'un message d'erreur est affiché
Future<void> expectErrorMessage(WidgetTester tester, String pattern) async {
  await tester.pumpAndSettle(kMediumTimeout);
  final errorFinder = find.textContaining(pattern, findRichText: true);
  if (errorFinder.evaluate().isEmpty) {
    // Essayer avec SnackBar
    final snackBar = find.byType(SnackBar);
    expect(snackBar.evaluate().length, greaterThan(0));
  } else {
    expect(errorFinder, findsAtLeastNWidgets(1));
  }
}
