import fp from 'fastify-plugin'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'
import ws from 'ws'

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type AnySupabase = SupabaseClient<any, any, any>

declare module 'fastify' {
  interface FastifyInstance {
    supabase: AnySupabase
  }
}

export default fp(async (app) => {
  const supabase = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    { auth: { persistSession: false }, realtime: { transport: ws as any } },
  )

  app.decorate('supabase', supabase as AnySupabase)
})
