import type { FastifyPluginAsync } from 'fastify'
import { z } from 'zod'
import { db } from '../lib/db'
import type { UserPower, PowerKind, PowerFamily } from '@terra/shared'

// Recharge cooldown in hours per power kind
const RECHARGE_HOURS: Record<string, number> = {
  shield:    24 * 7,  // 7 days
  reclaim:   24 * 7,  // 1/week
  sprint:    24,      // 1/day (via challenge unlock)
}

const PASSIVE_POWERS: PowerKind[] = ['roots', 'freshness', 'revenge']
const FAMILY: Record<PowerKind, PowerFamily> = {
  shield:    'constancy',
  roots:     'constancy',
  freshness: 'constancy',
  reclaim:   'action',
  sprint:    'action',
  revenge:   'action',
}

const ALL_KINDS: PowerKind[] = ['shield', 'reclaim', 'sprint', 'roots', 'freshness', 'revenge']

const kindSchema = z.enum(['shield', 'reclaim', 'sprint', 'roots', 'freshness', 'revenge'])

const powersRoute: FastifyPluginAsync = async (app) => {
  // GET /powers — state of all powers for the authenticated user
  app.get('/', { preHandler: [app.authenticate] }, async (req, reply) => {
    const userId = (req.user as { id: string }).id

    const { rows } = await db.query<{
      kind: PowerKind
      charges: number
      max_charges: number
      armed: boolean
      recharged_at: string
    }>(
      `SELECT kind, charges, max_charges, armed, recharged_at
         FROM user_powers WHERE user_id = $1`,
      [userId],
    )

    const dbMap = Object.fromEntries(rows.map((r) => [r.kind, r]))

    const powers: UserPower[] = ALL_KINDS.map((kind) => {
      const row = dbMap[kind]
      const passive = PASSIVE_POWERS.includes(kind)

      if (!row) {
        return {
          kind,
          family: FAMILY[kind],
          charges: passive ? 0 : 0,
          maxCharges: 1,
          armed: false,
          passive,
          rechargesAt: null,
        }
      }

      const rechargeHours = RECHARGE_HOURS[kind]
      let rechargesAt: string | null = null
      if (!passive && row.charges < row.max_charges && rechargeHours) {
        const recharged = new Date(row.recharged_at)
        recharged.setHours(recharged.getHours() + rechargeHours)
        rechargesAt = recharged.toISOString()
      }

      return {
        kind,
        family: FAMILY[kind],
        charges: row.charges,
        maxCharges: row.max_charges,
        armed: row.armed,
        passive,
        rechargesAt,
      }
    })

    return powers
  })

  // POST /powers/:kind/activate — arm a power for the next run
  app.post<{ Params: { kind: string } }>(
    '/:kind/activate',
    { preHandler: [app.authenticate] },
    async (req, reply) => {
      const parsed = kindSchema.safeParse(req.params.kind)
      if (!parsed.success) {
        return reply.code(400).send({ error: { code: 'invalid_power', message: 'Invalid power kind' } })
      }

      const kind = parsed.data
      const userId = (req.user as { id: string }).id

      if (PASSIVE_POWERS.includes(kind)) {
        return reply.code(422).send({
          error: { code: 'passive_power', message: 'Passive powers cannot be manually activated' },
        })
      }

      // Get or create user_powers row
      const { rows } = await db.query<{
        charges: number
        max_charges: number
        armed: boolean
        recharged_at: string
      }>(
        `SELECT charges, max_charges, armed, recharged_at
           FROM user_powers WHERE user_id = $1 AND kind = $2`,
        [userId, kind],
      )

      if (rows.length === 0 || rows[0].charges === 0) {
        return reply.code(422).send({
          error: { code: 'no_charges', message: 'No charges available for this power' },
        })
      }

      if (rows[0].armed) {
        return reply.code(422).send({
          error: { code: 'already_armed', message: 'Power is already armed for next run' },
        })
      }

      const { rows: updated } = await db.query<{
        kind: PowerKind
        charges: number
        max_charges: number
        armed: boolean
        recharged_at: string
      }>(
        `UPDATE user_powers SET armed = true
           WHERE user_id = $1 AND kind = $2
           RETURNING kind, charges, max_charges, armed, recharged_at`,
        [userId, kind],
      )

      const row = updated[0]
      const rechargeHours = RECHARGE_HOURS[kind]
      let rechargesAt: string | null = null
      if (row.charges < row.max_charges && rechargeHours) {
        const recharged = new Date(row.recharged_at)
        recharged.setHours(recharged.getHours() + rechargeHours)
        rechargesAt = recharged.toISOString()
      }

      const power: UserPower = {
        kind: row.kind,
        family: FAMILY[row.kind],
        charges: row.charges,
        maxCharges: row.max_charges,
        armed: row.armed,
        passive: false,
        rechargesAt,
      }

      return power
    },
  )
}

export default powersRoute
