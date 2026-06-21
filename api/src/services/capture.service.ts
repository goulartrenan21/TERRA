import { db } from '../lib/db'
import { cleanPolyline, type Point } from '../lib/geo/polyline'
import { detectLoops, isValidLoop } from '../lib/geo/loops'
import { notifyUser } from '../lib/ws'
import { sendTerritoryStolen } from './push.service'
import type { CaptureJobData, CaptureResult, CapturedArea, StolenArea, GeoPolygon } from '@terra/shared'

// ─── XP ──────────────────────────────────────────────────────────────────────

export function calculateXP(areaKm2: number, isSteal: boolean): number {
  const base  = Math.round(areaKm2 * 1000) // 1 XP per 1000 m²
  const bonus = isSteal ? Math.round(base * 0.5) : 0
  return base + bonus
}

// XP(n) = 100 × n^1.5 — returns new level
export function computeLevel(totalXp: number): number {
  let level = 1
  while (100 * Math.pow(level + 1, 1.5) <= totalXp) level++
  return level
}

// ─── Spoofing guard ──────────────────────────────────────────────────────────

const MAX_SPEED_MS     = 15.28 // 55 km/h
const MIN_LOOP_AREA    = 0.01  // km²

// ─── Main service ─────────────────────────────────────────────────────────────

export class CaptureService {
  async process(job: CaptureJobData): Promise<CaptureResult> {
    const { activityId, userId, polyline } = job
    const rawPoints = polyline.coordinates as Point[]

    // A — Clean polyline
    const points = cleanPolyline(rawPoints)

    // B — Detect loops
    const loops = detectLoops(points)
    const validLoops = loops.filter((l) => isValidLoop(l.polygon))

    const capturedAreas: CapturedArea[] = []
    const stolenFrom:    StolenArea[]   = []
    let totalXpGained = 0

    // C — Process each valid loop
    for (const loop of validLoops) {
      const geojsonPolygon = JSON.stringify({
        type: 'Polygon',
        coordinates: [loop.polygon],
      })

      const result = await this._processLoop(userId, activityId, geojsonPolygon)
      capturedAreas.push(...result.captured)
      stolenFrom.push(...result.stolen)
      totalXpGained += result.xpGained
    }

    // D — Update user XP + level
    const { newLevel, leveledUp } = await this._applyXP(userId, totalXpGained)

    // E — Update ranking
    if (capturedAreas.length > 0 || stolenFrom.length > 0) {
      const totalArea = capturedAreas.reduce((s, a) => s + a.areaKm2, 0)
      await this._updateRanking(userId, totalArea, capturedAreas.length)
    }

    // F — Update streak
    const streakUpdated = await this._checkinStreak(userId)

    // G — Mark activity done
    await db.query(
      `UPDATE activities SET status = 'done' WHERE id = $1`,
      [activityId],
    )

    // H — Notify owners whose territory was stolen
    if (stolenFrom.length > 0) {
      const attackerName = await this._getDisplayName(userId)
      for (const stolen of stolenFrom) {
        await db.query(
          `INSERT INTO notifications (user_id, type, payload)
           VALUES ($1, 'territory_stolen', $2)`,
          [
            stolen.fromUserId,
            JSON.stringify({
              territoryId:   stolen.territoryId,
              byUserId:      userId,
              byDisplayName: attackerName,
              areaKm2:       stolen.areaKm2,
            }),
          ],
        )
        sendTerritoryStolen(stolen.fromUserId, attackerName, stolen.areaKm2).catch(console.error)
      }
    }

    const result: CaptureResult = {
      activityId,
      capturedAreas,
      stolenFrom,
      xpGained:       totalXpGained,
      newLevel,
      leveledUp,
      streakUpdated,
    }

    // I — WebSocket notification
    notifyUser(userId, { type: 'capture_done', payload: result })

    return result
  }

  // ─── Process one loop against existing territories ─────────────────────────

