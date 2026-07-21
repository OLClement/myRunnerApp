import 'package:flutter/material.dart';

import '../../core/coming_soon_screen.dart';

class PrepaScreen extends StatelessWidget {
  const PrepaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Prépa',
      icon: Icons.flag_outlined,
      message: 'Plans de préparation objectif course — bientôt disponible.',
    );
  }
}
