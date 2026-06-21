import type { FastifyPluginAsync } from 'fastify'
import { db } from '../lib/db'

const streakRoute: FastifyPluginAsync = async (app) => {
  // POST /streak/checkin
  app.post('/checkin', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id

    const { rows } = await db.query<{
      streak_days: number
      freeze_used: boolean
    }>(
      `SELECT streak_days, freeze_used FROM check_streak($1)`,
      [userId],
    )

    const { streak_days, freeze_used } = rows[0]
    const { rows: userRows } = await db.query(
      'SELECT streak_freezes FROM users WHERE id = $1',
      [userId],
    )

    let message = `Sequência: ${streak_days} dias`
    if (freeze_used) message = `Freeze usado! Sequência mantida: ${streak_days} dias`
    if (streak_days === 1 && !freeze_used) message = 'Sequência reiniciada. Vai que vai!'

    return {
      streakDays:       streak_days,
      freezesRemaining: userRows[0]?.streak_freezes ?? 0,
      message,
    }
  })
}

export default streakRoute
