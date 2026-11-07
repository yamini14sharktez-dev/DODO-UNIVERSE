# DODO Universe Project Guide

## 1. Project Architecture

DODO Universe uses a **Pure Supabase BaaS** architecture backed by a **Flutter** client:

```
DODO-Uni/
├── dodo_universe_flutter/     # Flutter client application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/        # Environment configurations (AppConfig)
│   │   │   └── supabase/      # SupabaseManager singleton & initialization
│   │   ├── screens/           # UI screens (including Phase0Screen verification)
│   │   └── main.dart          # App entry point
│   └── pubspec.yaml
└── supabase/                  # Supabase configurations & backend logic
    ├── config.toml            # Project CLI configuration (Project ID: swivkawtnqymvymjxlpl)
    ├── migrations/            # SQL migration scripts
    └── functions/             # Supabase Edge Functions (Deno / TypeScript)
```

---

## 2. Supabase Services & Foundation

- **Project ID**: `swivkawtnqymvymjxlpl`
- **Region**: `ap-south-1` (Mumbai)
- **Project URL**: `https://swivkawtnqymvymjxlpl.supabase.co`
- **Database Engine**: PostgreSQL 17 (Managed by Supabase)

### Core BaaS Components
1. **Supabase Auth**: Manages user registration, sign-in, JWT session lifecycle, password resets, and OAuth providers.
2. **PostgreSQL & Row Level Security (RLS)**: Direct data access via Supabase's auto-generated PostgREST APIs. All tables must enforce RLS policies to restrict read/write operations by user identity (`auth.uid()`).
3. **Supabase Storage**: Secure bucket storage for user uploads, media, and assets, protected with storage RLS policies.
4. **Supabase Edge Functions**: Serverless TypeScript/Deno functions deployed to Supabase for secure server-side logic (e.g. payment webhooks, external API aggregations, admin tasks).

---

## 3. Environment & Configuration Strategy

### Frontend (`dodo_universe_flutter/lib/core/config/app_config.dart`)
Configuration is maintained via `AppConfig` supporting three environments:
- `Development`
- `Staging`
- `Production`

Runtime variables are passed at build or run time using `--dart-define`:
```powershell
flutter run --dart-define=ENVIRONMENT=development --dart-define=SUPABASE_ANON_KEY=your_publishable_anon_key
```

### Security Isolation Rules
- **NEVER** place the Supabase `service_role` key into Flutter.
- **NEVER** expose the database password in mobile code or version control.
- **ALWAYS** use the public `anon` (publishable) key for Flutter client operations.
- **ALWAYS** enforce Row Level Security on every table created in PostgreSQL.

---

## 4. Development & Testing Commands

### Dependency Resolution
```powershell
cd dodo_universe_flutter
flutter pub get
```

### Static Analysis
```powershell
cd dodo_universe_flutter
flutter analyze
```

### Running Tests
```powershell
cd dodo_universe_flutter
flutter test
```

### Building Android APK
```powershell
cd dodo_universe_flutter
flutter build apk --debug
```

### Running the App
```powershell
cd dodo_universe_flutter
# Chrome (Web)
flutter run -d chrome
# Android
flutter run -d android
```
