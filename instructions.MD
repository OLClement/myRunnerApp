# MyRunner iOS — Cadrage, choix techniques et découpage en lots

## Contexte

L'app web MyRunner actuelle (Flask + Jinja + SQLite/Postgres) sera **repartie de zéro** dans un
nouveau repo dédié, sous forme d'app iOS. L'objectif ici n'est pas de coder mais de figer :
- le **cadrage produit** (quelles features dans quel ordre),
- les **choix techniques** (framework mobile, backend, base de données, auth),
- une **boucle de test en live** pendant que le développement se fait "vibe-coding" avec Claude Code.

Profil du porteur de projet : Head of Data Science, très à l'aise en Python et sur les métiers
data, un peu d'expérience web, **pas de background mobile natif**. Toutes les recommandations
ci-dessous sont choisies pour minimiser le nombre de nouveaux écosystèmes à apprendre, et pour
maximiser la réutilisation de la logique métier déjà écrite et validée dans le repo Flask actuel
(`strava_service.py`, `athlete_profile.py`, `vdot.py`, `models.py`).

Décisions déjà validées avec l'utilisateur (voir questions posées en amont) :
1. **Backend logique métier** : micro-service Python (FastAPI) + Supabase comme base managée.
2. **Framework mobile** : Flutter.
3. **Auth** : JWT maison émis par le backend après échange OAuth Strava (pas Supabase Auth).
4. **Boucle de live-test** : simulateur iOS + hot reload Flutter en local, TestFlight plus tard.

---

## 1. Pourquoi Flutter (et pas autre chose)

- **Un seul langage (Dart)** à apprendre pour toute l'UI — pas d'écosystème JS/TS à gérer
  en parallèle du Python déjà maîtrisé.
- **Hot reload très rapide** + **simulateur iOS intégré** (via Xcode, présent sur Mac) : boucle
  de feedback quasi instantanée pendant les sessions de vibe-coding, sans dépendre d'un compte
  Apple Developer.
- Écosystème mature pour le type d'app visé : graphes (`fl_chart`), calendrier (`table_calendar`),
  formulaires, navigation (`go_router`), state management typé (`riverpod`).
- Alternative écartée : **React Native/Expo** aurait une boucle "live preview" encore plus proche
  de base44 (Expo Go, QR code, OTA), mais impose l'écosystème JS/TS et les frictions de modules
  natifs RN — coût d'apprentissage plus élevé pour ce profil, pour un gain marginal vu qu'on a
  déjà une excellente boucle avec le simulateur Flutter.
- Alternative écartée : **SwiftUI natif** — meilleure intégration iOS, mais courbe d'apprentissage
  la plus raide et aucune réutilisabilité si Android est envisagé un jour.

## 2. Architecture technique retenue

```
Flutter (iOS)  ──HTTPS/JSON──▶  FastAPI (Python, ex-Render)  ──SQLAlchemy──▶  Supabase Postgres
                                        │
                                        ├─▶ Strava API (OAuth + activités)
                                        └─▶ Groq API (LLM planning/prep)
```

- **Supabase = Postgres managé uniquement** pour le MVP (pas Supabase Auth, pas RLS, pas SDK
  Supabase côté Flutter). On se connecte simplement via la connection string Postgres, exactement
  comme aujourd'hui avec `DATABASE_URL` dans le Flask app. Ce choix découle directement de la
  décision "JWT maison" : Supabase Auth n'apporte rien tant qu'on n'utilise pas ses RLS, et
  l'introduire maintenant ajouterait un concept (row-level security, `auth.jwt()`) à apprendre
  pour rien. On pourra activer le SDK Supabase plus tard (ex. Realtime pour un statut de sync live)
  si un besoin concret apparaît.
- **FastAPI remplace Flask** : mêmes modèles SQLAlchemy (portage quasi direct de `models.py`),
  même logique de calcul (`charge_load`, VDOT, `athlete_profile.py`), mais routes JSON au lieu de
  templates Jinja, et middleware JWT au lieu de Flask-Login/sessions cookie.
