/**
 * Row Level Security — todas as tabelas protegidas.
 * A API usa service_role (bypassa RLS); o app mobile usa anon/authenticated.
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  const tables = [
    'users',
    'activities',
    'activity_samples',
    'territories',
    'territory_events',
    'ranking_entries',
    'notifications',
    'devices',
  ]

  // Habilitar RLS em todas as tabelas
  for (const table of tables) {
    pgm.sql(`ALTER TABLE ${table} ENABLE ROW LEVEL SECURITY;`)
  }

  // ── users ──────────────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE POLICY users_select_own ON users
      FOR SELECT USING (id = auth.uid());
  `)
  pgm.sql(`
    CREATE POLICY users_update_own ON users
      FOR UPDATE USING (id = auth.uid());
  `)
  // Perfis públicos (display_name, avatar_url) são lidos via API, não direto

  // ── activities ─────────────────────────────────────────────────────────────
  pgm.sql(`
    CREATE POLICY activities_select_own ON activities
      FOR SELECT USING (user_id = auth.uid());
  `)
  pgm.sql(`
    CREATE POLICY activities_insert_own ON activities
      FOR INSERT WITH CHECK (user_id = auth.uid());
  `)

  // ── activity_samples ───────────────────────────────────────────────────────
  pgm.sql(`
    CREATE POLICY samples_own ON activity_samples
      FOR ALL USING (
        activity_id IN (
          SELECT id FROM activities WHERE user_id = auth.uid()
        )
      );
  `)

  // ── territories — leitura pública, escrita via service_role ───────────────
  pgm.sql(`
    CREATE POLICY territories_select_all ON territories
      FOR SELECT USING (true);
  `)

  // ── territory_events — leitura pública ────────────────────────────────────
  pgm.sql(`
    CREATE POLICY territory_events_select_all ON territory_events
      FOR SELECT USING (true);
  `)

  // ── ranking_entries — leitura pública ─────────────────────────────────────
  pgm.sql(`
    CREATE POLICY ranking_select_all ON ranking_entries
      FOR SELECT USING (true);
  `)

  // ── notifications — próprias ───────────────────────────────────────────────
  pgm.sql(`
    CREATE POLICY notifications_own ON notifications
      FOR ALL USING (user_id = auth.uid());
  `)

  // ── devices — próprios ────────────────────────────────────────────────────
  pgm.sql(`
    CREATE POLICY devices_own ON devices
      FOR ALL USING (user_id = auth.uid());
  `)
}

exports.down = (pgm) => {
  const tables = [
    'users', 'activities', 'activity_samples', 'territories',
    'territory_events', 'ranking_entries', 'notifications', 'devices',
  ]

  const policies = [
    ['users',             'users_select_own'],
    ['users',             'users_update_own'],
    ['activities',        'activities_select_own'],
    ['activities',        'activities_insert_own'],
    ['activity_samples',  'samples_own'],
    ['territories',       'territories_select_all'],
    ['territory_events',  'territory_events_select_all'],
    ['ranking_entries',   'ranking_select_all'],
    ['notifications',     'notifications_own'],
    ['devices',           'devices_own'],
  ]

  for (const [table, policy] of policies) {
    pgm.sql(`DROP POLICY IF EXISTS ${policy} ON ${table};`)
  }

  for (const table of tables) {
    pgm.sql(`ALTER TABLE ${table} DISABLE ROW LEVEL SECURITY;`)
  }
}
