import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Regroupe les `sport_type` Strava bruts dans les mêmes catégories que le
/// backend (`SPORT_TYPE_TO_GROUP` dans strava_service.py), pour un affichage
/// cohérent. Index fixe dans `AppColors.sportRampLight/Dark` par catégorie —
/// ne pas réordonner.
class SportStyle {
  const SportStyle({required this.label, required this.icon, required this.rampIndex});

  final String label;
  final IconData icon;
  final int? rampIndex; // null = "Autre", pas de couleur dédiée (gris neutre)

  static const _groups = <String, SportStyle>{
    'Run': SportStyle(label: 'Course', icon: Icons.directions_run, rampIndex: 1),
    'TrailRun': SportStyle(label: 'Course', icon: Icons.directions_run, rampIndex: 1),
    'VirtualRun': SportStyle(label: 'Course', icon: Icons.directions_run, rampIndex: 1),
    'Ride': SportStyle(label: 'Vélo', icon: Icons.directions_bike, rampIndex: 0),
    'VirtualRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, rampIndex: 0),
    'MountainBikeRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, rampIndex: 0),
    'GravelRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, rampIndex: 0),
    'EBikeRide': SportStyle(label: 'Vélo', icon: Icons.directions_bike, rampIndex: 0),
    'Swim': SportStyle(label: 'Natation', icon: Icons.pool, rampIndex: 2),
    'OpenWaterSwim': SportStyle(label: 'Natation', icon: Icons.pool, rampIndex: 2),
    'WeightTraining': SportStyle(label: 'Renfo', icon: Icons.fitness_center, rampIndex: 3),
    'Workout': SportStyle(label: 'Renfo', icon: Icons.fitness_center, rampIndex: 3),
    'Crossfit': SportStyle(label: 'Renfo', icon: Icons.fitness_center, rampIndex: 3),
    'AlpineSki': SportStyle(label: 'Ski', icon: Icons.downhill_skiing, rampIndex: 4),
    'BackcountrySki': SportStyle(label: 'Ski', icon: Icons.downhill_skiing, rampIndex: 4),
    'NordicSki': SportStyle(label: 'Ski', icon: Icons.downhill_skiing, rampIndex: 4),
  };

  static const _other = SportStyle(label: 'Autre', icon: Icons.sports, rampIndex: null);

  static SportStyle of(String sportType) => _groups[sportType] ?? _other;

  Color color(bool isDark) {
    if (rampIndex == null) return AppColors.inkMuted;
    return (isDark ? AppColors.sportRampDark : AppColors.sportRampLight)[rampIndex!];
  }
}
