import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'

const markReadBody = z.object({
  ids: z.array(z.string().uuid()).min(1).max(100),
})

const notificationsRoute: FastifyPluginAsync = async (app) => {
  // GET /notifications
  app.get('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id
    const { rows } = await db.query(
      `SELECT id, type, payload, read, created_at
         FROM notifications
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT 50`,
      [userId],
    )
    return rows.map((r) => ({
      id: r.id, type: r.type, payload: r.payload,
      read: r.read, createdAt: r.created_at,
    }))
  })

  // POST /notifications/read
  app.post('/read', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id
    const body = markReadBody.safeParse(req.body)
    if (!body.success) {
      return reply.code(400).send({ error: body.error.flatten() })
    }
    await db.query(
      `UPDATE notifications SET read = true WHERE id = ANY($1) AND user_id = $2`,
      [body.data.ids, userId],
    )
    reply.code(204).send()
  })
}

export default notificationsRoute
