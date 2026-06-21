import fp from 'fastify-plugin'
import jwtPlugin from '@fastify/jwt'
import type { FastifyRequest, FastifyReply } from 'fastify'

export default fp(async (app) => {
  app.register(jwtPlugin, {
    secret: process.env.SUPABASE_JWT_SECRET!,
  })

  app.decorate('authenticate', async (req: FastifyRequest, reply: FastifyReply) => {
    try {
      await req.jwtVerify()
    } catch {
      reply.code(401).send({ error: 'Unauthorized' })
    }
  })
})

declare module 'fastify' {
  interface FastifyInstance {
    authenticate: (req: FastifyRequest, reply: FastifyReply) => Promise<void>
  }
}

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: { sub: string; email: string; role: string }
    user:    { id: string; email: string }
  }
}