- **Auth Strava → JWT maison** :
  1. Flutter ouvre l'écran d'autorisation Strava dans un navigateur in-app
     (`flutter_web_auth_2`), avec un **custom URL scheme** (`myrunner://strava/callback`) comme
     redirect URI.
  2. FastAPI échange le `code` contre les tokens Strava (comme `strava_auth.py` aujourd'hui),
     upsert le `User` en base, puis émet un **JWT applicatif** (access + refresh) — le secret
     client Strava ne quitte jamais le backend.
  3. Flutter stocke le JWT dans `flutter_secure_storage` (Keychain iOS), l'attache aux appels API
     via un intercepteur `dio` avec refresh automatique — équivalent du décorateur
     `@require_strava_token` actuel, mais côté JWT applicatif plutôt que token Strava direct.
- **Repo** : un seul mono-repo pour un porteur solo (`/api` FastAPI, `/mobile` Flutter) — plus
  simple à faire vivre en vibe-coding qu'un split en deux repos, une seule session Claude Code
  peut toucher aux deux couches si besoin.
- **Déploiement backend** : Render (comme aujourd'hui), Procfile équivalent
  (`web: alembic upgrade head && uvicorn api:app`).

## 3. Boucle de test en live ("façon base44")

- Boucle principale pendant le dev : **`flutter run` sur simulateur iOS**, hot reload à chaque
  sauvegarde — gratuit, instantané, ne nécessite aucun compte Apple Developer.
- Quand une validation sur device réel est utile (capteurs, deep link OAuth, notifications) :
  passer à un test iPhone réel via câble/Xcode avec un Apple ID gratuit (provisioning 7 jours),
  suffisant en phase MVP.
- **TestFlight** (nécessite Apple Developer Program, 99$/an) à activer plus tard, une fois le
  MVP stabilisé, pour du test sur device sans câble et du partage à d'éventuels testeurs.

## 4. Découpage en lots

### Lot 0 — Fondations (setup, avant le premier lot fonctionnel)
- Création du repo dédié, structure mono-repo `/api` + `/mobile`.
- Projet Supabase (Postgres managé), portage du schéma `models.py` en Alembic.
- Squelette FastAPI : middleware JWT, endpoints d'auth Strava → JWT.
- Squelette Flutter : `go_router`, `riverpod`, `flutter_secure_storage`, client `dio` avec
  intercepteur de refresh de token.

### Lot 1 — MVP : Auth Strava + Settings + Activities + Dashboard
- **Backend** : `/auth/strava/login`, `/auth/strava/callback`, `/auth/refresh`, `/auth/logout`
  (portage de `strava_auth.py`) ; `/me` (settings : `fc_max`, PR) ; `/activities` (list, sync,
  sync/full, sync/repair — portage de la logique de `strava_service.py`) ; `/dashboard`
  (agrégats via `athlete_profile.py` : `build_athlete_profile`, `compute_phase2_scores`).
- **Flutter** : écran login (bouton Strava → deep link), écran settings (formulaire `fc_max`,
  PR), écran liste d'activités (pull-to-refresh = trigger sync), écran dashboard (graphes
  charge hebdo, fitness/fatigue/readiness via `fl_chart`).
- **Definition of done** : login Strava fonctionnel sur simulateur, sync d'activités réelles,
  `charge_load` calculé et affiché, dashboard avec graphes, édition des settings.

### Lot 2 — Planning
- **Backend** : portage de `planning.py` — CRUD `WorkoutTemplate`/`PlannedWorkout`, endpoint
  `/planning/ai` (appel Groq, même logique de prompt qu'aujourd'hui).
- **Flutter** : vue calendrier/semaine (`table_calendar`), pool de templates disponibles,
  placement d'un template sur une date, bouton "placement IA" qui appelle le backend et affiche
  les suggestions pour validation par l'utilisateur.

### Lot 3 — Prep (préparation de course avec LLM)
- **Backend** : portage de `prep.py` — CRUD `PrepPlan`/`PrepWeek`, `build_load_curve` (Python,
  inchangé), `/prep/<id>/generate` (génération LLM des descriptions de semaine).
- **Flutter** : formulaire de création de plan (course cible, date, séances/semaine), écran
  détail du plan (vue semaine par semaine : `target_load` en graphe + description générée),
  bouton de régénération.

### Pistes hors périmètre (à ne pas traiter maintenant, juste à garder en tête)
- Notifications push (rappels de séance).
- Sync automatique via webhook Strava (au lieu du bouton sync manuel).
- Cache offline.
- Portage Android (Flutter le permettrait sans réécriture majeure si besoin un jour).

## 5. Prochaine étape

Ce document sert de cadrage produit/technique. Le développement effectif (création du repo dédié,
premier commit du Lot 0) se fera dans une session ultérieure, dans le nouveau repo.
