import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Code couleur de la charge d'une activité : dégradé continu bleu → rouge
/// (interpolation HSV, pas RGB — un lerp RGB direct traverse un point mort
/// terne au milieu du dégradé), calé sur la distribution réelle observée en
/// base (p25≈5, p50≈32, p75≈73, p90≈140, ~1% des activités dépassent 300).
Color chargeColor(double? charge, bool isDark) {
  if (charge == null) {
    return isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight;
  }
  final t = (charge / 300).clamp(0.0, 1.0);
  final low = isDark ? AppColors.chargeScaleLowDark : AppColors.chargeScaleLowLight;
  final high = isDark ? AppColors.chargeScaleHighDark : AppColors.chargeScaleHighLight;
  return HSVColor.lerp(HSVColor.fromColor(low), HSVColor.fromColor(high), t)!.toColor();
}