  private async _processLoop(
    userId: string,
    activityId: string,
    geojsonPolygon: string,
  ): Promise<{ captured: CapturedArea[]; stolen: StolenArea[]; xpGained: number }> {
    const captured: CapturedArea[] = []
    const stolen:   StolenArea[]   = []
    let xpGained = 0

    // Geodesic area in km²
    const { rows: areaRows } = await db.query<{ area_km2: number }>(
      `SELECT ST_Area(ST_GeomFromGeoJSON($1)::geography) / 1e6 AS area_km2`,
      [geojsonPolygon],
    )
    const totalAreaKm2 = parseFloat(String(areaRows[0].area_km2))

    if (totalAreaKm2 < MIN_LOOP_AREA) return { captured, stolen, xpGained }

    // Find all territories that intersect this polygon
    const { rows: intersecting } = await db.query<{
      id: string
      owner_id: string | null
      geom_json: string
      intersection_area: number
    }>(
      `SELECT
         t.id,
         t.owner_id,
         ST_AsGeoJSON(t.geom)::text                                    AS geom_json,
         ST_Area(ST_Intersection(t.geom, ST_GeomFromGeoJSON($1))::geography) / 1e6
                                                                        AS intersection_area
       FROM territories t
       WHERE ST_Intersects(t.geom, ST_GeomFromGeoJSON($1))`,
      [geojsonPolygon],
    )

    const client = await db.connect()
    try {
      await client.query('BEGIN')

      for (const territory of intersecting) {
        const intersectedArea = parseFloat(String(territory.intersection_area))
        if (intersectedArea < 0.001) continue

        if (territory.owner_id === userId) {
          // Reinforce own territory → refresh defended_at + freshness
          await client.query(
            `UPDATE territories
             SET defended_at = now(), freshness = 1.0
             WHERE id = $1`,
            [territory.id],
          )
          await client.query(
            `INSERT INTO territory_events (territory_id, activity_id, event_type, new_owner_id, area_km2)
             VALUES ($1, $2, 'reinforced', $3, $4)`,
            [territory.id, activityId, userId, intersectedArea],
          )
        } else if (territory.owner_id !== null) {
          // Steal from enemy — compute what remains after intersection
          const { rows: diffRows } = await client.query<{ diff_area: number; diff_geom: string | null }>(
            `SELECT
               ST_Area(ST_Difference(t.geom, ST_GeomFromGeoJSON($2))::geography) / 1e6 AS diff_area,
               CASE
                 WHEN ST_IsEmpty(ST_Difference(t.geom, ST_GeomFromGeoJSON($2))) THEN NULL
                 ELSE ST_AsGeoJSON(ST_Difference(t.geom, ST_GeomFromGeoJSON($2)))
               END AS diff_geom
             FROM territories t
             WHERE t.id = $1`,
            [territory.id, geojsonPolygon],
          )

          const remainingArea = parseFloat(String(diffRows[0].diff_area))

          if (remainingArea < 0.001 || !diffRows[0].diff_geom) {
            // Territory fully consumed
            await client.query(`DELETE FROM territories WHERE id = $1`, [territory.id])
          } else {
            // Shrink enemy territory
            await client.query(
              `UPDATE territories
               SET geom = ST_GeomFromGeoJSON($2), area_km2 = $3
               WHERE id = $1`,
              [territory.id, diffRows[0].diff_geom, remainingArea],
            )
          }

          await client.query(
            `INSERT INTO territory_events
               (territory_id, activity_id, event_type, old_owner_id, new_owner_id, area_km2)
             VALUES ($1, $2, 'stolen', $3, $4, $5)`,
            [territory.id, activityId, territory.owner_id, userId, intersectedArea],
          )

          stolen.push({
            territoryId:     territory.id,
            fromUserId:      territory.owner_id,
            fromDisplayName: '', // filled below after commit
            areaKm2:         intersectedArea,
          })

          xpGained += calculateXP(intersectedArea, true)
        }
      }

      // Compute neutral area = polygon - union of all existing territories
      const { rows: neutralRows } = await client.query<{ neutral_geom: string | null; neutral_area: number }>(
        `SELECT
           CASE
             WHEN EXISTS (SELECT 1 FROM territories WHERE ST_Intersects(geom, ST_GeomFromGeoJSON($1)))
             THEN ST_AsGeoJSON(
               ST_Difference(
                 ST_GeomFromGeoJSON($1),
                 (SELECT ST_Union(geom) FROM territories WHERE ST_Intersects(geom, ST_GeomFromGeoJSON($1)))
               )
             )
             ELSE $1
           END AS neutral_geom,
           CASE
             WHEN EXISTS (SELECT 1 FROM territories WHERE ST_Intersects(geom, ST_GeomFromGeoJSON($1)))
             THEN ST_Area(
               ST_Difference(
                 ST_GeomFromGeoJSON($1),
                 (SELECT ST_Union(geom) FROM territories WHERE ST_Intersects(geom, ST_GeomFromGeoJSON($1)))
               )::geography
             ) / 1e6
             ELSE ST_Area(ST_GeomFromGeoJSON($1)::geography) / 1e6
           END AS neutral_area`,
        [geojsonPolygon],
      )

      const neutralArea = parseFloat(String(neutralRows[0].neutral_area))
      const neutralGeom = neutralRows[0].neutral_geom

      if (neutralArea >= 0.001 && neutralGeom) {
        const { rows: insertedRows } = await client.query<{ id: string }>(
          `INSERT INTO territories (owner_id, geom, area_km2, freshness)
           VALUES ($1, ST_GeomFromGeoJSON($2), $3, 1.0)
           RETURNING id`,
          [userId, neutralGeom, neutralArea],
        )
        await client.query(
          `INSERT INTO territory_events (territory_id, activity_id, event_type, new_owner_id, area_km2)
           VALUES ($1, $2, 'captured', $3, $4)`,
          [insertedRows[0].id, activityId, userId, neutralArea],
        )
        captured.push({
          territoryId: insertedRows[0].id,
          areaKm2:     neutralArea,
          geom:        JSON.parse(neutralGeom) as GeoPolygon,
        })
        xpGained += calculateXP(neutralArea, false)
      }

      await client.query('COMMIT')
    } catch (err) {
      await client.query('ROLLBACK')
      throw err
    } finally {
      client.release()
    }

    // Resolve display names for stolen territories
    if (stolen.length > 0) {
      const ownerIds = [...new Set(stolen.map((s) => s.fromUserId))]
      const { rows: nameRows } = await db.query<{ id: string; display_name: string }>(
        `SELECT id, display_name FROM users WHERE id = ANY($1)`,
        [ownerIds],
      )
      const nameMap = Object.fromEntries(nameRows.map((r) => [r.id, r.display_name]))
      stolen.forEach((s) => { s.fromDisplayName = nameMap[s.fromUserId] ?? 'Unknown' })
    }

    return { captured, stolen, xpGained }
  }

