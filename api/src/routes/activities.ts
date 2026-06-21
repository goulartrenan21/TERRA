import type { FastifyPluginAsync } from 'fastify'
import { Queue } from 'bullmq'
import { z } from 'zod'
import { db } from '../lib/db'
import type { CaptureJobData, PostActivityRequest } from '@terra/shared'

const polylineSchema = z.object({
  type: z.literal('LineString'),
  coordinates: z.array(z.tuple([z.number(), z.number()])).min(4),
})

const metricsSchema = z.object({
  distanceM:        z.number().nonnegative(),
  durationS:        z.number().nonnegative(),
  avgPaceSecPerKm:  z.number().nonnegative(),
  elevationM:       z.number().optional(),
})

const postActivityBody = z.object({
  polyline:   polylineSchema,
  metrics:    metricsSchema,
  startedAt:  z.string().datetime(),
  endedAt:    z.string().datetime(),
})

const activitiesRoute: FastifyPluginAsync = async (app) => {
  const captureQueue = new Queue<CaptureJobData>('capture', {
    connection: app.redis,
    defaultJobOptions: { attempts: 3, backoff: { type: 'exponential', delay: 1000 } },
  })

  // POST /activities — upload de corrida, enfileira captura
  app.post('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const body = postActivityBody.safeParse(req.body)
    if (!body.success) {
      return reply.code(400).send({ error: 'Invalid request', details: body.error.flatten() })
    }

    const { polyline, metrics, startedAt, endedAt } = body.data
    const userId = (req.user as { id: string }).id

    const { rows } = await db.query<{ id: string }>(
      `INSERT INTO activities (user_id, path, distance_m, duration_s, avg_pace, elevation_m, status, started_at, ended_at)
       VALUES ($1, ST_GeomFromGeoJSON($2), $3, $4, $5, $6, 'processing', $7, $8)
       RETURNING id`,
      [
        userId,
        JSON.stringify(polyline),
        metrics.distanceM,
        metrics.durationS,
        metrics.avgPaceSecPerKm,
        metrics.elevationM ?? null,
        startedAt,
        endedAt,
      ],
    )

    const activityId = rows[0].id
    const job = await captureQueue.add('capture', { activityId, userId, polyline })

    reply.code(202).send({ activityId, status: 'processing', jobId: job.id })
  })

  // GET /activities/:id — status de uma atividade (polling fallback)
  app.get<{ Params: { id: string } }>('/:id', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id
    const { rows } = await db.query(
      `SELECT id, status, distance_m, duration_s, avg_pace, started_at, ended_at
         FROM activities WHERE id = $1 AND user_id = $2`,
      [req.params.id, userId],
    )
    if (!rows[0]) return reply.code(404).send({ error: 'Not found' })
    return rows[0]
  })
}

export default activitiesRoute
