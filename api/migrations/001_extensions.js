/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  pgm.sql(`CREATE EXTENSION IF NOT EXISTS postgis;`)
  pgm.sql(`CREATE EXTENSION IF NOT EXISTS pg_cron;`)
  pgm.sql(`CREATE EXTENSION IF NOT EXISTS "uuid-ossp";`)
}

exports.down = (pgm) => {
  pgm.sql(`DROP EXTENSION IF EXISTS pg_cron;`)
  pgm.sql(`DROP EXTENSION IF EXISTS postgis CASCADE;`)
  pgm.sql(`DROP EXTENSION IF EXISTS "uuid-ossp";`)
}
