# MyRunner iOS

Réécriture de l'app web MyRunner (Flask) en app iOS : **FastAPI** (backend) + **Supabase**
(Postgres managé) + **Flutter** (mobile) + JWT maison émis après OAuth Strava.

Le cadrage produit/technique complet est dans [`instructions.MD`](./instructions.MD).
Ce fichier documente **l'état d'avancement**, **les décisions prises pendant le build**, et
**comment reproduire l'environnement de dev sur une autre machine**.

---

## État d'avancement

### ✅ Lot 0 — Fondations (terminé)

- **Backend** (`/api`) : squelette FastAPI qui démarre, se connecte à Supabase, `GET /health`
  répond `200`. 6 tables créées via Alembic (`users`, `activities`, `workout_templates`,
  `planned_workouts`, `prep_plans`, `prep_weeks`) — modèles portés 1:1 depuis l'ancien repo
  Flask.
- **Mobile** (`/mobile`) : app Flutter qui compile et tourne sur le simulateur iOS, structure
  de dossiers en place (`auth`, `settings`, `activities`, `dashboard`).

### 🟡 Lot 1 — MVP (en cours)

- ✅ **Auth Strava → JWT** : `GET /auth/strava/login` (redirige vers Strava),
  `GET /auth/strava/callback` (échange le code, upsert `User`, émet JWT access+refresh,
  redirige vers `myrunner://strava/callback?...`), `POST /auth/refresh`, `POST /auth/logout`.
  Côté mobile : écran login réel via `flutter_web_auth_2`, tokens stockés dans
  `flutter_secure_storage`. Vérifié en conditions réelles (vrai compte Strava).
- ✅ **Activities** : `GET /activities`, `POST /activities/sync` (limit 50),
  `POST /activities/sync/full` (resync complet), `POST /activities/sync/repair` (recalcule
  `charge_load` manquant) — port de `strava_service.py`. Écran liste + pull-to-refresh côté
  mobile. Vérifié avec de vraies activités Strava (charge calculée correctement).
- ✅ **Dashboard** : `GET /dashboard?period=` — charge hebdomadaire par sport + moyenne
  mobile 4 semaines + KPIs (semaine en cours, moyenne 4 sem., projection). Port simplifié de
  la route `/dashboard` de l'ancien Flask app : la répartition par zones FC et les bandes de
  volatilité journalière (MM7j + écart-type 28j) n'ont **pas** été portées pour l'instant
  (scope réduit volontairement). Écran mobile avec graphe `fl_chart` (charge hebdo + moyenne
  mobile) + tuiles KPI.
- ⬜ **Settings** (`fc_max`, PR) — pas commencé.

Détail du découpage dans `instructions.MD` section 4.

### 🚀 Déploiement production (hors lots — terminé)

L'app tourne maintenant sur l'iPhone de Clément sans câble, sans Mac allumé, utilisable en 4G :
- **Backend** déployé sur **Render** (plan free) via `render.yaml` (Blueprint), service
  `myrunner-api`, domaine custom `https://api.myrunner.fr` (CNAME chez IONOS,
  `myrunner-api.onrender.com` en cible, SSL auto Render).
- **`DATABASE_URL` doit utiliser le connection pooler Supabase** (Supavisor,
  `aws-0-eu-north-1.pooler.supabase.com:6543`, user `postgres.<ref-projet>`), pas la connexion
  directe (`db.<ref>.supabase.co`) — Render n'a pas de sortie IPv6 fonctionnelle, et le host
  direct de Supabase résout en IPv6 dans certaines régions, ce qui plantait chaque requête
  touchant la DB (`Network is unreachable`) alors que ça marchait en local.
- **Callback Strava partagé avec l'ancienne webapp Flask** : le compte Strava (mêmes
  `client_id`/`client_secret` que l'ancien `myRunner`) a son "Authorization Callback Domain"
  réglé sur le domaine racine `myrunner.fr` — Strava couvre alors tous les sous-domaines
  automatiquement (`myrunner.fr` pour l'ancienne webapp, `api.myrunner.fr` pour la nouvelle API,
  `dev.myrunner.fr` pour le dev local), sans avoir à re-changer ce réglage entre les trois.
- Côté mobile, `apiBaseUrl` (compile-time, `mobile/lib/core/api_client.dart`) pointe par défaut
  sur `https://api.myrunner.fr` ; un override `--dart-define=API_BASE_URL=...` permet de
  développer contre le backend local (simulateur ou device physique — détails dans `CLAUDE.md`).
- Build/install sur iPhone en **release** (pas debug) pour pouvoir lancer l'app depuis l'écran
  d'accueil sans session `flutter run` active — voir `CLAUDE.md` pour les commandes exactes.

