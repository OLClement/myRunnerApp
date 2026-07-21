import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/app_shell.dart';
import 'core/theme.dart';
import 'features/activities/activities_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/planning/planning_screen.dart';
import 'features/prepa/prepa_screen.dart';
import 'features/settings/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const DashboardScreen())]),
        StatefulShellBranch(
          routes: [GoRoute(path: '/activities', builder: (context, state) => const ActivitiesScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: '/planning', builder: (context, state) => const PlanningScreen())],
        ),
        StatefulShellBranch(routes: [GoRoute(path: '/prepa', builder: (context, state) => const PrepaScreen())]),
      ],
    ),
  ],
);

class MyRunnerApp extends StatelessWidget {
  const MyRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'MyRunner',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
