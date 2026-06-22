/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  // Recharge cooldowns (hours) per power kind
  // shield: 168h (7 days), reclaim: 168h (7 days), sprint: 24h (1 day)
  pgm.sql(`
    CREATE OR REPLACE FUNCTION recharge_powers()
    RETURNS void LANGUAGE plpgsql AS $$
    BEGIN
      -- Shield: recharge 1 charge every 7 days since last recharge
      UPDATE user_powers
         SET charges      = LEAST(max_charges, charges + 1),
             recharged_at = now()
       WHERE kind = 'shield'
         AND charges < max_charges
         AND recharged_at < now() - INTERVAL '7 days';

      -- Reclaim: recharge 1 charge every 7 days
      UPDATE user_powers
         SET charges      = LEAST(max_charges, charges + 1),
             recharged_at = now()
       WHERE kind = 'reclaim'
         AND charges < max_charges
         AND recharged_at < now() - INTERVAL '7 days';

      -- Sprint: recharge 1 charge every 24h
      UPDATE user_powers
         SET charges      = LEAST(max_charges, charges + 1),
             recharged_at = now()
       WHERE kind = 'sprint'
         AND charges < max_charges
         AND recharged_at < now() - INTERVAL '24 hours';
    END;
    $$;
  `)

  // Run every hour — granular enough for sprint (daily) and cheap for weekly ones
  pgm.sql(`
    SELECT cron.schedule(
      'terra-recharge-powers',
      '0 * * * *',
      'SELECT recharge_powers()'
    );
  `)
}

exports.down = (pgm) => {
  pgm.sql(`SELECT cron.unschedule('terra-recharge-powers');`)
  pgm.sql(`DROP FUNCTION IF EXISTS recharge_powers();`)
}
