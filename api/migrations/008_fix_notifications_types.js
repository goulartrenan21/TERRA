/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  // Drop the restrictive CHECK constraint and replace with open text column
  // New notification types: shield_blocked, power_earned, revenge_ready
  pgm.sql(`
    ALTER TABLE notifications
      DROP CONSTRAINT IF EXISTS notifications_type_check;
  `)

  // Add RLS policies for user_powers and power_uses (missed in 005_rls)
  pgm.sql(`
    ALTER TABLE user_powers ENABLE ROW LEVEL SECURITY;
    ALTER TABLE power_uses  ENABLE ROW LEVEL SECURITY;

    CREATE POLICY user_powers_own ON user_powers
      FOR ALL USING (user_id = auth.uid());

    CREATE POLICY power_uses_own ON power_uses
      FOR ALL USING (user_id = auth.uid());
  `)

  // Allow challenges table (used by challenges route)
  pgm.sql(`
    CREATE TABLE IF NOT EXISTS challenges (
      id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      kind       TEXT        NOT NULL,
      reward_xp  INT         NOT NULL DEFAULT 0,
      status     TEXT        NOT NULL DEFAULT 'available'
                             CHECK (status IN ('available', 'claimed', 'expired')),
      expires_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS ix_challenges_user ON challenges (user_id, created_at DESC);
    ALTER TABLE challenges ENABLE ROW LEVEL SECURITY;
    CREATE POLICY challenges_own ON challenges
      FOR ALL USING (user_id = auth.uid());
  `)
}

exports.down = (pgm) => {
  pgm.sql(`
    DROP TABLE IF EXISTS challenges;
    DROP POLICY IF EXISTS power_uses_own  ON power_uses;
    DROP POLICY IF EXISTS user_powers_own ON user_powers;
    ALTER TABLE power_uses  DISABLE ROW LEVEL SECURITY;
    ALTER TABLE user_powers DISABLE ROW LEVEL SECURITY;
    ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
      CHECK (type IN ('territory_stolen','streak_warning','kudos','level_up','capture_done'));
  `)
}
