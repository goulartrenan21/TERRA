import 'dotenv/config'
import { buildApp } from './app'

const app = buildApp()

const port = parseInt(process.env.PORT ?? '3000', 10)

app.listen({ port, host: '0.0.0.0' }, (err) => {
  if (err) {
    app.log.error(err)
    process.exit(1)
  }
})

process.on('SIGTERM', async () => {
  await app.close()
  process.exit(0)
})
