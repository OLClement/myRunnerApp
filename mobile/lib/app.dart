import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/app_shell.dart';
import 'core/theme.dart';
import 'features/activities/activities_screen.dart';
import 'features/activities/activity_detail_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/splash_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/planning/planning_screen.dart';
import 'features/prepa/prepa_screen.dart';
import 'features/settings/settings_screen.dart';

final _router = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
    GoRoute(
      path: '/activities/:id',
      builder: (context, state) => ActivityDetailScreen(activityId: int.parse(state.pathParameters['id']!)),
    ),
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
