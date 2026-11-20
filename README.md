# Mad Miners Multiplayer

Real-time multiplayer mining game. You dig down through rock, avoid hidden volcanoes and the lava at the
bottom, and try to be the first to break the hidden treasure. Each room holds 8 to 12 miners, and empty
seats are filled with players run by the server.

```
madMiners/
├── packages/mad_miners_core/   Shared game rules: map, simulation, bots, protocol (pure Dart)
├── server/                     Authoritative game server + REST API + PostgreSQL
│   └── database/migrations/    SQL schema (applied automatically at startup)
└── app/                        Flutter + Flame client (Android, iOS, macOS, Windows, Web)
```

## Run it

You need PostgreSQL 14 or newer. On macOS:

```bash
brew services start postgresql@16
createdb mad_miners

cd server && dart run bin/server.dart      # creates the tables on first run
cd app && flutter run                      # in a second terminal
```

| Setting | Default |
|---|---|
| `DATABASE_URL` | `postgresql://$USER@localhost:5432/mad_miners?sslmode=disable` |
| `PORT` | `8080` |
| `MM_GOOGLE_CLIENT_IDS` | empty (Google sign-in turned off) |

The app finds the server on its own. It tries localhost and the Android emulator address, and it listens
for the server's Wi-Fi broadcast (UDP 41234). On a real phone, keep it on the same Wi-Fi as the computer.
**Practice Offline** works with no server at all.

