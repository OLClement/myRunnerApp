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
- **Mobile** (`/mobile`) : app Flutter qui compile et tourne sur le simulateur iOS, écran de
  login placeholder affiché, structure de dossiers en place (`auth`, `settings`,
  `activities`, `dashboard`).

### ⬜ Lot 1 — MVP (pas commencé)

Auth Strava → JWT (câbler le vrai bouton login), Activities (sync Strava réelle), Dashboard
(graphes), Settings (fc_max, PR). Détail dans `instructions.MD` section 4.

---

## Décisions prises pendant le build (au-delà de `instructions.MD`)

- **Boucle de dev 100% locale, pas de ngrok ni de Render pour le MVP.** Le callback OAuth
  Strava exige une redirect_uri sur un domaine "réel" (pas un scheme custom `myrunner://`
  directement) — mais Strava accepte `localhost`, et le simulateur iOS partage le réseau du
  Mac hôte. Donc : `STRAVA_REDIRECT_URI=http://localhost:8000/auth/strava/callback`, et le
  backend FastAPI redirige ensuite vers `myrunner://strava/callback?...` que
  `flutter_web_auth_2` intercepte pour fermer le navigateur in-app. Render/ngrok ne
  redeviendront utiles que pour un test sur device physique (hors périmètre actuel).
- **Gestion des paquets Python** : `venv` + `requirements.txt` (pas de Poetry/uv).
- **JWT** : `PyJWT`, tokens access + refresh **stateless** (pas de table de révocation
  serveur pour le MVP).
- **Supabase** : un **nouveau projet Supabase dédié** a été créé pour MyRunner (pas de
  réutilisation d'un projet existant, pour ne rien risquer d'écraser). C'est une base cloud
  partagée entre toutes les machines de dev — voir plus bas, pas besoin d'en recréer une sur
  un autre ordinateur.

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
│   │   ├── main.py        # app FastAPI, CORS, /health
│   │   ├── config.py      # settings (.env)
│   │   ├── db.py           # engine SQLAlchemy, Base, get_db
│   │   ├── models.py       # modèles (port de l'ancien models.py Flask)
│   │   ├── security.py     # JWT (création/validation)
│   │   ├── deps.py         # get_current_user
│   │   ├── routers/        # endpoints (vide pour l'instant, Lot 1)
│   │   └── services/       # logique métier portée (Lot 1)
│   ├── migrations/         # Alembic
│   ├── requirements.txt
│   └── .env.example
└── mobile/                # Flutter
    ├── lib/
    │   ├── main.dart
    │   ├── app.dart         # go_router
    │   ├── core/             # api_client (dio), secure_storage
    │   └── features/         # auth, settings, activities, dashboard
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
