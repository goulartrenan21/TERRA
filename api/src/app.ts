import Fastify from 'fastify'
import cors from '@fastify/cors'
import authPlugin from './plugins/auth'
import supabasePlugin from './plugins/supabase'
import redisPlugin from './plugins/redis'
import wsLib from './lib/ws'
import activitiesRoute from './routes/activities'
import mapRoute from './routes/map'
import rankingsRoute from './routes/rankings'
import profileRoute from './routes/profile'
import streakRoute from './routes/streak'
import feedRoute from './routes/feed'
import notificationsRoute from './routes/notifications'
import devicesRoute from './routes/devices'

export function buildApp(opts: { logger?: boolean } = {}) {
  const app = Fastify({ logger: opts.logger ?? true })

  app.register(cors, { origin: true })
  app.register(authPlugin)
  app.register(supabasePlugin)
  app.register(redisPlugin)
  app.register(wsLib)

  app.register(activitiesRoute,    { prefix: '/activities' })
  app.register(mapRoute,           { prefix: '/map' })
  app.register(rankingsRoute,      { prefix: '/rankings' })
  app.register(profileRoute,       { prefix: '/me' })
  app.register(streakRoute,        { prefix: '/streak' })
  app.register(feedRoute,          { prefix: '/feed' })
  app.register(notificationsRoute, { prefix: '/notifications' })
  app.register(devicesRoute,       { prefix: '/devices' })

  app.get('/health', async () => ({ status: 'ok', ts: new Date().toISOString() }))

  return app
}
