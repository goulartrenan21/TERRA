import fp from 'fastify-plugin'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

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
    { auth: { persistSession: false } },
  )

  app.decorate('supabase', supabase as AnySupabase)
})
