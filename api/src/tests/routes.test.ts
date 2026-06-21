import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { buildApp } from '../app'
import { setupDatabase, teardownDatabase } from './setup'
import jwt from 'jsonwebtoken'

const TEST_USER_ID = '00000000-0000-0000-0000-000000000001'
const JWT_SECRET   = 'test-secret-32-chars-minimum-long!!'

function makeToken(userId = TEST_USER_ID) {
  return jwt.sign({ sub: userId, email: 'test@terra.app' }, JWT_SECRET)
}

describe('API Routes', () => {
  let app: ReturnType<typeof buildApp>

  beforeAll(async () => {
    await setupDatabase()

    process.env.SUPABASE_JWT_SECRET   = JWT_SECRET
    process.env.REDIS_URL             = 'redis://localhost:6379'
    process.env.SUPABASE_URL          = 'https://test.supabase.co'
    process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-key'

    app = buildApp({ logger: false })
    await app.ready()

    // Seed test user
    const { db } = await import('../lib/db')
    await db.query(
      `INSERT INTO users (id, email, display_name) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING`,
      [TEST_USER_ID, 'test@terra.app', 'TestUser'],
    )
  }, 120_000)

  afterAll(async () => {
    await app.close()
    await teardownDatabase()
  })

  describe('GET /health', () => {
    it('returns 200 with status ok', async () => {
      const res = await app.inject({ method: 'GET', url: '/health' })
      expect(res.statusCode).toBe(200)
      expect(res.json()).toMatchObject({ status: 'ok' })
    })
  })

  describe('Auth middleware', () => {
    it('returns 401 without token', async () => {
      const res = await app.inject({ method: 'GET', url: '/me' })
      expect(res.statusCode).toBe(401)
    })

    it('returns 200 with valid token', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/me',
        headers: { authorization: `Bearer ${makeToken()}` },
      })
      expect(res.statusCode).toBe(200)
    })
  })

  describe('GET /me', () => {
    it('returns user profile', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/me',
        headers: { authorization: `Bearer ${makeToken()}` },
      })
      const body = res.json()
      expect(res.statusCode).toBe(200)
      expect(body).toMatchObject({
        id:          TEST_USER_ID,
        displayName: 'TestUser',
        xp:          0,
        level:       1,
        streakDays:  0,
      })
    })
  })

  describe('PATCH /me', () => {
    it('updates display name', async () => {
      const res = await app.inject({
        method: 'PATCH',
        url: '/me',
        headers: { authorization: `Bearer ${makeToken()}` },
        payload: { displayName: 'UpdatedName' },
      })
      expect(res.statusCode).toBe(204)
    })

    it('rejects invalid body', async () => {
      const res = await app.inject({
        method: 'PATCH',
        url: '/me',
        headers: { authorization: `Bearer ${makeToken()}` },
        payload: { displayName: 'X' }, // too short
      })
      expect(res.statusCode).toBe(400)
    })
  })

  describe('GET /map/territories', () => {
    it('returns GeoJSON FeatureCollection', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/map/territories?bbox=-46.7,-23.6,-46.6,-23.5',
        headers: { authorization: `Bearer ${makeToken()}` },
      })
      expect(res.statusCode).toBe(200)
      expect(res.json()).toMatchObject({ type: 'FeatureCollection', features: [] })
    })

    it('returns 400 for invalid bbox', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/map/territories?bbox=invalid',
        headers: { authorization: `Bearer ${makeToken()}` },
      })
      expect(res.statusCode).toBe(400)
    })
  })

  describe('GET /rankings', () => {
    it('returns ranking with currentUserPosition null when no entries', async () => {
      const res = await app.inject({
        method: 'GET',
        url: '/rankings',
        headers: { authorization: `Bearer ${makeToken()}` },
      })
      expect(res.statusCode).toBe(200)
      expect(res.json()).toMatchObject({ entries: [], currentUserPosition: null })
    })
  })

  describe('POST /activities', () => {
    it('returns 202 with activityId', async () => {
      const res = await app.inject({
        method: 'POST',
        url: '/activities',
        headers: { authorization: `Bearer ${makeToken()}` },
        payload: {
          polyline: {
            type: 'LineString',
            coordinates: [
              [-46.65, -23.55],
              [-46.64, -23.55],
              [-46.64, -23.54],
              [-46.65, -23.54],
              [-46.65, -23.55],
            ],
          },
          metrics: { distanceM: 1200, durationS: 600, avgPaceSecPerKm: 500 },
          startedAt: '2026-06-20T10:00:00Z',
          endedAt:   '2026-06-20T10:10:00Z',
        },
      })
      expect(res.statusCode).toBe(202)
      expect(res.json()).toMatchObject({ status: 'processing' })
      expect(res.json().activityId).toBeDefined()
    })
  })
})
