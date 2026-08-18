import 'package:flutter/material.dart';

import 'theme.dart';

/// Label de section MAJUSCULES + espacé, avec une action optionnelle alignée à
/// droite (lien/bouton) — motif "MY WORKOUTS ⋯ Show All" du design de référence
/// (Kenko). Réutilisé au-dessus des hero cards du dashboard, du panel
/// Activités, etc.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: inkSecondary,
            ),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Une statistique de [StatRow] : gros chiffre + unité optionnelle inline +
/// libellé dessous.
class StatItem {
  const StatItem({
    required this.value,
    this.unit,
    required this.label,
    this.valueColor,
  });

  final String value;
  final String? unit;
  final String label;
  final Color? valueColor;
}

/// Rangée de statistiques plate — PAS une card : sur la référence Kenko ("25
/// workouts completed · 103k kg tonnage lifted · 70 kg current weight" sur le
/// dashboard, "7 workouts completed · 9676 kg tonnage lifted" sur le détail
/// séance), ces chiffres reposent directement sur le fond de page, séparés par
/// de simples dividers fins — pas de boîte blanche ni d'ombre autour.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.items});

  final List<StatItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 40,
                child: VerticalDivider(
                  width: 1,
                  color: inkSecondary.withValues(alpha: 0.18),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          items[i].value,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: items[i].valueColor,
                          ),
                        ),
                        if (items[i].unit != null) ...[
                          const SizedBox(width: 2),
                          Text(
                            items[i].unit!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inkSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    items[i].label,
                    maxLines: 2,
                    style: TextStyle(fontSize: 11, color: inkSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Card unique, coins arrondis, qui enrobe une colonne de lignes séparées par
/// des hairlines — remplace une liste de cards individuelles à ombre (motif
/// "Add Exercises" du design de référence : pas d'ombre par ligne, juste un
/// panel + des traits fins).
class HairlineListPanel extends StatelessWidget {
  const HairlineListPanel({
    super.key,
    required this.children,
    this.indent = 60,
  });

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow(isDark),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: indent,
                color: inkSecondary.withValues(alpha: 0.12),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Bandeau plein bord (pas de marge gauche/droite, coins carrés) qui s'étend
/// jusqu'au bord de l'écran et prend en charge lui-même l'inset de la status
/// bar — motif "Add Exercises"/"Filter" du design de référence (Kenko), où le
/// bandeau coloré n'est PAS une card flottante avec marge/ombre/coins arrondis
/// comme les hero cards du dashboard, mais un vrai bandeau plein écran qui
/// enchaîne directement sur le contenu en dessous (cf. [FlatDividedList]).
class FullBleedHeroHeader extends StatelessWidget {
  const FullBleedHeroHeader({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
      padding: padding ?? EdgeInsets.fromLTRB(20, topInset + 18, 20, 20),
      child: child,
    );
  }
}

/// Liste plate, plein bord, sans card/ombre/coins arrondis englobants — juste
/// des lignes séparées par des hairlines sur le fond de la page. Pensée pour
/// enchaîner directement sous un [FullBleedHeroHeader], sans le gap ni le
/// "flottement" d'un [HairlineListPanel]. `background` permet de teinter le
/// fond (ex. surface blanche plutôt que le gris de page) pour matcher la zone
/// blanche continue du design de référence.
class FlatDividedList extends StatelessWidget {
  const FlatDividedList({
    super.key,
    required this.children,
    this.indent = 60,
    this.background,
  });

  final List<Widget> children;
  final double indent;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inkSecondary = isDark
        ? AppColors.inkSecondaryDark
        : AppColors.inkSecondaryLight;

    return Container(
      width: double.infinity,
      color: background,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: indent,
                color: inkSecondary.withValues(alpha: 0.12),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// Petit tag arrondi fond teinté — remplace les badges rectangulaires à angles
/// droits (zone d'intensité, filtres) par le style "pill" du design de
/// référence.
class PillTag extends StatelessWidget {
  const PillTag({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : 8,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 9 : 12, color: color),
            SizedBox(width: dense ? 2 : 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 9 : 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
