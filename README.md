# Mad Miners Multiplayer

Real-time multiplayer mining game: **Flutter + Flame** client (Android, iOS, Windows, macOS, Web),
**authoritative Dart server**, and a **shared pure-Dart game core**.
Rooms hold **8–12 miners**, and **bots fill the empty seats** when there aren't enough people.

```
madMiners/
├── packages/mad_miners_core/   Shared domain: rules, balance, map gen, simulation, bot AI, protocol
├── server/                     Dart server: REST /api/v1 + WebSocket /ws/game (server-authoritative)
└── app/                        Flutter client (clean architecture, feature-first)
```

## Run it

```bash
# 1. Server (port 8080; accounts are saved to server/data/accounts.json)
cd server && dart run bin/server.dart

# 2. Client (in another terminal)
cd app && flutter run            # -d macos / chrome / windows / <device id>
```

- Android emulator: the server URL defaults to `http://10.0.2.2:8080`. On a real phone, use your computer's LAN IP.
- You can also bake in a URL: `flutter run --dart-define=MM_SERVER=http://192.168.1.20:8080`.
- **Offline practice** works with no server: the whole simulation (with 7 bots) runs on the device.

Tests: `dart test` in `packages/mad_miners_core` and `server`, `flutter test` in `app`.

## How it plays

Dig down from the surface camp, mine ore (Copper → Iron → Gold → Diamond → Mystic Crystal, rarer the
deeper you go), and carry it back to the **depot** to sell it automatically. Spend coins at the depot on
pickaxes (up to the Laser Drill), backpacks, oxygen tanks and helmets. Below the oxygen line your air
drains. Lava, toxic gas and darkness can all knock you out, and you lose whatever ore you're carrying.

Modes: **Mining Competition** (most coins wins), **Team Mining** (2 crews), **Free Mining**.
Maps: **Starter Mine**, **Crystal Cave**, **Lava Mine**.

Controls: WASD/arrows to move, Space/J to mine. Touch devices get a joystick and a mine button.

## Bots

- `botsNeeded(settings, humans)` tops the room up to `minPlayers` (8) and never goes past `maxPlayers` (12).
- When a human joins, the lowest-scoring bot leaves. When a human leaves, a bot comes back. A room with no humans shuts down.
- Bots only send `PlayerInput`s, so the server validates them exactly like humans (no cheating).
  They use Dijkstra "dig-paths" to pick the most valuable ore for the effort, go home when they're full,
  low on air or hurt, and buy upgrades. They're labelled **[BOT]** in game.

## Architecture

**Shared core** (`mad_miners_core`, no Flutter or IO): `GameSimulation` is the single source of truth for rules.
The server runs it at 30 Hz and sends snapshots at 15 Hz. The client uses the same `Physics` to predict
your own movement, and runs the whole simulation for offline mode.

**Server** (clean architecture):
```
domain/          PlayerAccount, AccountRepository (port)
application/     AuthService, RoomService (matchmaking/rooms), GameRoom (tick loop, reconnect, rate limits)
infrastructure/  JsonFileAccountRepository  ← swap for PostgreSQL without touching the layers above
presentation/    REST router + middleware (error envelope, CORS, rate limit), WebSocket handler
```

**App**, one folder per feature (`auth`, `lobby`, `leaderboard`, `game`), each split into:
```
domain/        entities, repository interfaces, use cases   (no Flutter, no HTTP)
data/          data sources (REST, WebSocket, local sim), repository implementations
presentation/  Cubits, pages, widgets; game/ also has the Flame components + GameController
```
`GameSession` is the key abstraction: `RemoteGameSession` (WebSocket, auto-reconnect) and
`LocalGameSession` (on-device sim) are interchangeable, so the game UI doesn't know which one it's using.
DI lives in `app/lib/app/di.dart` (get_it).

### REST API (`/api/v1`, `{success, data}` / `{success:false, error:{code,message,requestId}}`)
| Method | Path | |
|---|---|---|
| POST | `/auth/guest` | Create guest account → `accessToken` |
| GET | `/players/me` | Profile, level, lifetime coins |
| GET / POST | `/rooms` | List public rooms / create room (`mapId, gameMode, maxPlayers 8–12, isPrivate`) |
| GET | `/rooms/{id}` | Room info |
| POST | `/rooms/{id}/join`, `/rooms/join-by-code` | Get a ticket (`wsPath`) |
| POST | `/matchmaking/quick` | Best open public room, or a new one filled with bots |
| GET | `/leaderboards/global` | Top 50 |
| GET | `/catalog` | Ores, upgrades, maps, modes |

WebSocket: `GET /ws/game?room=<id>&token=<accessToken>`. JSON frames are defined in `core/lib/src/protocol/messages.dart`.

### SRS requirements covered
Server-authoritative movement, mining range, speed and stamina validation (NFR-011/012/013, §12.1).
Purchases validated server-side and only allowed at the depot. 60 s reconnect window that keeps your
miner and inventory (FR-017/019, §5.4). Private rooms are code-gated (FR-020). Hashed tokens (NFR-009).
REST and per-socket rate limits (NFR-014). Atomic file writes. Balance numbers live in one config file (§11.4).

### Not done yet / next steps
- Rendering is **top-down 2D (Flame)**, not realistic 3D. Flutter isn't built for UE5-level 3D.
  The core and server are engine-agnostic, so a 3D client could reuse them later.
- Swap the JSON-file repository for PostgreSQL + Redis; add email login, friends, missions,
  admin tools, real payments and TLS (`wss://`) for production.
