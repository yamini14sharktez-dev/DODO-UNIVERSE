import 'package:serverpod/serverpod.dart';

class WelcomeEndpoint extends Endpoint {
  /// Simple welcome endpoint per Phase 0 specification.
  Future<String> getWelcomeMessage(Session session) async {
    return 'Welcome to DODO Universe. Backend connection successful.';
  }

  /// Verifies PostgreSQL database connectivity separately from API connectivity.
  Future<String> checkDatabase(Session session) async {
    try {
      final result = await session.db.unsafeQuery('SELECT version();');
      final version = result.firstOrNull?.firstOrNull?.toString() ?? 'PostgreSQL connected';
      return 'Supabase PostgreSQL connected successfully. Version: $version';
    } catch (e) {
      session.log('Database check failed: $e', level: LogLevel.error);
      return 'Database connection failed: $e';
    }
  }
}

