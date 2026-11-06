# DODO Universe

DODO Universe is built on a clean full-stack Dart architecture featuring a Flutter client application, a Dart Serverpod backend, and a Supabase-managed PostgreSQL database.

## Architecture

- **Frontend (`dodo_universe_flutter`)**: Cross-platform Flutter application (Mobile, Desktop, Web).
- **Backend (`dodo_universe_server`)**: Robust Dart Serverpod API server with strong typing and ORM.
- **Client Protocol (`dodo_universe_client`)**: Automatically generated type-safe client library bridging Flutter and Serverpod.
- **Database**: Supabase PostgreSQL with SSL encryption.

## Getting Started

See [PROJECT_GUIDE.md](file:///C:/DODO-Uni/PROJECT_GUIDE.md) for full setup, environment configuration, database connectivity, and verification workflows.

### Prerequisites

- Flutter SDK (Channel stable)
- Dart SDK (bundled with Flutter)
- Serverpod CLI (`dart pub global activate serverpod_cli`)
- Git

### Quick Run

1. **Start the Backend:**
   ```powershell
   cd dodo_universe_server
   dart bin/main.dart --mode development
   ```

2. **Run the Flutter Client:**
   ```powershell
   cd dodo_universe_flutter
   flutter run -d chrome
   ```

