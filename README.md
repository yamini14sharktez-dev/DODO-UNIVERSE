# DODO Universe

DODO Universe is built on a modern **Flutter + Supabase BaaS** architecture.

## Architecture

- **Frontend (`dodo_universe_flutter`)**: Cross-platform Flutter application for iOS, Android, Web, and Desktop.
- **Backend & Database (`supabase/`)**:
  - **Supabase Auth**: User authentication, sessions, and social logins.
  - **Supabase PostgreSQL**: Scalable relational database secured by Row Level Security (RLS).
  - **Supabase APIs**: Auto-generated RESTful (PostgREST) and GraphQL APIs.
  - **Supabase Edge Functions**: Serverless TypeScript/Deno functions for complex business logic and third-party integrations.
  - **Supabase Storage**: Secure object storage for media, images, and user files.

## Project Structure

```
DODO-Uni/
│
├── dodo_universe_flutter/     # Flutter client application
│   ├── lib/
│   │   ├── core/
│   │   │   ├── config/        # Environment configurations (Dev, Staging, Prod)
│   │   │   └── supabase/      # Supabase client singleton & initialization
│   │   ├── screens/           # UI views & feature screens
│   │   └── main.dart          # Application entry point
│   ├── android/               # Android platform project
│   ├── ios/                   # iOS platform project
│   └── pubspec.yaml
│
├── supabase/                  # Supabase configurations & database assets
│   ├── migrations/            # SQL migration files
│   ├── functions/             # Supabase Edge Functions (Deno/TypeScript)
│   └── config.toml            # Supabase CLI project configuration
│
├── .env.example               # Environment variables template
├── .gitignore                 # Version control ignore rules
├── AGENTS.md                  # Development guidelines for AI assistants
├── PROJECT_GUIDE.md           # Comprehensive project guide & workflows
└── README.md                  # Project overview
```

## Getting Started

### Prerequisites

- Flutter SDK (Channel stable)
- Dart SDK (bundled with Flutter)
- Android Studio / Android SDK

### Running the Flutter Client

```powershell
cd dodo_universe_flutter
flutter pub get
flutter run -d chrome
# Or targeting an Android device:
flutter run -d android
```

See [PROJECT_GUIDE.md](file:///C:/DODO-Uni/PROJECT_GUIDE.md) for full configuration, security standards, and workflow details.
