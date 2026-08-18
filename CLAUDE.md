# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

MyRunner iOS: a rewrite of an older Flask running-coach web app as **FastAPI (backend) + Supabase
(managed Postgres) + Flutter (mobile)**, with a home-rolled JWT issued after Strava OAuth (not
Supabase Auth). Mono-repo: `/api` (FastAPI) + `/mobile` (Flutter). Product/technical rationale and
the lot-by-lot roadmap live in `instructions.MD`; `README.md` tracks actual build progress and
decisions made along the way — read both before making architectural changes.

## Commands

### Backend (`/api`)

```bash
cd api
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt   # first-time setup
.venv/bin/alembic upgrade head                                        # apply migrations (idempotent)
.venv/bin/uvicorn app.main:app --reload                                # dev server, http://localhost:8000
curl http://localhost:8000/health                                      # should return {"status":"ok"}
.venv/bin/alembic revision --autogenerate -m "..."                    # new migration after model changes
```

`api/.env` (copied manually, not in git) must define `DATABASE_URL`, `STRAVA_CLIENT_ID`,
`STRAVA_CLIENT_SECRET`, `JWT_SECRET`, etc. — see `api/.env.example`. There is **no automated
backend test suite**; verify changes by hitting endpoints with `curl` (generate a throwaway JWT via
`app.security.create_access_token(user_id)` in a `python -c` snippet if you need an authenticated
request) and by reading the `uvicorn` log.

### Production deployment (Render)

The backend is deployed on Render as a Blueprint (`render.yaml` at repo root, service
`myrunner-api`, `rootDir: api`), reachable at the custom domain `https://api.myrunner.fr`
(CNAME at IONOS → `myrunner-api.onrender.com`; free Render plan, 2 custom domains included).
Env vars are set manually in Render's dashboard (`sync: false` in the blueprint) from the same
values as `api/.env`.

**`DATABASE_URL` must use Supabase's connection pooler, not the direct connection string.**
Render has no working IPv6 egress, and Supabase's direct host (`db.<ref>.supabase.co`) resolves
to an IPv6 address in some regions — this surfaced as
`psycopg2.OperationalError: ... Network is unreachable` on every DB-touching request once
deployed (worked fine locally, where the Mac's IPv6 route works). Fix: use the pooler connection
string from Supabase dashboard → Connect → Connection Pooling (host
`aws-0-<region>.pooler.supabase.com:6543`, username `postgres.<project-ref>` instead of just
`postgres`) — it's IPv4-only by design for exactly this kind of platform.

### Mobile (`/mobile`)

```bash
flutter pub get
flutter analyze                              # lint/typecheck — run after every change, must be clean
flutter test test/widget_test.dart           # the one existing test
flutter run -d <simulator-id>                # launch on a booted iOS simulator, hot reload on save
```

Requires a full Xcode install (not just Command Line Tools) and a downloaded iOS simulator runtime
(`xcodebuild -downloadPlatform iOS`). `flutter run` needs a full restart (not just hot reload) to
pick up changes to `main.dart`/`app.dart`-level structure (routing, theme).

#### Running on a physical iPhone (no App Store)

`mobile/lib/core/api_client.dart`'s `apiBaseUrl` is a compile-time `String.fromEnvironment`
default-valued to `https://api.myrunner.fr` (the Render deployment, see above) — so a normal
`flutter build ios --release` + install just works from anywhere (Wi-Fi or cellular), no Mac
dependency. Xcode signing (`RSV565PQRX` team, automatic signing) is already configured in the
Xcode project; free-tier signing expires after 7 days, so the build/install needs re-running
periodically to renew it:

```bash
flutter build ios --release
xcrun devicectl device install app --device <device-id> build/ios/iphoneos/Runner.app
xcrun devicectl device process launch --device <device-id> com.myrunner.mobile   # only works if the phone is unlocked
```

(`flutter run -d <device-id>` also works for a debug/hot-reload session over the wireless-debugging
pairing already set up for Clément's iPhone, but a **debug** build refuses to launch by tapping the
home-screen icon directly — "in iOS 14+, debug mode Flutter apps can only be launched from Flutter
IDE plugins or from the command line" — hence release builds for anything meant to be opened
normally afterward.)

To develop against the **local** backend on a physical device instead of Render, override
`apiBaseUrl` at launch:

```bash
flutter run -d <device-id> --dart-define=API_BASE_URL=http://dev.myrunner.fr:8000
```

`dev.myrunner.fr` is a DNS A record (IONOS) pointing at the Mac's LAN IP. This still works for the
Strava login flow without touching any Strava dashboard setting, because "Authorization Callback
Domain" is registered as the **root** domain `myrunner.fr` (see Auth below) — Strava auto-covers
every subdomain under it. Two one-time prerequisites keep the local-IP path from going stale:
- **DHCP reservation for the Mac** on the router, so its LAN IP (currently `192.168.1.21`) never
  changes and the DNS record never goes stale.
- **The iPhone's Wi-Fi DNS set manually to `1.1.1.1`/`8.8.8.8`** (Settings → Wi-Fi → ⓘ → Configure
  DNS → Manual), so it resolves fresh instead of hitting the router's DNS cache (which lagged
  behind an IONOS record update by hours during setup). The Mac's Wi-Fi DNS is already set the same
  way.

