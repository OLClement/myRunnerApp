import 'package:flutter/material.dart';

/// Charte "navy/périwinkle" (fond clair, cards blanches, un bloc "hero" bleu
/// marine très foncé pour les éléments mis en avant). Contrastes vérifiés WCAG
/// (formule standard, cf. skill dataviz) : accentLight/accentDark ≥ 4.5:1 sur
/// blanc et sur le fond de page, navy ≥ 18:1 avec du texte blanc.
/// Palette catégorielle (graphes dashboard uniquement désormais) revalidée
/// contraste + daltonisme via le skill `dataviz`. Les badges de sport
/// n'utilisent plus cette palette "identité" mais `sportRampLight/Dark`, un
/// dégradé à teinte unique bleue (retour utilisateur : le vert/rouge de la
/// palette catégorielle "piquait les yeux" même désaturé) — ne pas retoucher
/// l'une ou l'autre sans revalider (script `validate_palette` du skill).
class AppColors {
  AppColors._();

  // Accent (boutons, highlights, chiffres clés)
  static const accentLight = Color(0xFF4F5FEE);
  static const accentDark = Color(0xFF6E7CFA);

  // Bloc "hero" bleu marine — couleur fixe, ne suit pas le thème clair/sombre
  // (même esprit que les couleurs de statut : rôle réservé, jamais réordonné).
  static const navy = Color(0xFF12142B);
  static const navyMuted = Color(0xFF8A8DB0);

  // Surfaces
  static const surfaceLight = Color(0xFFFFFFFF);
  static const pageLight = Color(0xFFF4F5FA);
  static const surfaceDark = Color(0xFF141826);
  static const pageDark = Color(0xFF0B0E1A);

  // Encre
  static const inkPrimaryLight = Color(0xFF0B0B12);
  static const inkSecondaryLight = Color(0xFF6B6F80);
  static const inkPrimaryDark = Color(0xFFFFFFFF);
  static const inkSecondaryDark = Color(0xFFA8ABC0);
  static const inkMuted = Color(0xFF9497A6);

  // Palette catégorielle (ordre fixe — ne jamais réordonner selon les filtres).
  // Utilisée uniquement par les graphes du dashboard aujourd'hui : index 0
  // (bleu, série "Tout"/métrique courante) et index 3 (jaune, moyenne mobile —
  // lisible sur fond navy). Les autres slots sont réservés pour de futures
  // séries.
  static const categoricalLight = [
    Color(0xFF2A78D6), // 0 blue
    Color(0xFFEB6834), // 1 orange (inutilisé)
    Color(0xFF1BAF7A), // 2 aqua
    Color(0xFFEDA100), // 3 yellow
    Color(0xFFE87BA4), // 4 magenta
    Color(0xFF008300), // 5 green (inutilisé)
    Color(0xFF4A3AA7), // 6 violet
    Color(0xFFE34948), // 7 red
  ];

  static const categoricalDark = [
    Color(0xFF3987E5),
    Color(0xFFD95926),
    Color(0xFF199E70),
    Color(0xFFC98500),
    Color(0xFFD55181),
    Color(0xFF008300),
    Color(0xFF9085E9),
    Color(0xFFE66767),
  ];

  static const statusGood = Color(0xFF0CA30C);
  static const statusWarning = Color(0xFFFAB219);
  static const statusSerious = Color(0xFFEC835A);
  static const statusCritical = Color(0xFFD03B3B);

  // Dégradé continu de charge (bleu → rouge, cf `charge_style.dart`). Teintes
  // dédiées (pas accentLight/Dark ni statusCritical) : la trajectoire HSV
  // complète bleu→violet→rouge a été validée en contraste texte WCAG (≥4.5:1,
  // pas seulement les bornes) sur surfaceLight/surfaceDark via le skill
  // `dataviz` — un lerp naïf sur accent/statusCritical existants descend sous
  // 4.5:1 au milieu du dégradé. Rouge choisi à teinte 355° (pas 360°/0°) pour
  // que `HSVColor.fromColor` (qui normalise en [0,360)) round-trippe sur la
  // bonne trajectoire ascendante (via violet/magenta) plutôt que de redescendre
  // par le vert.
  static const chargeScaleLowLight = Color(0xFF3642B2);
  static const chargeScaleHighLight = Color(0xFFB23640);
  static const chargeScaleLowDark = Color(0xFF7381FF);
  static const chargeScaleHighDark = Color(0xFFFF737E);

