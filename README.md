# Mad Miners Multiplayer

Real-time multiplayer mining game: **Flutter + Flame** client (Android, iOS, Windows, macOS, Web),
**authoritative Dart server**, and a **shared pure-Dart game core**.
Dig down through rock, avoid the lava at the bottom, and be the **first to break the hidden treasure**.
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

Screenshots without a device (renders login, lobby and an in-game frame to PNG):
```bash
cd app && flutter test test/screenshots --dart-define=SHOTS=/tmp/shots \
  --dart-define=FONTS=$HOME/flutter/bin/cache/artifacts/material_fonts \
  --dart-define=CI_FONT=$(ls -d ~/.pub-cache/hosted/pub.dev/cupertino_icons-*/ | tail -1)assets/CupertinoIcons.ttf
```

## How it plays: Treasure Hunt

```
 surface camp + SHOP           ← everyone spawns here (and respawns after dying)
 ── soil / rock ───────────────  dig down, grab copper / iron / gold (coins right away)
 ── hard rock ─────────────────  diamonds, money bags, toxic gas,
                                  HIDDEN VOLCANOES (look like normal rock!)
 ── 💎 hidden treasure ────────  random spot, 1–3 rows above the lava
 ── LAVA SEA ──────────────────  instant death, back to the top
```

- **Break rock to go down.** Loot pays coins instantly.
- **Hidden volcanoes:** some deep rocks are volcanoes and look exactly like normal rock, even to a
  hacked client. Break one and it erupts: you die and respawn at the top, and anyone nearby gets
  burned. The lava hardens back into rock after 25 seconds.
- **Treasure sense (hints):** deeper down your helmet "senses" the treasure. You'll see
  *Faint glimmer…*, then *Warmer · somewhere left/right*, then *HOT!*, and the screen edge glows gold.
  It never shows the exact tile. Better helmets sense from farther away. Hints are sent only to you.
- **The first to break the treasure wins and the match ends.** If time runs out, the most coins wins.
- **Shop (on the surface)**, paid with match coins:
  Pickaxe (dig speed) · Helmet (light + sense range) · Boots (run speed) · Armor (less blast/gas damage)
  · **Bomb** (blows up 3×3, 25¢) · **Dynamite** (5×5, 70¢). Bombs collect any loot they blow up,
  set off volcanoes, chain-react, and hurt miners nearby, including you.
- Controls: WASD/arrows move · Space dig · **B** bomb · **N** dynamite. Touch: joystick, dig button, bomb buttons.

## Money, gems & cosmetics

| Currency | How you get it | What it buys |
|---|---|---|
| Match coins | Loot during a match | Equipment and bombs (that match only) |
| Wallet coins | Everything you earned in a match is added after it ends | Outfits, helmets, pickaxe skins |
| 💎 Gems (premium) | +10 for finding the treasure, +2 for a top-3 finish (real-money packs can come later) | Premium cosmetics |

**Locker** (Lobby → Locker): try items on a live preview of your miner, then buy or wear them.
There are 8 outfits, 6 helmets (hard hat, crown, viking, prospector…) and 5 pickaxe skins.
Everyone sees what you wear in the match. Cosmetics never change gameplay. Purchases are checked and
applied on the server, and a retried purchase (same `requestId`) is never charged twice.

**Leaderboard:** the **Today** tab ranks by treasures found today, then coins (resets every day).
The **All Time** tab ranks by lifetime coins.

## Bots (they look like real players)

- Each room fills up to 8 miners and never goes past 12. When a real person joins, the shallowest bot leaves.
- Bots have ordinary Nepali-style usernames (`Sagar_07`, `Bikash.np`, `Aayush99`…) and no BOT tag.
  The server never sends who's a bot: `isBot` is always `false` on the wire, including in results.
  Only the server knows (it's kept for persistence, analytics and moderation, and bots are never
  saved as accounts or put on the leaderboard).
- Matches open with a **7-second lobby**: "Finding miners… 4/8" while bots join one by one, then 3‑2‑1.
  Bots walk around the camp during the lobby, sometimes hesitate while digging, and have different
  skill levels.
- Bots don't know where the treasure is. They dig down along their own lane, never walk into lava,
  grab loot they can see, and only go for the treasure once it's revealed and close.
- If you'd rather tell players about bots (some stores and regions expect it), set
  `disguiseBots: false` in `GameSimulation`.

## Troubleshooting: "server didn't connect"

- **The app finds the server by itself:** it tries localhost, the Android emulator address, and listens
  for the server's Wi‑Fi broadcast (UDP 41234). If the dot stays red, tap **Search again**.
- The server must be running: `curl localhost:8080/health` → `{"success":true,...}`.
  **Restart it after pulling new code** (Ctrl+C, then `dart run bin/server.dart`).
- `Address already in use`: an old server is still running. Stop it, or kill it with
  `kill $(lsof -t -i:8080)`, or run on another port with `PORT=8081`.
- At startup the server prints a **Network** address. Use that on a real phone (same Wi-Fi).
  The login screen shows a green "Online" dot once it can reach the server.
- macOS app: needs the `com.apple.security.network.client` entitlement (already added).
- Android: emulator → `http://10.0.2.2:8080`; real phone → `http://<your-PC-LAN-IP>:8080` (same Wi-Fi).
  Cleartext HTTP and the INTERNET permission are enabled for dev builds.
- iOS: `NSAllowsArbitraryLoads` is on for dev. Use HTTPS/WSS in production.

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
| GET | `/leaderboards/global` | Top 50 all-time |
| GET | `/leaderboards/daily` | Today's top 50 (most treasure finds) |
| GET | `/store/catalog` | Cosmetics with prices |
| POST | `/store/purchase` | `{itemId, requestId}` → idempotent purchase |
| POST | `/players/me/equip` | `{itemId}` → wear an owned item |
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
