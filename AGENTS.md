# Flutter & Supabase BaaS Project

This project is a Flutter application backed by Supabase Backend-as-a-Service (BaaS).

## Technology Architecture
- **Frontend**: Flutter + Dart (`dodo_universe_flutter/`)
- **Authentication**: Supabase Auth (managed via `supabase_flutter`)
- **Database**: Supabase PostgreSQL with Row Level Security (RLS)
- **Database API**: Supabase auto-generated PostgREST client
- **Server-side Logic**: Supabase Edge Functions (`supabase/functions/` in TypeScript/Deno)
- **File Storage**: Supabase Storage
- **Local / CLI Assets**: `supabase/` (config.toml, migrations, functions)

## Strict Development Rules
1. **Security Isolation**:
   - Only the public `anon` / publishable key is permitted in the Flutter client.
   - NEVER embed the `service_role` key or database connection password in Flutter code, assets, or Git.
   - Enforce Row Level Security (RLS) on all database tables.

2. **Database Schema**:
   - Write database migrations as SQL in `supabase/migrations/`.
   - Never run destructive SQL (`DROP TABLE`, `TRUNCATE`) without explicit user approval.
   - Do not create business tables until the data model is explicitly approved.

3. **Checklist After Making Changes**:
   - `flutter analyze` in `dodo_universe_flutter`
   - `flutter test` in `dodo_universe_flutter`
   - Test UI / compilation with `flutter build apk --debug`
