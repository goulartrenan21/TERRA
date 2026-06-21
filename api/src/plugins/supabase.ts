import fp from 'fastify-plugin'
import { createClient } from '@supabase/supabase-js'

declare module 'fastify' {
  interface FastifyInstance {
    supabase: ReturnType<typeof createClient>
  }
}

export default fp(async (app) => {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  )

  app.decorate('supabase', supabase)
})