### Limites connues à garder en tête
- Pas de session persistante au démarrage : l'app affiche toujours l'écran de login au
  lancement, même si un JWT valide est déjà dans le Keychain (pas de vérification/auto-skip
  au démarrage pour l'instant).
- Signature Xcode gratuite (compte perso, pas de compte développeur payant) : expire tous les
  7 jours, il faut relancer un build/install périodiquement pour la renouveler.
- ~~`JWT_SECRET` par défaut dans `.env.example` est court~~ — corrigé : vrais secrets aléatoires
  générés (`openssl rand -hex 32`), différents entre `api/.env` local et Render.

---

## Décisions prises pendant le build (au-delà de `instructions.MD`)

- **Boucle de dev locale pour le MVP, puis déploiement Render une fois le besoin d'un vrai
  device apparu.** Le callback OAuth Strava exige une redirect_uri sur un domaine "réel" (pas
  un scheme custom `myrunner://` directement) — mais Strava accepte `localhost`, et le
  simulateur iOS partage le réseau du Mac hôte, donc `http://localhost:8000/...` a suffi tant
  que le dev restait sur simulateur. Le backend FastAPI redirige ensuite vers
  `myrunner://strava/callback?...` que `flutter_web_auth_2` intercepte pour fermer le
  navigateur in-app. Une fois le besoin de tester sur iPhone physique arrivé, le backend a été
  déployé sur Render (voir section "Déploiement production" ci-dessus) plutôt que de rester sur
  du ngrok/Wi-Fi maison à long terme.
- **Gestion des paquets Python** : `venv` + `requirements.txt` (pas de Poetry/uv).
- **JWT** : `PyJWT`, tokens access + refresh **stateless** (pas de table de révocation
  serveur pour le MVP).
- **Supabase** : un **nouveau projet Supabase dédié** a été créé pour MyRunner (pas de
  réutilisation d'un projet existant, pour ne rien risquer d'écraser). C'est une base cloud
  partagée entre toutes les machines de dev — voir plus bas, pas besoin d'en recréer une sur
  un autre ordinateur.
- **Charte graphique** : palette validée (contraste + daltonisme vérifiés par script, pas à
  l'œil — voir la skill `dataviz`), orange (`#EB6834` clair / `#D95926` sombre) comme couleur
  de marque, surfaces crème/sombre chaudes, typographie système par défaut (Material 3, pas de
  police custom). Définie dans `mobile/lib/core/theme.dart`. Mode sombre gratuit via
  `themeMode: ThemeMode.system`. La même palette catégorielle (8 teintes, ordre fixe) sert
  pour les graphes du dashboard.

---

## Reproduire l'environnement de dev sur une autre machine

### 1. Outils système (une fois par machine)

```bash
# Homebrew (si absent) : voir https://brew.sh

# Xcode — l'application complète (pas juste les Command Line Tools), depuis l'App Store.
# Après install, l'ouvrir une fois pour accepter la licence + installer les composants :
xcodebuild -runFirstLaunch
# Puis télécharger le runtime simulateur iOS (image système utilisée par le simulateur) :
xcodebuild -downloadPlatform iOS

# Flutter SDK
brew install --cask flutter

# CocoaPods (gestion des dépendances natives iOS de Flutter)
brew install cocoapods

# Vérifier que tout est en ordre (Android manquant = normal, on ne cible pas Android)
flutter doctor
```

### 2. Récupérer le repo + les secrets

```bash
git clone <url-du-repo> myRunnerApp   # ou copier le dossier
cd myRunnerApp
```

`api/.env` contient des secrets (mot de passe Supabase, credentials Strava, JWT secret) et
n'est **pas** dans git (`.gitignore`). Il faut le copier manuellement depuis la première
machine (ex. via un gestionnaire de mots de passe, AirDrop, etc.) — **ne pas régénérer** ces
valeurs : la base Supabase et l'app Strava sont des ressources **cloud partagées**, identiques
quelle que soit la machine qui s'y connecte.

### 3. Backend

```bash
cd api
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
# .env déjà en place (copié à l'étape précédente)
.venv/bin/alembic upgrade head   # idempotent, sans effet si déjà à jour
.venv/bin/uvicorn app.main:app --reload
# → vérifier http://localhost:8000/health répond {"status":"ok"}
```

### 4. Mobile

```bash
cd mobile
flutter pub get
flutter run   # choisir un simulateur iOS quand demandé
```

---

## Structure du repo

```
myRunnerApp/
├── instructions.MD     # cadrage produit/technique complet
├── README.md            # ce fichier
├── api/                  # FastAPI
│   ├── app/
│   │   ├── main.py        # app FastAPI, CORS, /health, routers
│   │   ├── config.py      # settings (.env)
│   │   ├── db.py           # engine SQLAlchemy, Base, get_db
│   │   ├── models.py       # modèles (port de l'ancien models.py Flask)
│   │   ├── schemas.py      # schémas Pydantic (requêtes/réponses)
│   │   ├── security.py     # JWT (création/validation)
│   │   ├── deps.py         # get_current_user, get_strava_token
│   │   ├── routers/        # auth.py, activities.py, dashboard.py (settings.py à venir)
│   │   └── services/       # strava_auth.py, strava_service.py, dashboard_service.py
│   ├── migrations/         # Alembic
│   ├── requirements.txt
│   └── .env.example
└── mobile/                # Flutter
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart         # go_router
    │   ├── core/             # api_client (dio), secure_storage, theme
    │   └── features/         # auth, activities, dashboard (settings à venir)
    └── ios/Runner/Info.plist # scheme custom myrunner://
```

---

## Logique métier source (à porter au fil du Lot 1)

L'ancien repo Flask (**pas dans ce dépôt**, sibling directory sur la machine d'origine) :
`~/Desktop/perso/myRunner/`. Fichiers pertinents : `models.py`, `vdot.py`,
`strava_service.py`, `athlete_profile.py`, `strava_auth.py`. Si tu reprends ce projet sur une
autre machine sans accès à ce dossier, il faudra soit le copier aussi, soit reconstruire la
logique directement depuis ce `README.md` + `instructions.MD` (les grandes lignes de chaque
fichier sont résumées dans la section "Décisions" ci-dessus et dans `instructions.MD`).
