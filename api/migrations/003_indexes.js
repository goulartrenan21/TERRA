/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  // Spatial indexes (PostGIS GIST) — críticos para ST_Intersects e ST_Within
  pgm.sql(`CREATE INDEX idx_territories_geom ON territories USING GIST(geom);`)
  pgm.sql(`CREATE INDEX idx_activities_path  ON activities  USING GIST(path);`)

  // Query indexes
  pgm.sql(`CREATE INDEX idx_territories_owner    ON territories(owner_id);`)
  pgm.sql(`CREATE INDEX idx_territories_defended ON territories(defended_at);`)

  pgm.sql(`CREATE INDEX idx_activities_user ON activities(user_id, started_at DESC);`)
  pgm.sql(`CREATE INDEX idx_activities_status ON activities(status) WHERE status = 'processing';`)

  pgm.sql(`CREATE INDEX idx_samples_activity ON activity_samples(activity_id, recorded_at);`)

  pgm.sql(`CREATE INDEX idx_notifications_user_unread ON notifications(user_id, created_at DESC) WHERE read = false;`)

  pgm.sql(`CREATE INDEX idx_ranking_neighborhood_window ON ranking_entries(neighborhood_id, window_start DESC);`)
  pgm.sql(`CREATE INDEX idx_ranking_user ON ranking_entries(user_id);`)

  pgm.sql(`CREATE INDEX idx_devices_user ON devices(user_id);`)

  pgm.sql(`CREATE INDEX idx_territory_events_territory ON territory_events(territory_id, created_at DESC);`)
  pgm.sql(`CREATE INDEX idx_territory_events_activity  ON territory_events(activity_id);`)
}

exports.down = (pgm) => {
  pgm.sql(`DROP INDEX IF EXISTS idx_territories_geom;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_activities_path;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_territories_owner;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_territories_defended;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_activities_user;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_activities_status;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_samples_activity;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_notifications_user_unread;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_ranking_neighborhood_window;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_ranking_user;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_devices_user;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_territory_events_territory;`)
  pgm.sql(`DROP INDEX IF EXISTS idx_territory_events_activity;`)
}
