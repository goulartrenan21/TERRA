import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'
import type { TerritoriesResponse } from '@terra/shared'

const bboxSchema = z.string().regex(
  /^-?\d+(\.\d+)?,-?\d+(\.\d+)?,-?\d+(\.\d+)?,-?\d+(\.\d+)?$/,
  'bbox must be: lng1,lat1,lng2,lat2',
)

const CACHE_TTL_SECONDS = 10

const mapRoute: FastifyPluginAsync = async (app) => {
  // GET /map/territories?bbox=lng1,lat1,lng2,lat2
  app.get<{ Querystring: { bbox: string } }>(
    '/territories',
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const parsed = bboxSchema.safeParse(req.query.bbox)
      if (!parsed.success) {
        return reply.code(400).send({ error: parsed.error.flatten().formErrors[0] })
      }

      const cacheKey = `map:territories:${parsed.data}`
      const cached = await app.redis.get(cacheKey)
      if (cached) {
        return reply.header('X-Cache', 'HIT').send(JSON.parse(cached))
      }

      const [lng1, lat1, lng2, lat2] = parsed.data.split(',').map(Number)

      const { rows } = await db.query(
        `SELECT
           t.id,
           t.owner_id,
           u.display_name      AS owner_name,
           u.avatar_url        AS owner_avatar_url,
           ST_AsGeoJSON(t.geom)::json AS geom,
           t.area_km2,
           t.freshness,
           t.captured_at,
           t.defended_at
         FROM territories t
         LEFT JOIN users u ON u.id = t.owner_id
         WHERE t.geom && ST_MakeEnvelope($1, $2, $3, $4, 4326)
         LIMIT 500`,
        [lng1, lat1, lng2, lat2],
      )

      const geojson: TerritoriesResponse = {
        type: 'FeatureCollection',
        features: rows.map((r) => ({
          type: 'Feature',
          geometry: r.geom,
          properties: {
            id: r.id,
            ownerId: r.owner_id,
            ownerName: r.owner_name,
            ownerAvatarUrl: r.owner_avatar_url,
            areaKm2: parseFloat(r.area_km2),
            freshness: parseFloat(r.freshness),
            capturedAt: r.captured_at,
            defendedAt: r.defended_at,
          },
        })),
      }

      await app.redis.setex(cacheKey, CACHE_TTL_SECONDS, JSON.stringify(geojson))

      return reply.header('X-Cache', 'MISS').send(geojson)
    },
  )
}

export default mapRoute
