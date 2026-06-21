import 'dotenv/config'
import { Worker, type Job } from 'bullmq'
import { CaptureService } from '../services/capture.service'
import { db } from '../lib/db'
import type { CaptureJobData, CaptureResult } from '@terra/shared'

// Use URL-based connection to avoid ioredis version conflict with BullMQ's bundled copy
const worker = new Worker<CaptureJobData, CaptureResult, string>(
  'capture',
  async (job: Job<CaptureJobData>) => {
    const service = new CaptureService()
    return service.process(job.data)
  },
  {
    connection: { url: process.env.REDIS_URL!, maxRetriesPerRequest: null },
    concurrency: 10,
    limiter: { max: 50, duration: 1000 },
  },
)

worker.on('completed', (job) => {
  console.log(`[capture] job ${job.id} completed for activity ${job.data.activityId}`)
})

worker.on('failed', async (job, err) => {
  console.error(`[capture] job ${job?.id} failed:`, err.message)

  if (job && job.attemptsMade >= (job.opts.attempts ?? 3)) {
    await db.query(
      `UPDATE activities SET status = 'failed' WHERE id = $1`,
      [job.data.activityId],
    )
  }
})

worker.on('error', (err) => {
  console.error('[capture] worker error:', err)
})

console.log('[capture] worker started')

process.on('SIGTERM', async () => {
  await worker.close()
  process.exit(0)
})
