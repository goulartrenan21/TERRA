import { PostgreSqlContainer, type StartedPostgreSqlContainer } from '@testcontainers/postgresql'
import { execSync } from 'child_process'

let container: StartedPostgreSqlContainer

export async function setupDatabase(): Promise<string> {
  container = await new PostgreSqlContainer('postgis/postgis:16-3.4')
    .withDatabase('terra_test')
    .withUsername('terra')
    .withPassword('terra_test')
    .start()

  const url = container.getConnectionUri()
  process.env.DATABASE_URL = url

  // Rodar migrations
  execSync('npm run db:migrate', {
    cwd: process.cwd(),
    env: { ...process.env, DATABASE_URL: url },
    stdio: 'inherit',
  })

  return url
}

export async function teardownDatabase(): Promise<void> {
  await container?.stop()
}
