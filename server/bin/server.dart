import 'dart:io';

import 'package:mad_miners_server/mad_miners_server.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;

Future<void> main() async {
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 8080;
  final dataFile = Platform.environment['MM_DATA_FILE'] ?? 'data/accounts.json';

  final app = ServerApp(await JsonFileAccountRepository.open(dataFile));
  final handler = const Pipeline().addMiddleware(logRequests()).addHandler(app.handler);
  final server = await io.serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('Mad Miners server on http://${server.address.host}:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    stdout.writeln('Shutting down…');
    app.rooms.shutdown();
    await server.close(force: true);
    exit(0);
  });
}
