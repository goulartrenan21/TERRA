/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  // ── USERS ──────────────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE users (
      id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      email             TEXT        UNIQUE NOT NULL,
      display_name      TEXT        NOT NULL,
      avatar_url        TEXT,
      xp                INTEGER     NOT NULL DEFAULT 0,
      level             INTEGER     NOT NULL DEFAULT 1,
      streak_days       INTEGER     NOT NULL DEFAULT 0,
      streak_freezes    INTEGER     NOT NULL DEFAULT 2,
      last_active_date  DATE,
      neighborhood_id   UUID,
      privacy_zones     JSONB       NOT NULL DEFAULT '[]',
      created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
      updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `)

  // ── ACTIVITIES ─────────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE activities (
      id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      path        GEOMETRY(LINESTRING, 4326) NOT NULL,
      distance_m  NUMERIC(10,2),
      duration_s  INTEGER,
      avg_pace    NUMERIC(6,2),
      elevation_m NUMERIC(8,2),
      status      TEXT        NOT NULL DEFAULT 'processing'
                              CHECK (status IN ('processing', 'done', 'failed')),
      started_at  TIMESTAMPTZ NOT NULL,
      ended_at    TIMESTAMPTZ,
      created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `)

  // ── ACTIVITY_SAMPLES ───────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE activity_samples (
      id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      activity_id UUID        NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
      lat         NUMERIC(10,8) NOT NULL,
      lng         NUMERIC(11,8) NOT NULL,
      accuracy_m  NUMERIC(6,2),
      speed_ms    NUMERIC(6,2),
      altitude_m  NUMERIC(8,2),
      recorded_at TIMESTAMPTZ NOT NULL
    );
  `)

  // ── TERRITORIES ────────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE territories (
      id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      owner_id    UUID        REFERENCES users(id) ON DELETE SET NULL,
      geom        GEOMETRY(POLYGON, 4326) NOT NULL,
      area_km2    NUMERIC(12,6) NOT NULL,
      freshness   NUMERIC(5,2) NOT NULL DEFAULT 1.0 CHECK (freshness >= 0 AND freshness <= 1),
      captured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      defended_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `)

  // ── TERRITORY_EVENTS ───────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE territory_events (
      id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      territory_id UUID        NOT NULL REFERENCES territories(id) ON DELETE CASCADE,
      activity_id  UUID        NOT NULL REFERENCES activities(id),
      event_type   TEXT        NOT NULL CHECK (event_type IN ('captured', 'stolen', 'reinforced', 'decayed', 'expired')),
      old_owner_id UUID        REFERENCES users(id) ON DELETE SET NULL,
      new_owner_id UUID        REFERENCES users(id) ON DELETE SET NULL,
      area_km2     NUMERIC(12,6),
      created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `)

  // ── RANKING_ENTRIES ────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE ranking_entries (
      id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id          UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      neighborhood_id  UUID        NOT NULL,
      window_start     DATE        NOT NULL,
      window_end       DATE        NOT NULL,
      total_area_km2   NUMERIC(12,6) NOT NULL DEFAULT 0,
      territory_count  INTEGER     NOT NULL DEFAULT 0,
      updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE(user_id, neighborhood_id, window_start)
    );
  `)

  // ── NOTIFICATIONS ──────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE notifications (
      id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      type       TEXT        NOT NULL CHECK (type IN (
                               'territory_stolen', 'streak_warning',
                               'kudos', 'level_up', 'capture_done'
                             )),
      payload    JSONB       NOT NULL DEFAULT '{}',
      read       BOOLEAN     NOT NULL DEFAULT false,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `)

  // ── DEVICES (FCM / APNs) ───────────────────────────────────────────────────
  pgm.sql(`
    CREATE TABLE devices (
      id         UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
      user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      token      TEXT        NOT NULL,
      platform   TEXT        NOT NULL CHECK (platform IN ('android', 'ios')),
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE(token)
    );
  `)
}

exports.down = (pgm) => {
  pgm.sql(`DROP TABLE IF EXISTS devices CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS notifications CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS ranking_entries CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS territory_events CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS territories CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS activity_samples CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS activities CASCADE;`)
  pgm.sql(`DROP TABLE IF EXISTS users CASCADE;`)
}
