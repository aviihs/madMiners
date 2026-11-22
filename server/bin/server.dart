import 'dart:async';
import 'dart:io';

import 'package:mad_miners_server/mad_miners_server.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  // Store data next to the server package, wherever it's launched from.
  final serverDir = p.dirname(p.dirname(p.fromUri(Platform.script)));
  final user = Platform.environment['USER'] ?? 'postgres';
  final dbUrl = Platform.environment['DATABASE_URL'] ?? 'postgresql://$user@localhost:5432/mad_miners?sslmode=disable';
  // A compiled binary (Docker / Render) can't find the folder by itself.
  final migrations = Platform.environment['MM_MIGRATIONS_DIR'] ?? p.join(serverDir, 'database', 'migrations');
  // Wi-Fi discovery only makes sense on a home / event network, not in the cloud.
  final lanDiscovery = Platform.environment['MM_LAN_DISCOVERY'] != 'off';

  await runZonedGuarded(() async {
    final PostgresAccountRepository db;
    try {
      db = await PostgresAccountRepository.open(dbUrl, migrationsDir: migrations);
    } catch (e) {
      stderr
        ..writeln('\nCould not connect to PostgreSQL at ${_redact(dbUrl)}')
        ..writeln('  $e')
        ..writeln('  Start it (brew services start postgresql@16), create the database (createdb mad_miners),')
        ..writeln('  or point DATABASE_URL at your server.\n');
      exit(1);
    }
    final google = HttpGoogleTokenVerifier.fromEnvironment();
    final app = ServerApp(db, google: google);
    final handler = const Pipeline().addMiddleware(logRequests()).addHandler(app.handler);

    final HttpServer server;
    try {
      server = await io.serve(handler, InternetAddress.anyIPv4, port);
    } on SocketException catch (e) {
      stderr.writeln('\nCould not start on port $port: ${e.osError?.message ?? e.message}');
      stderr.writeln('  Another server is probably still running. Stop it (Ctrl+C in its terminal,');
      stderr.writeln('  or: kill \$(lsof -t -i:$port)), or use another port: PORT=8081 dart run bin/server.dart\n');
      exit(1);
    }

    final announcer = LanAnnouncer(httpPort: server.port);
    if (lanDiscovery) await announcer.start();

    final lan = await _lanAddresses();
    stdout
      ..writeln('Mad Miners server running')
      ..writeln('   Local:   http://localhost:${server.port}')
      ..writeln([for (final a in lan) '   Network: http://$a:${server.port}   (use this on a real phone)'].join('\n'))
      ..writeln('   DB:      ${_redact(dbUrl)}')
      ..writeln('   Google:  ${google.isConfigured ? 'enabled' : 'off (set MM_GOOGLE_CLIENT_IDS)'}')
      ..writeln(lanDiscovery ? '   Phones on the same Wi-Fi find this server automatically.' : '   LAN discovery: off')
      ..writeln('   Press Ctrl+C to stop.');

    var stopping = false;
    Future<void> shutdown(ProcessSignal _) async {
      if (stopping) return;
      stopping = true;
      stdout.writeln('\nShutting down…');
      announcer.stop();
      app.rooms.shutdown();
      await db.close();
      await server.close(force: true);
      exit(0);
    }

    ProcessSignal.sigint.watch().listen(shutdown);
    // Hosts like Render stop the old instance with SIGTERM on every deploy.
    if (!Platform.isWindows) ProcessSignal.sigterm.watch().listen(shutdown);
  }, (error, stack) {
    // Never let one bad connection take the whole server down.
    stderr.writeln('[unhandled] $error\n$stack');
  });
}

String _redact(String url) => url.replaceAll(RegExp(r':[^:@/]+@'), ':***@');

Future<List<String>> _lanAddresses() async {
  try {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final i in ifaces)
        for (final a in i.addresses)
          if (!a.isLoopback) a.address,
    ];
  } catch (_) {
    return const [];
  }
}
