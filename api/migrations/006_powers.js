/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  pgm.sql(`
    DO $$ BEGIN
      CREATE TYPE power_kind AS ENUM ('shield', 'reclaim', 'sprint', 'roots', 'freshness', 'revenge');
    EXCEPTION WHEN duplicate_object THEN NULL;
    END $$;
  `)

  pgm.sql(`
    CREATE TABLE IF NOT EXISTS user_powers (
      user_id      UUID       REFERENCES users(id) ON DELETE CASCADE,
      kind         power_kind NOT NULL,
      charges      INT        NOT NULL DEFAULT 0,
      max_charges  INT        NOT NULL DEFAULT 1,
      armed        BOOLEAN    NOT NULL DEFAULT false,
      recharged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, kind),
      CONSTRAINT charges_range CHECK (charges BETWEEN 0 AND max_charges)
    );
  `)

  pgm.sql(`
    CREATE TABLE IF NOT EXISTS power_uses (
      id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id        UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      kind           power_kind  NOT NULL,
      activity_id    UUID        REFERENCES activities(id) ON DELETE SET NULL,
      target_user_id UUID        REFERENCES users(id),
      outcome        TEXT,
      area_km2       NUMERIC(12,4),
      used_at        TIMESTAMPTZ NOT NULL DEFAULT now()
    );
    CREATE INDEX IF NOT EXISTS ix_power_uses_user   ON power_uses (user_id, used_at DESC);
    CREATE INDEX IF NOT EXISTS ix_power_uses_target ON power_uses (target_user_id, used_at DESC);
  `)
}

exports.down = (pgm) => {
  pgm.sql(`
    DROP TABLE IF EXISTS power_uses;
    DROP TABLE IF EXISTS user_powers;
    DROP TYPE IF EXISTS power_kind;
  `)
}