Uvicorn needs `--host 0.0.0.0` (not just `--reload`) to accept connections from the phone instead
of only loopback when running the local backend this way.

## Architecture

### Data flow

```
Flutter (iOS)  ──HTTPS/JSON──▶  FastAPI (Render, api.myrunner.fr)  ──SQLAlchemy──▶  Supabase Postgres
                                    │                                                (via connection pooler)
                                    ├─▶ Strava API (OAuth + activity data)
                                    └─▶ Groq API (LLM planning/prep — dependency + `config.groq_api_key`
                                        exist, but no endpoint calls it yet; see Current state)
```

### Auth

Strava OAuth happens through the backend, not the client: Flutter opens `GET /auth/strava/login`
in an in-app browser (`flutter_web_auth_2`) with redirect URI
`https://api.myrunner.fr/auth/strava/callback` in production (or `http://localhost:8000/...` /
`http://dev.myrunner.fr:8000/...` for local dev — see the "physical iPhone" section above; Strava
requires a "real" domain, not a custom scheme, but does accept `localhost`). The Strava API app
(`client_id` 222626) is **shared** with the older Flask webapp still live at `myrunner.fr` — its
"Authorization Callback Domain" (strava.com/settings/api) is registered as the **root domain
`myrunner.fr`**, which Strava treats as covering every subdomain automatically, so the old webapp,
the new Render API (`api.myrunner.fr`), and local dev (`dev.myrunner.fr`) all work simultaneously
without ever touching that setting again (Strava only allows one registered domain at a time,
which would otherwise force choosing between them). The backend exchanges the code, upserts the
`User`, and redirects to the custom scheme `myrunner://strava/callback?...` which
`flutter_web_auth_2` intercepts. JWTs (access + refresh) are **stateless** — no server-side
revocation table — validated in `app/deps.py::get_current_user`. Mobile stores tokens in
`flutter_secure_storage` (Keychain) and attaches them via a `dio` interceptor in
`core/api_client.dart` that auto-refreshes on 401.

Known limitation: no persistent-session check at launch — the app always shows the login screen
first, even with a valid JWT already in the Keychain.

### Backend (`api/app`)

Standard router → service → model layering: `routers/*.py` (HTTP layer, one file per resource:
`auth`, `activities`, `dashboard`, `settings`, `planning`) call into `services/*.py` (Strava API
calls, charge calculation, dashboard aggregation) which operate on SQLAlchemy models in
`models.py`. Not every router has a service — `planning.py` and `settings.py` are thin enough
(plain CRUD) to query the ORM directly instead.

- **`Activity.hr_data`/`velocity_data`** are `Text` columns holding full per-second JSON streams —
  large. Any query that doesn't need them (list views, dashboard aggregation) **must** use
  `.options(load_only(...))` to exclude them, or every request drags megabytes across the network
  from Supabase. This bit us once already (multi-second load times on the activities list).
- The SQLAlchemy engine (`db.py`) is created with `pool_pre_ping=True, pool_recycle=300` —
  Supabase's connection pooler (Supavisor — `DATABASE_URL` must point at it, not the direct host;
  see Production deployment above) silently drops idle connections, and without pre-ping this
  surfaces as a `psycopg2.OperationalError: server closed the connection unexpectedly` after any
  period of inactivity (e.g. the dev server sitting idle between sessions).