Tests: `dart test` in `packages/mad_miners_core` and in `server` (the PostgreSQL test uses a
`mad_miners_test` database and is skipped if it can't connect), and `flutter test` in `app`.

## The game

```
 surface camp + shop         everyone spawns here, and respawns here after dying
 soil / rock                 copper, iron, gold: coins the moment you break them
 hard rock                   diamonds, money bags, toxic gas, hidden volcanoes
 the treasure                one random spot, 1 to 3 rows above the lava
 lava sea                    instant death
```

- **The first miner to break the treasure wins, and the match ends right away.** If time runs out, the
  most coins wins.
- **Hidden volcanoes** look exactly like hard rock, even to a modified client. Break one and you die,
  then respawn at the top. The lava hardens back into rock after 25 seconds.
- **Treasure sense:** as you get close you see "faint", then "warmer, somewhere left or right", then
  "hot", and the screen edge glows. It never shows the exact tile, and nobody else sees your hints.
- **Shop (on the surface, paid with match coins):** Pickaxe (dig speed), Helmet (light and sense range),
  Boots (run speed), Armor (less blast and gas damage), Bomb (3x3 blast), Dynamite (5x5 blast).
- **Gravity:** the mine is a side view. You run, jump (clears a 1-tile ledge; better boots jump higher)
  and fall. Landing from more than about 3.5 tiles hurts. In a 1-wide shaft you can brace against both
  walls and climb back up.
- **Loose boulders** sit in the rock. Dig out the tile under one and it wobbles, then drops and hits
  whoever is below.
- **Bombs are thrown** the way you face: forward in an arc, straight up, or dropped at your feet when
  aiming down. They bounce and roll, chain-react, and the blast shoves miners (and other bombs) away.
- **Jetpack:** every miner has one. It burns fuel while firing and only refills while you stand on
  solid ground, so use it to escape a pit or cross a gap, not to fly the whole match.
- **Blocks and traps:** soft dirt near the top (1 hit), rock, hard rock, ores, loose boulders, rusty
  **spike traps** on cave floors (hurt and bounce you), red **explosive crates** (break or blast one
  and it goes off a moment later), toxic gas, lava pockets and hidden volcanoes.
- **Bombs** have a short throw cooldown, and at most 3 can be lit per miner at once.
- **Controls:** A/D or ←/→ to run, W/↑ to jump (or climb a shaft), Shift (or K) for the jetpack,
  S/↓ to aim down, Space to dig, B to throw a bomb, N for dynamite. Touch screens get a joystick plus
  dig, jump, jetpack and bomb buttons (all usable at once). In **Settings** you can resize the buttons
  or swap them to the left for left-handed play.

### Mystery Bombs

Glowing violet orbs with a metal shell hidden in the rock (more of them deeper down). They all look
the same: the rarity (Common, Rare, Epic, Legendary, Mythic) is **UNKNOWN** until opened. Dig one or
blast it and it cracks, shakes and glows for 1.8 seconds while everyone nearby watches, then bursts.
The server alone rolls the result and pays it exactly once to the miner who cracked it:

| Reward | What happens |
|---|---|
| Gold Shower, Diamond Burst | Coins (scaled by rarity) |
| Crystal Reward | Gems, credited to your account when the match ends |
| JACKPOT | Big coins + gems (much likelier from Legendary/Mythic) |
| Energy Refill | Full health, stamina and jetpack fuel |
| Explosives Cache | +2 bombs, +1 dynamite |
| Monster Surprise | A spider (or golem from Epic+) pops out where the bomb was, plus a few coins |
| Slime Prank | Harmless: you run slower for 5 seconds |
| Cursed Treasure | Lots of coins, but slow digging for 20 seconds |

### Monsters

- **Cave Spider:** fast, weak, jumps over bumps, bites, and runs away when badly hurt.
- **Stone Golem:** slow, tough, hits hard and knocks you back. More common deep down.

They patrol cave floors (turning at walls and ledges), notice miners nearby, chase and attack. Swing
your pickaxe at them (better pickaxes hit harder) or blow them up; whoever lands the last hit gets the
loot coins. Lava kills them. Bots defend themselves too.

### Zones, ores and world events

- **Zones by depth:** Starter Mine, Stone Cave, Gold Mine, Diamond Cave, Crystal Cavern, Lava
  Underground. Each zone tints the rock and shows its name next to your depth.
- **Ores:** coal, copper, iron, silver, gold, emerald, ruby, diamond and money bags, getting rarer and
  richer with depth. **Obsidian** forms a very hard crust just above the lava.
- **World events** (server-timed, every 1 to 1.5 minutes): **Gold Rush** (ore pays double for 25s),
  **Earthquake** (chunks of ceiling turn into falling rocks above miners), **Mystery Bomb Rain** (new
  Mystery Bombs appear in the rock near players). Each one gets a banner, a countdown chip and sound.

### Navigation

A **fog-of-war mini-map** (top right) shows only the tiles your light has reached: tunnels, ores,
Mystery Bombs you've found, lava, other miners (bots in blue), monsters you can currently see, and a
green arrow back to the surface shop. Your depth and current zone are always shown top left.

### Sound, vibration and settings

All sound is original and generated by `tool/gen_audio.py` (pure Python, no samples):
digging, rock breaking, coins, gems, bombs, dynamite, lava, jump, landing, jetpack, getting hurt,
victory, defeat and a music loop. Sounds are quieter the farther away they happen. Settings (saved on
the device) turn music, sound effects and vibration on or off and set the control size and side.

### Players in the room

The server fills every room up to 8 miners and never lets it go past 12. Those extra miners are
**bots, and they are always labelled**: a blue `BOT` tag over their head, in the standings and on the
results screen, and "(bot) joined" in the feed. They play by the same server rules as people (they
send inputs, the simulation validates them), are never saved to the database and never appear on the
leaderboards. Practice Offline is you against bots on your device, with no rewards.

## Money and the Locker

| Currency | Earned by | Spent on |
|---|---|---|
| Match coins | Loot during a match | Equipment and bombs, for that match only |
| Wallet coins | Your match score, added when the match ends | Miners, outfits, helmets, pickaxe skins |
| Gems (premium) | 10 for finding the treasure, 2 for a top-3 finish | Premium items |

The **Locker** has 8 miners (Rookie, Maya, Old Bahadur, Tinker, Shadow, Bolt-9, Mr. Mole, Bones),
9 outfits, 7 helmets and 9 pickaxes. You can try any item on before buying it. Most items cost coins
and a few premium ones cost gems. Each slot changes the drawn character: its own head, hands and body
details per miner, patterns per outfit, shapes per helmet, and four pickaxe head shapes (pick, axe,
mattock, drill).

**Everything in the Locker is cosmetic.** Pickaxe skins look different but dig exactly the same: the
only way to dig faster is the in-match shop, which every player starts from zero in. Nothing you buy
gives an advantage.

### Daily reward and badges

- **Daily reward:** claim once per UTC day from the lobby. Days 1 to 6 pay 50 to 175 coins, day 7 pays
  200 coins and 10 gems, then it starts over. Missing a day resets the streak. The server picks the
  day and the amount; the client only asks. A database row lock plus the unique
  `(user_id, request_id)` index make a double claim impossible.
- **Badges** (Profile → Badges): 12 achievements such as Treasure Hunter, Deep Diver and Motherlode,
  computed from the stats the server records after each match.

## Accounts and Google sign-in

There are two ways to sign in: **Guest** (just pick a name) or **Google**. A guest can link Google later
from the Profile screen and keep every coin and item.

To turn Google on:

1. In Google Cloud Console, create OAuth client IDs: one **Web** client, and one each for Android
   (with your app's SHA-1) and iOS/macOS as needed.
2. Server: `MM_GOOGLE_CLIENT_IDS=<web id>,<ios id> dart run bin/server.dart`
3. App:
   `flutter run --dart-define=MM_GOOGLE_SERVER_CLIENT_ID=<web id> --dart-define=MM_GOOGLE_CLIENT_ID=<ios id>`
4. iOS/macOS: add the reversed iOS client ID as a URL scheme in `Info.plist`.

The server checks each Google ID token's issuer, audience and expiry before it creates or loads an
account.

## Database (PostgreSQL)

| Table | What it holds |
|---|---|
| `users` | Account, username (case-insensitive unique), status |
| `auth_identities` | Sign-in methods per user (guest, google), with email when verified |
| `sessions` | SHA-256 of each access token, with expiry and last use |
| `player_stats` | XP, matches, treasures found, best score, deepest point, loot, lifetime coins |
| `wallets` | Coins and gems (a check constraint keeps them from going negative) |
| `transactions` | Every coin and gem movement, with balance after; a unique request id blocks double charges |
| `owned_cosmetics`, `equipped_cosmetics` | Locker items |
| `matches`, `match_players` | Every finished match and each person's result and reward |
| `daily_stats` | Wins and coins per day, which drives the Today leaderboard |
| `daily_rewards` | Last claimed day and streak for the daily login reward |

Rewards and purchases each run in a single transaction, so they either fully happen or don't happen at
all. Purchases lock the wallet row first.

## Architecture

**Core** (`mad_miners_core`): `GameSimulation` is the only place game rules live. The server runs it
at 30 Hz and sends 15 snapshots a second. The client uses the same physics to predict your own movement
and runs the full simulation for offline practice.

**Server** (clean architecture):

```
domain/          PlayerAccount, MatchRecord, AccountRepository (port)
application/     AuthService (guest + Google), StoreService, RoomService, GameRoom
infrastructure/  PostgresAccountRepository, InMemoryAccountRepository (tests),
                 HttpGoogleTokenVerifier, LanAnnouncer
presentation/    REST router and middleware, WebSocket handler
```

**App**, one folder per feature (`auth`, `lobby`, `game`, `store`, `profile`, `leaderboard`), each split
into `domain/` (entities, repository interfaces, use cases), `data/` (REST, WebSocket, local simulation)
and `presentation/` (Cubits, pages, widgets). The shared design system is in `app/lib/app/ui/` and
`app/lib/app/theme.dart`.

**Design system:** Lilita One for headings, numbers and buttons; Nunito for body text (both bundled
under `app/assets/fonts`, OFL licensed). Each colour has one job: gold for primary actions and coins,
teal for gems and premium, lava orange for danger, green for success and online, blue for information,
violet for brand surfaces.

## REST API (`/api/v1`)

Responses use `{"success": true, "data": ...}` or `{"success": false, "error": {"code", "message", "requestId"}}`.

| Method | Path | Purpose |
|---|---|---|
| POST | `/auth/guest` | Create a guest account and return `accessToken` |
| POST | `/auth/google` | `{idToken}`; send a guest bearer token to link instead |
| POST | `/auth/logout` | End this session |
| GET | `/players/me` | Profile, stats, wallet, Locker |
| GET | `/players/me/matches` | Match history |
| GET | `/economy/transactions` | Coin and gem history |
| GET / POST | `/rooms` | List public rooms, or create one |
| POST | `/rooms/{id}/join`, `/rooms/join-by-code`, `/matchmaking/quick` | Get a room ticket |
| GET | `/leaderboards/daily`, `/leaderboards/global` | Today's and all-time rankings |
| GET | `/store/catalog` | Locker items |
| POST | `/store/purchase` | `{itemId, requestId}`, idempotent |
| POST | `/players/me/equip` | `{itemId}` |
| GET / POST | `/rewards/daily` | See today's reward, or claim it (409 `ALREADY_CLAIMED` if done) |

Gameplay uses a WebSocket at `/ws/game?room=<id>&token=<accessToken>`.

## Troubleshooting

- **"Could not connect to PostgreSQL":** run `brew services start postgresql@16` and `createdb mad_miners`,
  or set `DATABASE_URL`.
- **"Address already in use":** an older server is still running. Stop it, or use `PORT=8081`.
- **The app can't find the server:** the server prints its Network address when it starts. Type that
  address into the server field on the login screen.

## Not done yet

- Real-money gem purchases (needs App Store / Play billing and receipt checks on the server).
- An admin dashboard, friends and chat.
- Private rooms start on the lobby countdown; there is no ready/unready toggle or "host starts the
  match" button yet.
- Tournament mode.
- From the big "3D adventure" spec, still missing: a 3D client, a walkable lobby hub, parties and
  friends, player-to-player trading, a persistent backpack/selling economy, quests and missions,
  revive-by-teammate, scanners, flashlight/oxygen gear, chat moderation tools, and a persistent shared
  world (each match is still its own mine).
- Graphics are side-view 2D (Flame), not realistic 3D. The core and server don't depend on the client, so
  a 3D client could reuse them.
