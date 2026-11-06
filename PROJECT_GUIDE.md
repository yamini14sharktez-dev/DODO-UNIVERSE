# DODO Universe Project Guide

## 1. Project Architecture

The project follows the official Serverpod three-package structure:

```
C:\DODO-Uni\
├── dodo_universe_flutter/    # Flutter application (Frontend)
│   ├── lib/
│   │   ├── core/config/      # Multi-environment configuration (Dev, Staging, Prod)
│   │   ├── screens/          # UI views & feature screens
│   │   ├── client.dart       # Serverpod client initialization
│   │   └── main.dart         # Flutter entry point
│   └── pubspec.yaml
├── dodo_universe_server/     # Dart Serverpod Backend
│   ├── bin/main.dart         # Backend entry point
│   ├── config/               # Server & database environment configs
│   │   ├── development.yaml
│   │   ├── staging.yaml
│   │   ├── production.yaml
│   │   └── passwords.yaml    # Secret credentials (GIT-IGNORED)
│   ├── lib/src/endpoints/    # Serverpod API endpoints
│   └── pubspec.yaml
└── dodo_universe_client/     # Generated API client & serialization protocols
    └── lib/
```

## 2. Environment Configuration Strategy

### Backend Configuration (`dodo_universe_server/config/`)
Serverpod uses YAML configurations selected at startup via the `--mode` flag:
- `development.yaml` (Mode: `development`)
- `staging.yaml` (Mode: `staging`)
- `production.yaml` (Mode: `production`)

Sensitive values (such as database passwords and service keys) are kept in `config/passwords.yaml` or provided via environment variables (`SERVERPOD_PASSWORDS`). **`config/passwords.yaml` is strictly ignored by Git.**

### Frontend Configuration (`dodo_universe_flutter/lib/core/config/`)
The Flutter client accesses the backend API exclusively through the Serverpod generated client. Flutter never connects directly to PostgreSQL and never possesses database credentials or Supabase service-role keys.

Environment switching is managed via `--dart-define=ENVIRONMENT=development` (or staging/production).

## 3. Supabase PostgreSQL Integration

- **Host & Port**: Supabase provides either a direct host (port 5432) or a session pooler host (port 5432 / 6543). For networks without native IPv6 routing, the **Session Pooler** (IPv4 compatible) is recommended.
- **SSL**: `requireSsl: true` is strictly enforced for all Supabase connections.
- **Connection Limits**: Managed inside `config/development.yaml` to prevent pool exhaustion.

## 4. Development Workflow & Commands

### Code Generation
Whenever you add or modify an endpoint or a `.spy.yaml` model in `dodo_universe_server`:
```powershell
cd dodo_universe_server
serverpod generate
```

### Database Migrations
To create and apply migrations with Serverpod:
```powershell
cd dodo_universe_server
serverpod create-migration
dart bin/main.dart --apply-migrations --mode development
```

### Running Backend
```powershell
cd dodo_universe_server
dart bin/main.dart --mode development
```

### Running Flutter App
```powershell
cd dodo_universe_flutter
flutter run -d chrome
# Or targeting Windows desktop:
flutter run -d windows
# Or targeting Android emulator:
flutter run -d emulator-5554
```

## 5. Security Principles

1. **Backend-Only Database Access**: PostgreSQL is only queried by the Serverpod server.
2. **Zero Client Secrets**: No DB passwords, JWT secret keys, or service-role tokens in the Flutter app.
3. **SSL/TLS Everywhere**: Enforced database SSL and HTTPS for staging/production API endpoints.
4. **Git Hygiene**: Credentials, `.env`, and `passwords.yaml` are barred from commits.

