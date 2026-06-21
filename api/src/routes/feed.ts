import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'

const feedQuery = z.object({
  cursor: z.string().datetime().optional(),
  limit:  z.coerce.number().int().min(1).max(50).default(20),
  tab:    z.enum(['explore', 'following']).default('explore'),
})

const feedRoute: FastifyPluginAsync = async (app) => {
  app.get('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const query = feedQuery.safeParse(req.query)
    if (!query.success) {
      return reply.code(400).send({ error: query.error.flatten() })
    }

    const userId = (req.user as { id: string }).id
    const { cursor, limit, tab } = query.data

    const cursorFilter = cursor ? `AND a.created_at < $3` : ''
    const tabFilter    = tab === 'following'
      ? `AND a.user_id IN (
           SELECT following_id FROM follows WHERE follower_id = $1
         )`
      : ''

    const params: unknown[] = [userId, limit + 1]
    if (cursor) params.push(cursor)

    const { rows } = await db.query(
      `SELECT
         a.id                                       AS activity_id,
         a.user_id,
         u.display_name,
         u.avatar_url,
         ST_AsGeoJSON(a.path)::json                AS path,
         a.distance_m,
         a.duration_s,
         a.avg_pace,
         a.created_at,
         COALESCE(te_sum.area_km2, 0)              AS captured_area_km2,
         COALESCE(te_sum.xp_gained, 0)             AS xp_gained,
         COALESCE(lk.like_count, 0)                AS like_count,
         COALESCE(lk.liked_by_me, false)           AS liked_by_me
       FROM activities a
       JOIN users u ON u.id = a.user_id
       LEFT JOIN LATERAL (
         SELECT
           SUM(area_km2)                                    AS area_km2,
           COUNT(*)::INT                                    AS xp_gained
         FROM territory_events
         WHERE activity_id = a.id AND event_type IN ('captured', 'stolen')
       ) te_sum ON true
       LEFT JOIN LATERAL (
         SELECT
           COUNT(*)::INT                                    AS like_count,
           BOOL_OR(user_id = $1)                           AS liked_by_me
         FROM activity_likes
         WHERE activity_id = a.id
       ) lk ON true
       WHERE a.status = 'done' ${tabFilter} ${cursorFilter}
       ORDER BY a.created_at DESC
       LIMIT $2`,
      params,
    )

    const hasMore = rows.length > limit
    const posts = rows.slice(0, limit)

    return {
      posts: posts.map((r) => ({
        id:              r.activity_id,
        activityId:      r.activity_id,
        userId:          r.user_id,
        displayName:     r.display_name,
        avatarUrl:       r.avatar_url,
        path:            r.path,
        metrics: {
          distanceM:       parseFloat(r.distance_m),
          durationS:       r.duration_s,
          avgPaceSecPerKm: parseFloat(r.avg_pace),
        },
        capturedAreaKm2: parseFloat(r.captured_area_km2),
        xpGained:        r.xp_gained,
        likeCount:       r.like_count,
        commentCount:    0,
        likedByMe:       r.liked_by_me,
        createdAt:       r.created_at,
      })),
      nextCursor: hasMore ? posts[posts.length - 1].created_at : null,
    }
  })
}

export default feedRoute
