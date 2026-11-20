-- Daily login reward: one claim per UTC day, with a 7-day streak.
CREATE TABLE daily_rewards (
  user_id   uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_day  date NOT NULL,
  streak    integer NOT NULL CHECK (streak >= 1)
);
