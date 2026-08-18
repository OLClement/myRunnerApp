# Backlog d'améliorations — cadrage

Cadrage des demandes utilisateur du 2026-08-16 (login/sync, UX activités, bug dashboard, site
web). Chaque point liste la décision produit retenue et son état d'avancement. Complète
`instructions.MD` (roadmap des lots) plutôt que de le remplacer.

## 1. Sync automatique au démarrage — ✅ fait

Après connexion (session existante restaurée ou login Strava frais), l'app déclenche
automatiquement `POST /activities/sync` une fois par lancement, en tâche de fond (pas de
blocage UI, échec réseau silencieux). Voir `mobile/lib/features/dashboard/dashboard_screen.dart`
(`_autoSyncOnce`).

## 2. Session persistante (pas de re-login à chaque lancement) — ✅ fait

Un écran `SplashScreen` (`mobile/lib/features/auth/splash_screen.dart`) tente de restaurer la
session via le refresh token stocké en Keychain (`POST /auth/refresh`, déjà existant côté
backend — access token 120 min, refresh token 30 jours) avant d'afficher le Dashboard ou
l'écran de login. `app.dart` route désormais vers `/splash` au démarrage plutôt que
`/login` en dur.

## 3. Écran détail d'activité (stats, zones, courbe FC) — ✅ fait

Nouvel endpoint `GET /activities/{id}` (zones + streams HR/vitesse déjà stockés en base, pas de
recalcul) et nouvel écran mobile `ActivityDetailScreen`
(`mobile/lib/features/activities/activity_detail_screen.dart`, route `/activities/:id`) : stats
clés, répartition du temps par zone FC (barre empilée, même convention que le dashboard), courbe
FC seconde par seconde. Accessible en tapant une carte dans la liste des activités.

## 4. Code couleur de la charge — ✅ fait

Paliers discrets réutilisant les couleurs de statut déjà définies dans `theme.dart`
(`statusGood`/`Warning`/`Serious`/`Critical`), calés sur la distribution réelle observée en base
(p25≈5, p50≈32, p75≈73, p90≈140) : `<50` vert, `50-150` jaune, `150-300` orange, `>300` rouge
(~1% des activités). Voir `mobile/lib/features/activities/charge_style.dart`, appliqué dans la
liste d'activités et l'écran détail.

## 5. Bug graphique dashboard (barres zones HR < 100%) — ✅ fait

Cause : le temps "sous Z1" (échauffement/récup) était compté dans le dénominateur du calcul de
% mais jamais distribué dans les séries envoyées au mobile
(`api/app/services/dashboard_service.py`). Fix : ce temps est désormais fondu dans Z1 à
l'affichage (pas de nouveau segment/couleur). Vérifié par calcul direct sur `GET /dashboard`
(toutes les semaines somment à 100% ± arrondi).

## 6. Site web (même base Supabase) — non planifié, pas prioritaire

Besoin exprimé : répliquer l'app sur le web avec les mêmes fonctionnalités, branché sur la même
base Supabase / API FastAPI (`api.myrunner.fr`). Explicitement mis de côté pour l'instant — à
cadrer dans une session dédiée le moment venu (probablement soit Flutter Web sur le code Flutter
existant, soit un frontend web séparé consommant la même API — décision non tranchée).
