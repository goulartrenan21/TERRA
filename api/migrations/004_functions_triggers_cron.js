/**
 * @type {import('node-pg-migrate').MigrationBuilder}
 */
exports.up = (pgm) => {
  // ── Trigger: updated_at automático ─────────────────────────────────────────
  pgm.sql(`
    CREATE OR REPLACE FUNCTION set_updated_at()
    RETURNS TRIGGER LANGUAGE plpgsql AS $$
    BEGIN
      NEW.updated_at = now();
      RETURN NEW;
    END;
    $$;
  `)

  pgm.sql(`
    CREATE TRIGGER trg_users_updated_at
      BEFORE UPDATE ON users
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  `)

  pgm.sql(`
    CREATE TRIGGER trg_ranking_updated_at
      BEFORE UPDATE ON ranking_entries
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  `)

  pgm.sql(`
    CREATE TRIGGER trg_devices_updated_at
      BEFORE UPDATE ON devices
      FOR EACH ROW EXECUTE FUNCTION set_updated_at();
  `)

  // ── Função: calcular área km² de um polígono GeoJSON ──────────────────────
  pgm.sql(`
    CREATE OR REPLACE FUNCTION territory_area_km2(geom GEOMETRY)
    RETURNS NUMERIC(12,6) LANGUAGE sql IMMUTABLE AS $$
      SELECT ROUND((ST_Area(geom::geography) / 1e6)::NUMERIC, 6);
    $$;
  `)

  // ── Função: decaimento diário de territórios ───────────────────────────────
  pgm.sql(`
    CREATE OR REPLACE FUNCTION decay_territories()
    RETURNS void LANGUAGE plpgsql AS $$
    DECLARE
      expired_count INTEGER;
      decayed_count INTEGER;
    BEGIN
      -- Territórios sem defesa há > 21 dias → expiram (viram neutros)
      WITH expired AS (
        DELETE FROM territories
        WHERE defended_at < now() - INTERVAL '21 days'
        RETURNING id
      )
      SELECT count(*) INTO expired_count FROM expired;

      -- Territórios sem defesa há > 7 dias → freshness diminui 10%
      UPDATE territories
      SET freshness = GREATEST(0.0, freshness - 0.10)
      WHERE defended_at < now() - INTERVAL '7 days'
        AND defended_at >= now() - INTERVAL '21 days';

      GET DIAGNOSTICS decayed_count = ROW_COUNT;

      RAISE NOTICE 'decay_territories: expired=%, decayed=%', expired_count, decayed_count;
    END;
    $$;
  `)

  // ── Função: verificar streak do usuário ────────────────────────────────────
  pgm.sql(`
    CREATE OR REPLACE FUNCTION check_streak(p_user_id UUID)
    RETURNS TABLE(streak_days INT, freeze_used BOOLEAN) LANGUAGE plpgsql AS $$
    DECLARE
      v_last_date DATE;
      v_streak    INT;
      v_freezes   INT;
      v_today     DATE := CURRENT_DATE;
    BEGIN
      SELECT last_active_date, streak_days, streak_freezes
        INTO v_last_date, v_streak, v_freezes
        FROM users
       WHERE id = p_user_id;

      IF v_last_date IS NULL OR v_last_date < v_today - 2 THEN
        -- Streak quebrado (perdeu 2+ dias)
        UPDATE users SET streak_days = 1, last_active_date = v_today WHERE id = p_user_id;
        RETURN QUERY SELECT 1, false;

      ELSIF v_last_date = v_today - 1 THEN
        -- Dia seguinte — incrementa streak
        UPDATE users
          SET streak_days = streak_days + 1, last_active_date = v_today
        WHERE id = p_user_id;
        RETURN QUERY SELECT v_streak + 1, false;

      ELSIF v_last_date = v_today - 2 AND v_freezes > 0 THEN
        -- Perdeu um dia mas tem freeze — usa freeze
        UPDATE users
          SET streak_days = streak_days + 1,
              streak_freezes = streak_freezes - 1,
              last_active_date = v_today
        WHERE id = p_user_id;
        RETURN QUERY SELECT v_streak + 1, true;

      ELSIF v_last_date = v_today THEN
        -- Já fez check-in hoje
        RETURN QUERY SELECT v_streak, false;

      ELSE
        -- Sem freeze disponível, streak quebrado
        UPDATE users SET streak_days = 1, last_active_date = v_today WHERE id = p_user_id;
        RETURN QUERY SELECT 1, false;
      END IF;
    END;
    $$;
  `)

  // ── Função: upsert ranking entry ───────────────────────────────────────────
  pgm.sql(`
    CREATE OR REPLACE FUNCTION upsert_ranking(
      p_user_id         UUID,
      p_neighborhood_id UUID,
      p_area_delta      NUMERIC(12,6),
      p_territory_delta INTEGER
    ) RETURNS void LANGUAGE plpgsql AS $$
    DECLARE
      v_week_start DATE := date_trunc('week', CURRENT_DATE)::DATE;
      v_week_end   DATE := v_week_start + 6;
    BEGIN
      INSERT INTO ranking_entries
        (user_id, neighborhood_id, window_start, window_end, total_area_km2, territory_count)
      VALUES
        (p_user_id, p_neighborhood_id, v_week_start, v_week_end, GREATEST(0, p_area_delta), GREATEST(0, p_territory_delta))
      ON CONFLICT (user_id, neighborhood_id, window_start)
      DO UPDATE SET
        total_area_km2  = GREATEST(0, ranking_entries.total_area_km2 + p_area_delta),
        territory_count = GREATEST(0, ranking_entries.territory_count + p_territory_delta),
        updated_at      = now();
    END;
    $$;
  `)

  // ── pg_cron: decaimento diário às 03:00 BRT (06:00 UTC) ───────────────────
  pgm.sql(`
    SELECT cron.schedule(
      'terra-decay-territories',
      '0 6 * * *',
      'SELECT decay_territories()'
    );
  `)

  // ── pg_cron: streak warning às 20:00 BRT (23:00 UTC) ─────────────────────
  pgm.sql(`
    CREATE OR REPLACE FUNCTION notify_streak_at_risk()
    RETURNS void LANGUAGE plpgsql AS $$
    DECLARE
      r RECORD;
    BEGIN
      FOR r IN
        SELECT id
          FROM users
         WHERE last_active_date = CURRENT_DATE - 1
           AND streak_days >= 3
      LOOP
        INSERT INTO notifications (user_id, type, payload)
        VALUES (r.id, 'streak_warning', json_build_object(
          'streakDays', (SELECT streak_days FROM users WHERE id = r.id),
          'hoursLeft', 4
        ));
      END LOOP;
    END;
    $$;
  `)

  pgm.sql(`
    SELECT cron.schedule(
      'terra-streak-warning',
      '0 23 * * *',
      'SELECT notify_streak_at_risk()'
    );
  `)
}

exports.down = (pgm) => {
  pgm.sql(`SELECT cron.unschedule('terra-streak-warning');`)
  pgm.sql(`SELECT cron.unschedule('terra-decay-territories');`)

  pgm.sql(`DROP FUNCTION IF EXISTS notify_streak_at_risk();`)
  pgm.sql(`DROP FUNCTION IF EXISTS upsert_ranking(UUID, UUID, NUMERIC, INTEGER);`)
  pgm.sql(`DROP FUNCTION IF EXISTS check_streak(UUID);`)
  pgm.sql(`DROP FUNCTION IF EXISTS decay_territories();`)
  pgm.sql(`DROP FUNCTION IF EXISTS territory_area_km2(GEOMETRY);`)

  pgm.sql(`DROP TRIGGER IF EXISTS trg_devices_updated_at  ON devices;`)
  pgm.sql(`DROP TRIGGER IF EXISTS trg_ranking_updated_at  ON ranking_entries;`)
  pgm.sql(`DROP TRIGGER IF EXISTS trg_users_updated_at    ON users;`)
  pgm.sql(`DROP FUNCTION IF EXISTS set_updated_at();`)
}
