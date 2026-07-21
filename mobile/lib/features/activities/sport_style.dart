import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Regroupe les `sport_type` Strava bruts dans les mêmes catégories que le
/// backend (`SPORT_TYPE_TO_GROUP` dans strava_service.py), pour un affichage
/// cohérent. Index de palette fixe par catégorie — ne pas réordonner.
class SportStyle {
  const SportStyle({required this.label, required this.icon, required this.paletteIndex});

  final String label;
  final IconData icon;
  final int? paletteIndex; // null = "Autre", pas de couleur catégorielle (gris neutre)

  static const _groups = <String, SportStyle>{
    'Run': SportStyle(label: 'Course', icon: Icons.directions_run, paletteIndex: 0),
    'TrailRun': SportStyle(label: 'Course', icon: Icons.directions_run, paletteIndex: 0),
    'VirtualRun': SportStyle(label: 'Course', icon: Icons.directions_run, paletteIndex: 0),
    'Ride': SportStyle(label: 'Vélo', icon: Icons.directions_bike, paletteIndex: 3),
    'VirtualRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, paletteIndex: 3),
    'MountainBikeRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, paletteIndex: 3),
    'GravelRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, paletteIndex: 3),
    'EBikeRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, paletteIndex: 3),
    'Swim': SportStyle(label: 'Natation', icon: Icons.pool, paletteIndex: 1),
    'OpenWaterSwim': SportStyle(label: 'Natation', icon: Icons.pool, paletteIndex: 1),
    'WeightTraining': SportStyle(label: 'Renfo', icon: Icons.fitness_center, paletteIndex: 4),
    'Workout': SportStyle(label: 'Renfo', icon: Icons.fitness_center, paletteIndex: 4),
    'Crossfit': SportStyle(label: 'Renfo', icon: Icons.fitness_center, paletteIndex: 4),
    'AlpineSki': SportStyle(label: 'Ski', icon: Icons.downhill_skiing, paletteIndex: 5),
    'BackcountrySki': SportStyle(label: 'Ski', icon: Icons.downhill_skiing, paletteIndex: 5),
    'NordicSki': SportStyle(label: 'Ski', icon: Icons.downhill_skiing, paletteIndex: 5),
  };

  static const _other = SportStyle(label: 'Autre', icon: Icons.sports, paletteIndex: null);

  static SportStyle of(String sportType) => _groups[sportType] ?? _other;

  Color color(bool isDark) {
    if (paletteIndex == null) return AppColors.inkMuted;
    return (isDark ? AppColors.categoricalDark : AppColors.categoricalLight)[paletteIndex!];
  }
}
