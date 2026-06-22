import { initializeApp, getApps, cert } from 'firebase-admin/app'
import { getMessaging } from 'firebase-admin/messaging'
import { db } from '../lib/db'

function initFirebase() {
  if (getApps().length > 0) return

  const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT_KEY
  if (!serviceAccount) {
    console.warn('[push] FIREBASE_SERVICE_ACCOUNT_KEY not set — push disabled')
    return
  }

  initializeApp({
    credential: cert(JSON.parse(serviceAccount)),
  })
}

initFirebase()

export async function sendPushToUser(
  userId: string,
  notification: { title: string; body: string },
  data: Record<string, string> = {},
): Promise<void> {
  if (getApps().length === 0) return

  const { rows } = await db.query<{ token: string }>(
    `SELECT token FROM devices WHERE user_id = $1`,
    [userId],
  )
  if (rows.length === 0) return

  const tokens = rows.map((r) => r.token)

  try {
    const response = await getMessaging().sendEachForMulticast({
      tokens,
      notification,
      data,
      android: { priority: 'high' },
      apns:    { payload: { aps: { sound: 'default', badge: 1 } } },
    })

    // Remove stale tokens (unregistered devices)
    const staleTokens = response.responses
      .map((r, i) => (!r.success && r.error?.code === 'messaging/registration-token-not-registered' ? tokens[i] : null))
      .filter(Boolean) as string[]

    if (staleTokens.length > 0) {
      await db.query(`DELETE FROM devices WHERE token = ANY($1)`, [staleTokens])
    }
  } catch (err) {
    console.error('[push] sendEachForMulticast error:', err)
  }
}

export async function sendTerritoryStolen(
  victimUserId: string,
  attackerName: string,
  areaKm2: number,
): Promise<void> {
  await sendPushToUser(
    victimUserId,
    {
      title: 'Seu território foi roubado!',
      body:  `${attackerName} roubou ${areaKm2.toFixed(3)} km² do seu território`,
    },
    { type: 'territory_stolen' },
  )
}

export async function sendStreakWarning(userId: string, streakDays: number): Promise<void> {
  await sendPushToUser(
    userId,
    {
      title: 'Seu streak está em risco ⚠️',
      body:  `Corra hoje para manter ${streakDays} dias de sequência`,
    },
    { type: 'streak_warning', streakDays: String(streakDays) },
  )
}
