import { db } from '../lib/db'
import { cleanPolyline, type Point } from '../lib/geo/polyline'
import { detectLoops, isValidLoop } from '../lib/geo/loops'
import { notifyUser } from '../lib/ws'
import { sendTerritoryStolen } from './push.service'
import type { CaptureJobData, CaptureResult, CapturedArea, StolenArea, GeoPolygon, PowerKind, PowerApplied } from '@terra/shared'

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
    const { activityId, userId, polyline, powersArmed = [] } = job
    const rawPoints = polyline.coordinates as Point[]
    const powersApplied: PowerApplied[] = []

    // A — Clean polyline
    const points = cleanPolyline(rawPoints)

    // B — Detect loops
    const loops = detectLoops(points)
    const validLoops = loops.filter((l) => isValidLoop(l.polygon))

    const capturedAreas: CapturedArea[] = []
    const stolenFrom:    StolenArea[]   = []
    let totalXpGained = 0

    const hasSprint  = powersArmed.includes('sprint')
    const hasReclaim = powersArmed.includes('reclaim')

    // C — Consume attacker's armed charges for active powers
    if (powersArmed.length > 0) {
      await this._consumeArmedPowers(userId, powersArmed)
    }

    // D — Check passive revenge: did any of the victims steal from attacker in last 48h?
    const revengeTargets = await this._getRevengeTargets(userId)

    // E — Process each valid loop
    for (const loop of validLoops) {
      const geojsonPolygon = JSON.stringify({
        type: 'Polygon',
        coordinates: [loop.polygon],
      })

      const result = await this._processLoop(
        userId, activityId, geojsonPolygon,
        { hasSprint, hasReclaim, revengeTargets, powersApplied },
      )
      capturedAreas.push(...result.captured)
      stolenFrom.push(...result.stolen)
      totalXpGained += result.xpGained
    }

    // F — Update user XP + level
    const { newLevel, leveledUp } = await this._applyXP(userId, totalXpGained)

    // G — Update ranking
    if (capturedAreas.length > 0 || stolenFrom.length > 0) {
      const totalArea = capturedAreas.reduce((s, a) => s + a.areaKm2, 0)
      await this._updateRanking(userId, totalArea, capturedAreas.length)
    }

    // H — Update streak
    const streakUpdated = await this._checkinStreak(userId)

    // I — Mark activity scored
    await db.query(
      `UPDATE activities SET status = 'scored' WHERE id = $1`,
      [activityId],
    )

    // J — Log power uses
    for (const applied of powersApplied) {
      await db.query(
        `INSERT INTO power_uses (user_id, kind, activity_id, target_user_id, outcome, area_km2)
         VALUES ($1, $2, $3, $4, $5, $6)`,
        [userId, applied.kind, activityId, applied.targetUserId ?? null, applied.outcome, applied.areaKm2 ?? null],
      )
    }

    // K — Notify owners whose territory was stolen
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
      xpGained:     totalXpGained,
      newLevel,
      leveledUp,
      streakUpdated,
      powersApplied,
    }

    // L — WebSocket notification
    notifyUser(userId, { type: 'capture_done', payload: result })

    return result
  }

  // ─── Process one loop against existing territories ─────────────────────────

  private async _processLoop(
    userId: string,
    activityId: string,
    geojsonPolygon: string,
    powers: {
      hasSprint: boolean
      hasReclaim: boolean
      revengeTargets: Set<string>
      powersApplied: PowerApplied[]
    },
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
          // Check if victim has an armed shield
          const shieldBlocked = await this._checkAndConsumeShield(territory.owner_id, userId, activityId)
          if (shieldBlocked) {
            powers.powersApplied.push({
              kind: 'shield',
              outcome: 'shield_blocked',
              targetUserId: territory.owner_id,
              areaKm2: intersectedArea,
            })
            continue
          }

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

          // Revenge bonus: +50% area if victim stole from attacker in last 48h
          let effectiveArea = intersectedArea
          if (powers.revengeTargets.has(territory.owner_id)) {
            effectiveArea = intersectedArea * 1.5
            powers.powersApplied.push({
              kind: 'revenge',
              outcome: 'revenge_bonus',
              targetUserId: territory.owner_id,
              areaKm2: effectiveArea - intersectedArea,
            })
          }

          // Sprint: 2x captured area
          if (powers.hasSprint) {
            effectiveArea = effectiveArea * 2
          }

          stolen.push({
            territoryId:     territory.id,
            fromUserId:      territory.owner_id,
            fromDisplayName: '', // filled below after commit
            areaKm2:         effectiveArea,
          })

          xpGained += calculateXP(effectiveArea, true)
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
        // Sprint: 2x area on neutral captures too
        const effectiveNeutralArea = powers.hasSprint ? neutralArea * 2 : neutralArea

        const { rows: insertedRows } = await client.query<{ id: string }>(
          `INSERT INTO territories (owner_id, geom, area_km2, freshness)
           VALUES ($1, ST_GeomFromGeoJSON($2), $3, 1.0)
           RETURNING id`,
          [userId, neutralGeom, effectiveNeutralArea],
        )
        await client.query(
          `INSERT INTO territory_events (territory_id, activity_id, event_type, new_owner_id, area_km2)
           VALUES ($1, $2, 'captured', $3, $4)`,
          [insertedRows[0].id, activityId, userId, effectiveNeutralArea],
        )
        captured.push({
          territoryId: insertedRows[0].id,
          areaKm2:     effectiveNeutralArea,
          geom:        JSON.parse(neutralGeom) as GeoPolygon,
        })
        xpGained += calculateXP(effectiveNeutralArea, false)

        if (powers.hasSprint && effectiveNeutralArea > neutralArea) {
          powers.powersApplied.push({
            kind: 'sprint',
            outcome: 'sprint_doubled',
            areaKm2: effectiveNeutralArea - neutralArea,
          })
        }
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

      // Grant Reconquista at level 3
      if (newLevel >= 3 && rows[0].level < 3) {
        await db.query(
          `INSERT INTO user_powers (user_id, kind, charges, max_charges, recharged_at)
           VALUES ($1, 'reclaim', 1, 1, now())
           ON CONFLICT (user_id, kind) DO UPDATE
             SET charges = LEAST(user_powers.max_charges, user_powers.charges + 1),
                 recharged_at = now()`,
          [userId],
        )
        await db.query(
          `INSERT INTO notifications (user_id, type, payload)
           VALUES ($1, 'power_earned', $2)`,
          [userId, JSON.stringify({ kind: 'reclaim', level: newLevel })],
        )
      }
    }

    return { newLevel, leveledUp }
  }

  // ─── Streak checkin ────────────────────────────────────────────────────────

  private async _checkinStreak(userId: string): Promise<boolean> {
    const { rows } = await db.query<{ streak_days: number; freeze_used: boolean }>(
      `SELECT streak_days, freeze_used FROM check_streak($1)`,
      [userId],
    )
    const { streak_days } = rows[0]

    // Grant shield at every 7-day milestone (7, 14, 21 …)
    if (streak_days > 0 && streak_days % 7 === 0) {
      await db.query(
        `INSERT INTO user_powers (user_id, kind, charges, max_charges, recharged_at)
         VALUES ($1, 'shield', 1, 1, now())
         ON CONFLICT (user_id, kind) DO UPDATE
           SET charges = LEAST(user_powers.max_charges, user_powers.charges + 1),
               recharged_at = now()`,
        [userId],
      )
      await db.query(
        `INSERT INTO notifications (user_id, type, payload)
         VALUES ($1, 'power_earned', $2)`,
        [userId, JSON.stringify({ kind: 'shield', streak_days })],
      )
    }

    return streak_days > 0
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

  // ─── Powers helpers ───────────────────────────────────────────────────────

  private async _consumeArmedPowers(userId: string, powers: PowerKind[]): Promise<void> {
    for (const kind of powers) {
      await db.query(
        `UPDATE user_powers
           SET charges = charges - 1, armed = false, recharged_at = now()
           WHERE user_id = $1 AND kind = $2 AND armed = true AND charges > 0`,
        [userId, kind],
      )
    }
  }

  private async _checkAndConsumeShield(
    victimId: string,
    attackerId: string,
    activityId: string,
  ): Promise<boolean> {
    const { rows } = await db.query<{ charges: number }>(
      `UPDATE user_powers
         SET charges = charges - 1, armed = false, recharged_at = now()
         WHERE user_id = $1 AND kind = 'shield' AND armed = true AND charges > 0
         RETURNING charges`,
      [victimId],
    )
    if (rows.length === 0) return false

    // Notify the victim that their shield blocked an attack
    await db.query(
      `INSERT INTO notifications (user_id, type, payload)
       VALUES ($1, 'shield_blocked', $2)`,
      [victimId, JSON.stringify({ byUserId: attackerId, activityId })],
    )
    notifyUser(victimId, {
      type: 'territory_stolen',
      payload: { territoryId: '', byUserId: attackerId, byDisplayName: '', areaKm2: 0 },
    })

    return true
  }

  private async _getRevengeTargets(userId: string): Promise<Set<string>> {
    const { rows } = await db.query<{ attacker_id: string }>(
      `SELECT DISTINCT attacker_id
         FROM territory_events
         WHERE new_owner_id = $1
           AND event_type = 'stolen'
           AND created_at > now() - interval '48 hours'`,
      [userId],
    )
    return new Set(rows.map((r) => r.attacker_id))
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
