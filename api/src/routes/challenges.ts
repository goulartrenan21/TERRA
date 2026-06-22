import type { FastifyPluginAsync } from 'fastify'
import { db } from '../lib/db'

const challengesRoute: FastifyPluginAsync = async (app) => {
  // GET /challenges
  app.get('/', { preHandler: [app.authenticate] }, async (req) => {
    const userId = (req.user as { id: string }).id
    const { rows } = await db.query(
      `SELECT id, kind, reward_xp, status, expires_at
         FROM challenges
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 20`,
      [userId],
    )
    return rows
  })

  // POST /challenges/:id/claim
  app.post<{ Params: { id: string } }>(
    '/:id/claim',
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const userId = (req.user as { id: string }).id
      const { id }  = req.params

      const { rows } = await db.query<{
        kind: string
        reward_xp: number
        status: string
        expires_at: string | null
      }>(
        `SELECT kind, reward_xp, status, expires_at
           FROM challenges WHERE id = $1 AND user_id = $2`,
        [id, userId],
      )

      if (!rows[0]) return reply.code(404).send({ error: { code: 'not_found', message: 'Challenge not found' } })

      const ch = rows[0]
      if (ch.status !== 'available') {
        return reply.code(422).send({ error: { code: 'already_claimed', message: 'Challenge already claimed or expired' } })
      }
      if (ch.expires_at && new Date(ch.expires_at) < new Date()) {
        await db.query(`UPDATE challenges SET status = 'expired' WHERE id = $1`, [id])
        return reply.code(422).send({ error: { code: 'expired', message: 'Challenge expired' } })
      }

      // Mark as claimed + grant XP
      await db.query(`UPDATE challenges SET status = 'claimed' WHERE id = $1`, [id])
      const { rows: xpRows } = await db.query<{ xp: number; level: number }>(
        `UPDATE users SET xp = xp + $2 WHERE id = $1 RETURNING xp, level`,
        [userId, ch.reward_xp],
      )
      const { xp, level } = xpRows[0]

      // Grant Sprint charge for daily run challenges
      if (ch.kind === 'daily_run') {
        await db.query(
          `INSERT INTO user_powers (user_id, kind, charges, max_charges, recharged_at)
           VALUES ($1, 'sprint', 1, 1, now())
           ON CONFLICT (user_id, kind) DO UPDATE
             SET charges = LEAST(user_powers.max_charges, user_powers.charges + 1),
                 recharged_at = now()`,
          [userId],
        )
      }

      return { xp, level, challenge: { id, kind: ch.kind, status: 'claimed', reward_xp: ch.reward_xp } }
    },
  )
}

export default challengesRoute
