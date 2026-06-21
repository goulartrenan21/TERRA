import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'

const registerDeviceBody = z.object({
  token:    z.string().min(10),
  platform: z.enum(['android', 'ios']),
})

const devicesRoute: FastifyPluginAsync = async (app) => {
  // POST /devices — registra token FCM/APNs
  app.post('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id
    const body = registerDeviceBody.safeParse(req.body)
    if (!body.success) {
      return reply.code(400).send({ error: body.error.flatten() })
    }

    await db.query(
      `INSERT INTO devices (user_id, token, platform)
       VALUES ($1, $2, $3)
       ON CONFLICT (token) DO UPDATE SET user_id = $1, platform = $3, updated_at = now()`,
      [userId, body.data.token, body.data.platform],
    )

    reply.code(204).send()
  })
}

export default devicesRoute