- `charge_load` is computed from Strava HR streams in `strava_service.py` (per-sport weighting in
  `SPORT_FACTORS`/`SPORT_TYPE_TO_GROUP`) — this is the core metric the whole app is built around
  (dashboard, activity list, planning's plan-vs-actual view).
- `sync` (recent, capped) vs `sync/full` (deletes local activities, re-fetches up to 2 years,
  ~0.5s sleep per activity between Strava calls to stay under rate limits — a full resync can take
  minutes) vs `sync/repair` (recomputes `charge_load` only where missing) are three distinct
  endpoints with different cost/completeness tradeoffs; don't conflate them.
- **`WorkoutTemplate`** rows with `user_id IS NULL` are global templates visible to every user
  (seeded by the `9eea66f3a625_seed_default_workout_templates` migration); `user_id` set = a
  user's own custom template. `planning.py` queries always `OR` the two together
  (`or_(WorkoutTemplate.user_id.is_(None), WorkoutTemplate.user_id == current_user.id)`) — keep
  that filter when adding new template queries, or per-user templates leak across accounts /
  global templates disappear.
- `PlannedWorkout.zone` (`Z1`–`Z5`, `Mixte`) is the "session type" concept end-to-end (backend and
  mobile) — the older Flask app's `EF`/`VMA`/`I`/`T`/`R` labels were **not** carried over.

### Mobile (`mobile/lib`)

Feature-first structure: `features/<name>/` holds a screen + a `*_repository.dart` (thin wrapper
around `ApiClient.instance.dio`) + a plain data model, per feature (`auth`, `activities`,
`dashboard`, `settings`, `planning`, `prepa`). `core/` holds cross-cutting infra: `api_client.dart`
(dio + JWT interceptor), `secure_storage.dart` (Keychain), `theme.dart` (design system, see
below), `app_shell.dart` (bottom nav), `coming_soon_screen.dart` (placeholder screens).

**No riverpod in practice**: `flutter_riverpod` is a dependency and `main.dart` wraps the app in
a `ProviderScope`, but no screen actually uses a `Provider`/`Consumer`/`StateNotifier` — every
screen is a plain `StatefulWidget` calling its repository directly in `initState`/callbacks and
holding results in local `setState` fields. Follow that pattern for new screens rather than
introducing riverpod providers, unless you're deliberately migrating the whole app's state
management (a bigger decision to raise with the user first).

Navigation (`app.dart`) is `go_router` with a `StatefulShellRoute.indexedStack` holding the four
bottom-nav tabs (Dashboard / Activités / Planning / Prépa, state preserved per tab); `/login` and
`/settings` live outside the shell as plain pushed routes. `prepa` (Lot 3) is still a
`ComingSoonScreen` placeholder wired into a real route so the nav shell doesn't need to change
shape once that lot lands.

**Planning (`features/planning/`)** is the most involved screen: a local segmented-button toggle
(`_PlanningView` enum, no route/query-param involved) switches between two independently-fetched
views inside the same `PlanningScreen` state —
- **Plans**: a chronological, vertically-scrollable list grouped by week then day, deliberately
  windowed to the *current + next 2 weeks only* (`_weeksShown = 3`, anchored on `_anchorWeekStart`)
  to avoid duplicating what the unbounded Activités list already shows for past sessions.
- **Calendrier**: a hand-rolled month grid (`_calendarMonth`/`_calendarGridStart/End`), not the
  `table_calendar` package floated in `instructions.MD` — it was never added as a dependency.
  Independent of the Plans window; always shows the full selected month including past days.

Both views merge **completed** `Activity` rows and **planned** `PlannedWorkout` rows for the same
date range (the "plan vs actual" comparison is the point of this tab) — `_SessionCard`/
`_CalendarSessionChip` render both through the same `sport_style.dart` icon+color convention used
on the Activités list (zone-pastel accents apply only to `PlannedWorkout` trailing badges); the
done/planned distinction comes from the trailing content (charge number vs. zone badge), not from
icon color. It's currently read/write in Plans (tap a day → place/remove a template via
`/planning/planned`) but read-only in Calendrier (no drag & drop yet).

**Design system (`core/theme.dart`)**: navy/periwinkle palette (`AppColors`) — light page background,
white cards, a fixed-color `navy` "hero" surface used for emphasized blocks (e.g. the dashboard
chart card) regardless of light/dark theme, `accentLight`/`accentDark` as the brand/button color.
The 8-hue `categoricalLight`/`categoricalDark` arrays are validated for contrast and colorblind-safe
adjacency (see the `dataviz` skill) — **fixed slot order, never reorder or reassign per filter**;
they're shared by the dashboard chart (`fl_chart`) and the activity-list sport-type badges
(`features/activities/sport_style.dart` maps raw Strava `sport_type` strings to a group/icon/slot,
mirroring the backend's `SPORT_TYPE_TO_GROUP`). Reuse existing roles from `AppColors`/`AppTheme`
(e.g. `AppTheme.cardRadius`) rather than hand-picking new colors or radii.

### Current state

Lot 0 (foundations) and Lot 1 (Auth, Activities, Dashboard, Settings) are built. Lot 2 (Planning)
is **partially** built: `WorkoutTemplate`/`PlannedWorkout` CRUD and the mobile Plans/Calendrier
views work end-to-end, but the Groq-based "AI placement" endpoint from `instructions.MD` §4
(`/planning/ai`) does not exist yet — placement is manual only (pick a date, pick a template).
Lot 3 (Prep) has its models (`PrepPlan`/`PrepWeek`) migrated but **no router, service, or mobile
screen** — `prepa` is still a `ComingSoonScreen` placeholder. Treat `README.md`'s "État
d'avancement" section as stale on these two points; this file reflects the actual code.
