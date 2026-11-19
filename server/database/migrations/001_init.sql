-- Mad Miners core schema (SRS §7).

CREATE TABLE users (
  id          uuid PRIMARY KEY,
  username    varchar(24) NOT NULL,
  status      varchar(16) NOT NULL DEFAULT 'active',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_username_ci ON users (lower(username));

-- One user can sign in several ways (guest device token, Google, ...).
CREATE TABLE auth_identities (
  id          bigserial PRIMARY KEY,
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider    varchar(16) NOT NULL,
  subject     varchar(255) NOT NULL,
  email       varchar(320),
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (provider, subject)
);
CREATE INDEX auth_identities_user ON auth_identities (user_id);

-- Bearer sessions. Only the SHA-256 of the token is stored.
CREATE TABLE sessions (
  token_hash    char(64) PRIMARY KEY,
  user_id       uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at    timestamptz NOT NULL DEFAULT now(),
  last_used_at  timestamptz NOT NULL DEFAULT now(),
  expires_at    timestamptz NOT NULL
);
CREATE INDEX sessions_user ON sessions (user_id);

CREATE TABLE player_stats (
  user_id       uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  xp            bigint NOT NULL DEFAULT 0,
  games_played  integer NOT NULL DEFAULT 0,
  wins          integer NOT NULL DEFAULT 0,      -- treasures found
  best_score    integer NOT NULL DEFAULT 0,
  best_depth    integer NOT NULL DEFAULT 0,
  ores_mined    bigint NOT NULL DEFAULT 0,
  total_coins   bigint NOT NULL DEFAULT 0       -- lifetime coins earned
);

CREATE TABLE wallets (
  user_id  uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  coins    bigint NOT NULL DEFAULT 0 CHECK (coins >= 0),
  gems     bigint NOT NULL DEFAULT 0 CHECK (gems >= 0)
);

-- Every coin/gem movement, for audit (SRS §7.5).
CREATE TABLE transactions (
  id             bigserial PRIMARY KEY,
  user_id        uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  kind           varchar(24) NOT NULL,           -- match_reward | purchase | grant
  currency       varchar(8) NOT NULL,            -- coins | gems
  amount         bigint NOT NULL,                -- + credit, - debit
  balance_after  bigint NOT NULL,
  reference      varchar(128),
  request_id     varchar(64),
  created_at     timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX transactions_user_time ON transactions (user_id, created_at DESC);
-- A retried purchase can never be applied twice.
CREATE UNIQUE INDEX transactions_request ON transactions (user_id, request_id) WHERE request_id IS NOT NULL;

CREATE TABLE owned_cosmetics (
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_id      varchar(48) NOT NULL,
  acquired_at  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, item_id)
);

CREATE TABLE equipped_cosmetics (
  user_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  slot     varchar(16) NOT NULL,
  item_id  varchar(48) NOT NULL,
  PRIMARY KEY (user_id, slot)
);

CREATE TABLE matches (
  id                uuid PRIMARY KEY,
  room_code         varchar(12),
  map_id            varchar(24) NOT NULL,
  mode              varchar(24) NOT NULL,
  started_at        timestamptz NOT NULL,
  ended_at          timestamptz NOT NULL DEFAULT now(),
  duration_seconds  integer NOT NULL,
  player_count      integer NOT NULL,
  winner_user_id    uuid REFERENCES users(id) ON DELETE SET NULL,
  winner_name       varchar(32)
);
CREATE INDEX matches_ended ON matches (ended_at DESC);

-- Human participants only.
CREATE TABLE match_players (
  match_id        uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rank            integer NOT NULL,
  score           integer NOT NULL,
  ores            integer NOT NULL,
  xp              integer NOT NULL,
  max_depth       integer NOT NULL,
  found_treasure  boolean NOT NULL DEFAULT false,
  coins_awarded   integer NOT NULL,
  gems_awarded    integer NOT NULL,
  PRIMARY KEY (match_id, user_id)
);
CREATE INDEX match_players_user ON match_players (user_id);

CREATE TABLE daily_stats (
  user_id  uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  day      date NOT NULL,
  wins     integer NOT NULL DEFAULT 0,
  coins    bigint NOT NULL DEFAULT 0,
  games    integer NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);
CREATE INDEX daily_stats_rank ON daily_stats (day, wins DESC, coins DESC);
