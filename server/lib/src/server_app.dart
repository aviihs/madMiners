import 'package:shelf/shelf.dart';

import 'application/auth_service.dart';
import 'application/room_service.dart';
import 'domain/repositories/account_repository.dart';
import 'presentation/http/api_router.dart';
import 'presentation/http/middleware.dart';
import 'presentation/ws/game_socket_handler.dart';

/// Composition root: wires adapters -> services -> handlers.
class ServerApp {
  ServerApp(this.accounts, {bool autoStartRooms = true})
    : auth = AuthService(accounts),
      rooms = RoomService(accounts, autoStart: autoStartRooms);

  final AccountRepository accounts;
  final AuthService auth;
  final RoomService rooms;

  Handler get handler {
    final api = ApiRouter(auth, rooms, accounts).router;
    final ws = GameSocketHandler(auth, rooms).handler;
    final httpPipeline = const Pipeline()
        .addMiddleware(cors())
        .addMiddleware(errorHandling())
        .addMiddleware(rateLimit())
        .addHandler(api.call);
    return (Request req) => req.url.path == 'ws/game' ? ws(req) : httpPipeline(req);
  }
}
