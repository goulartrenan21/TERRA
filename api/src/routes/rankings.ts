import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'

const rankingsQuery = z.object({
  scope:          z.enum(['neighborhood', 'city', 'country']).default('neighborhood'),
  window:         z.enum(['week', 'alltime']).default('week'),
  neighborhoodId: z.string().uuid().optional(),
})

const rankingsRoute: FastifyPluginAsync = async (app) => {
  app.get('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const query = rankingsQuery.safeParse(req.query)
    if (!query.success) {
      return reply.code(400).send({ error: query.error.flatten() })
    }

    const userId = (req.user as { id: string }).id
    const { scope, window: win } = query.data

    // Resolve neighborhood — usa o do usuário se não fornecido
    let neighborhoodId = query.data.neighborhoodId
    if (!neighborhoodId && scope === 'neighborhood') {
      const { rows } = await db.query('SELECT neighborhood_id FROM users WHERE id = $1', [userId])
      neighborhoodId = rows[0]?.neighborhood_id
    }

    const windowFilter = win === 'week'
      ? `AND r.window_start = date_trunc('week', CURRENT_DATE)::DATE`
      : ''

    const scopeFilter = neighborhoodId
      ? `AND r.neighborhood_id = '${neighborhoodId}'`
      : ''

    const { rows } = await db.query(
      `SELECT
         ROW_NUMBER() OVER (ORDER BY r.total_area_km2 DESC) AS position,
         r.user_id,
         u.display_name,
         u.avatar_url,
         r.total_area_km2,
         r.territory_count,
         r.window_start,
         r.window_end
       FROM ranking_entries r
       JOIN users u ON u.id = r.user_id
       WHERE true ${windowFilter} ${scopeFilter}
       ORDER BY r.total_area_km2 DESC
       LIMIT 50`,
    )

    // Posição do usuário atual
    const myRow = rows.find((r) => r.user_id === userId)
    const currentUserPosition = myRow ? parseInt(myRow.position) : null

    return {
      scope,
      window: win,
      windowStart: rows[0]?.window_start ?? null,
      windowEnd:   rows[0]?.window_end ?? null,
      entries: rows.map((r) => ({
        position:       parseInt(r.position),
        userId:         r.user_id,
        displayName:    r.display_name,
        avatarUrl:      r.avatar_url,
        totalAreaKm2:   parseFloat(r.total_area_km2),
        territoryCount: r.territory_count,
      })),
      currentUserPosition,
    }
  })
}

export default rankingsRoute
