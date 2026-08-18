import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../activities/activities_repository.dart';

/// Écran de démarrage : décide, avant d'afficher quoi que ce soit d'autre,
/// si une session valide existe déjà en Keychain (évite de repasser par le
/// login Strava à chaque lancement — cf. CLAUDE.md "Known limitation"), et
/// synchronise les activités avant de naviguer pour éviter un flash de
/// données obsolètes sur le Dashboard.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final restored = await ApiClient.instance.restoreSession();
    if (restored) {
      try {
        await ActivitiesRepository().sync().timeout(const Duration(seconds: 8));
      } catch (_) {
        // best-effort : ne bloque pas l'entrée dans l'app si le réseau/Strava traîne.
      }
    }
    if (!mounted) return;
    context.go(restored ? '/' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }
}
