import 'package:shelf/shelf.dart';

import 'application/auth_service.dart';
import 'application/google_token_verifier.dart';
import 'application/room_service.dart';
import 'application/store_service.dart';
import 'domain/repositories/account_repository.dart';
import 'presentation/http/api_router.dart';
import 'presentation/http/middleware.dart';
import 'presentation/ws/game_socket_handler.dart';

/// Composition root: wires adapters -> services -> handlers.
class ServerApp {
  ServerApp(this.accounts, {required GoogleTokenVerifier google, bool autoStartRooms = true})
    : auth = AuthService(accounts, google),
      rooms = RoomService(accounts, autoStart: autoStartRooms),
      store = StoreService(accounts);

  final AccountRepository accounts;
  final AuthService auth;
  final RoomService rooms;
  final StoreService store;

  Handler get handler {
    final api = ApiRouter(auth, rooms, accounts, store).router;
    final ws = GameSocketHandler(auth, rooms).handler;
    final httpPipeline = const Pipeline()
        .addMiddleware(cors())
        .addMiddleware(errorHandling())
        .addMiddleware(rateLimit())
        .addHandler(api.call);
    return (Request req) => req.url.path == 'ws/game' ? ws(req) : httpPipeline(req);
  }
}
