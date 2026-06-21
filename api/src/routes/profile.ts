import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'

const updateProfileBody = z.object({
  displayName:    z.string().min(2).max(40).optional(),
  avatarUrl:      z.string().url().optional(),
  neighborhoodId: z.string().uuid().optional(),
  privacyZones:   z.array(z.object({
    lat:     z.number(),
    lng:     z.number(),
    radiusM: z.number().min(50).max(500),
    label:   z.string().optional(),
  })).max(5).optional(),
})

const profileRoute: FastifyPluginAsync = async (app) => {
  // GET /me
  app.get('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id

    const { rows } = await db.query(
      `SELECT
         u.id, u.email, u.display_name, u.avatar_url,
         u.xp, u.level, u.streak_days, u.streak_freezes,
         u.neighborhood_id, u.privacy_zones, u.created_at,
         COALESCE(SUM(t.area_km2), 0)::NUMERIC(12,6) AS total_area_km2,
         COUNT(t.id)::INTEGER                         AS territory_count
       FROM users u
       LEFT JOIN territories t ON t.owner_id = u.id
       WHERE u.id = $1
       GROUP BY u.id`,
      [userId],
    )

    if (!rows[0]) return reply.code(404).send({ error: 'User not found' })

    const user = rows[0]
    return {
      id:             user.id,
      email:          user.email,
      displayName:    user.display_name,
      avatarUrl:      user.avatar_url,
      xp:             user.xp,
      level:          user.level,
      streakDays:     user.streak_days,
      streakFreezes:  user.streak_freezes,
      neighborhoodId: user.neighborhood_id,
      privacyZones:   user.privacy_zones,
      totalAreaKm2:   parseFloat(user.total_area_km2),
      territoryCount: user.territory_count,
      createdAt:      user.created_at,
    }
  })

  // PATCH /me
  app.patch('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id
    const body = updateProfileBody.safeParse(req.body)
    if (!body.success) {
      return reply.code(400).send({ error: 'Invalid request', details: body.error.flatten() })
    }

    const updates: string[] = []
    const values: unknown[] = []
    let idx = 1

    if (body.data.displayName)    { updates.push(`display_name = $${idx++}`);    values.push(body.data.displayName) }
    if (body.data.avatarUrl)      { updates.push(`avatar_url = $${idx++}`);      values.push(body.data.avatarUrl) }
    if (body.data.neighborhoodId) { updates.push(`neighborhood_id = $${idx++}`); values.push(body.data.neighborhoodId) }
    if (body.data.privacyZones)   { updates.push(`privacy_zones = $${idx++}`);   values.push(JSON.stringify(body.data.privacyZones)) }

    if (updates.length === 0) return reply.code(400).send({ error: 'Nothing to update' })

    values.push(userId)
    await db.query(
      `UPDATE users SET ${updates.join(', ')} WHERE id = $${idx}`,
      values,
    )

    reply.code(204).send()
  })

  // GET /me/user/:id — perfil público de outro usuário
  app.get<{ Params: { id: string } }>('/user/:id', { preHandler: [app.authenticate] }, async (req, reply) => {
    const { rows } = await db.query(
      `SELECT
         u.id, u.display_name, u.avatar_url, u.level, u.xp,
         u.streak_days, u.neighborhood_id, u.created_at,
         COALESCE(SUM(t.area_km2), 0)::NUMERIC(12,6) AS total_area_km2,
         COUNT(t.id)::INTEGER AS territory_count
       FROM users u
       LEFT JOIN territories t ON t.owner_id = u.id
       WHERE u.id = $1
       GROUP BY u.id`,
      [req.params.id],
    )
    if (!rows[0]) return reply.code(404).send({ error: 'User not found' })
    const u = rows[0]
    return {
      id: u.id, displayName: u.display_name, avatarUrl: u.avatar_url,
      level: u.level, xp: u.xp, streakDays: u.streak_days,
      neighborhoodId: u.neighborhood_id,
      totalAreaKm2: parseFloat(u.total_area_km2),
      territoryCount: u.territory_count,
      createdAt: u.created_at,
    }
  })
}

export default profileRoute