  // Dégradé "sport" (badges/icônes par type de sport, cf `sport_style.dart`) —
  // une seule teinte bleue (~215°), 5 paliers de clarté (le plus clair en
  // premier). Remplace l'ancienne palette catégorielle multi-teintes : retour
  // utilisateur, le vert/rouge y restait trop visible même désaturé. Validé
  // comme un ramp ordinal (skill `dataviz`) : luminosité monotone, écarts
  // OKLCH ΔL ≥ 0.06 entre paliers adjacents, contraste vs surface (le palier
  // le plus clair reste sous 3:1 par design — mitigé par le libellé texte
  // toujours accolé à l'icône, jamais la couleur seule).
  static const sportRampLight = [
    Color(0xFF6DA7EC),
    Color(0xFF3987E5),
    Color(0xFF256ABF),
    Color(0xFF184F95),
    Color(0xFF0D366B),
  ];

  static const sportRampDark = [
    Color(0xFFA1C5F7),
    Color(0xFF73A3E6),
    Color(0xFF4982D1),
    Color(0xFF2864B8),
    Color(0xFF174D99),
  ];

  // Zones d'intensité (Z1 → Z5 + Mixte) — convention fixe reprise de l'app
  // d'origine (myRunner Flask), même rôle qu'un statut : jamais réordonnée.
  static const zoneColors = {
    'Z1': Color(0xFF93C5FD),
    'Z2': Color(0xFF86EFAC),
    'Z3': Color(0xFFFDE047),
    'Z4': Color(0xFFFB923C),
    'Z5': Color(0xFFF87171),
    'Mixte': Color(0xFFC4B5FD),
  };

  static Color zoneColor(String? zone) => zoneColors[zone] ?? inkMuted;
}

class AppTheme {
  AppTheme._();

  // Échelle de coins arrondis façon "Kenko" (cf. captures de référence) : hero
  // cards/sheets très arrondis, panels de liste un cran en dessous, boutons/tuiles
  // modérés, tags/cellules denses les moins arrondis pour ne pas paraître "bulleux"
  // en grille serrée. `cardRadius` reste un alias de `radiusMd` pour les call sites
  // pas encore migrés vers un rôle précis.
  static const radiusXl = 28.0;
  static const radiusLg = 20.0;
  static const radiusMd = 14.0;
  static const radiusSm = 10.0;
  static const cardRadius = radiusMd;
  static const sheetRadius = radiusXl;

  // Dégradé diagonal des hero cards (dashboard/activités/planning/detail) —
  // remplace l'ancien fond `AppColors.navy` plat. Couleur fixe (ne suit pas le
  // thème clair/sombre), même logique que `AppColors.navy` lui-même.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.navy, AppColors.accentDark],
  );

  // Ombre "ambiante" douce + ombre "de contact" plus resserrée, pour que les
  // cards se détachent nettement du fond de page sans paraître dures.
  static List<BoxShadow> cardShadow(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.10),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  // Bloc "hero" navy : fond fixe (ne suit pas le thème) — même chose pour son ombre.
  static final heroCardShadow = cardShadow(true);

  // Variante plus discrète pour les éléments denses (grille calendrier) où une
  // ombre pleine grandeur sur chaque cellule ferait paraître la grille chargée.
  static List<BoxShadow> cellShadow(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
          blurRadius: 8,
          offset: const Offset(0, 3),
        ),
      ];

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final accent = isDark ? AppColors.accentDark : AppColors.accentLight;
    final inkPrimary = isDark ? AppColors.inkPrimaryDark : AppColors.inkPrimaryLight;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDark ? AppColors.pageDark : AppColors.pageLight,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.pageDark : AppColors.pageLight,
        foregroundColor: inkPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: inkPrimary, fontSize: 27, fontWeight: FontWeight.w800),
      ),
      textTheme: Typography.material2021().englishLike.apply(bodyColor: inkPrimary, displayColor: inkPrimary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
      ),
      // Nav monochrome (icône/label sombres à l'état actif, pas teintés accent) et
      // indicateur quasi invisible — Kenko distingue l'onglet actif par le
      // contraste noir/gris, pas par une pastille de couleur pleine.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        indicatorColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: states.contains(WidgetState.selected)
                ? inkPrimary
                : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? inkPrimary
                : (isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        // Fond page (plus clair que les cards blanches) pour que les champs se
        // détachent quand ils sont imbriqués dans une card surface.
        fillColor: isDark ? AppColors.pageDark : AppColors.pageLight,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMd), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.inkSecondaryDark : AppColors.inkSecondaryLight,
        ),
      ),
    );
  }
}
