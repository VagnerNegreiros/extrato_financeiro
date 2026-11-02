import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Named routes. Navigation always uses names, never raw paths.
abstract final class AppRoute {
  static const dashboard = 'dashboard';
  static const statement = 'statement';
  static const transactionDetails = 'transactionDetails';
}

/// Routes are flat and opened with `pushNamed`, so the back button always
/// returns to the screen the user came from: details opened from the
/// statement keep the statement (filters, pages and scroll) alive below.
GoRouter createRouter({
  required WidgetBuilder dashboard,
  required WidgetBuilder statement,
  required Widget Function(BuildContext context, String id) details,
  String initialLocation = '/',
}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      name: AppRoute.dashboard,
      builder: (context, _) => dashboard(context),
    ),
    GoRoute(
      path: '/extrato',
      name: AppRoute.statement,
      builder: (context, _) => statement(context),
    ),
    GoRoute(
      path: '/transacao/:id',
      name: AppRoute.transactionDetails,
      builder: (context, state) =>
          details(context, state.pathParameters['id'] ?? ''),
    ),
  ],
);

extension AppNavigation on BuildContext {
  void openStatement() => pushNamed(AppRoute.statement);

  void openTransaction(String id) =>
      pushNamed(AppRoute.transactionDetails, pathParameters: {'id': id});

  /// Pops, or goes to the dashboard when the screen was opened directly
  /// (deep link) and there is nothing to pop.
  void back() => canPop() ? pop() : goNamed(AppRoute.dashboard);
}