  // ─── Apply XP to user ──────────────────────────────────────────────────────

  private async _applyXP(userId: string, xpGained: number): Promise<{ newLevel: number; leveledUp: boolean }> {
    if (xpGained === 0) {
      const { rows } = await db.query<{ level: number }>('SELECT level FROM users WHERE id = $1', [userId])
      return { newLevel: rows[0].level, leveledUp: false }
    }

    const { rows } = await db.query<{ xp: number; level: number }>(
      `UPDATE users SET xp = xp + $2 WHERE id = $1 RETURNING xp, level`,
      [userId, xpGained],
    )
    const newLevel = computeLevel(rows[0].xp)
    const leveledUp = newLevel > rows[0].level

    if (leveledUp) {
      await db.query(`UPDATE users SET level = $2 WHERE id = $1`, [userId, newLevel])
      await db.query(
        `INSERT INTO notifications (user_id, type, payload) VALUES ($1, 'level_up', $2)`,
        [userId, JSON.stringify({ newLevel, xp: rows[0].xp })],
      )
    }

    return { newLevel, leveledUp }
  }

  // ─── Streak checkin ────────────────────────────────────────────────────────

  private async _checkinStreak(userId: string): Promise<boolean> {
    const { rows } = await db.query<{ streak_days: number }>(
      `SELECT streak_days FROM check_streak($1)`,
      [userId],
    )
    return rows[0].streak_days > 0
  }

  // ─── Ranking upsert ────────────────────────────────────────────────────────

  private async _updateRanking(userId: string, areaKm2: number, territoryDelta: number): Promise<void> {
    const { rows } = await db.query<{ neighborhood_id: string | null }>(
      `SELECT neighborhood_id FROM users WHERE id = $1`,
      [userId],
    )
    if (!rows[0]?.neighborhood_id) return

    await db.query(
      `SELECT upsert_ranking($1, $2, $3, $4)`,
      [userId, rows[0].neighborhood_id, areaKm2, territoryDelta],
    )
  }

  // ─── Helper ───────────────────────────────────────────────────────────────

  private async _getDisplayName(userId: string): Promise<string> {
    const { rows } = await db.query<{ display_name: string }>(
      `SELECT display_name FROM users WHERE id = $1`,
      [userId],
    )
    return rows[0]?.display_name ?? 'Unknown'
  }
}
