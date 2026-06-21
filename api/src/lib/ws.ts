import fp from 'fastify-plugin'
import websocketPlugin from '@fastify/websocket'
import type { WsMessage } from '@terra/shared'

const connections = new Map<string, WebSocket>()

export default fp(async (app) => {
  await app.register(websocketPlugin)

  app.get('/ws', { websocket: true, preHandler: [app.authenticate] }, (socket, req) => {
    const userId = (req.user as { id: string }).id
    connections.set(userId, socket as unknown as WebSocket)

    socket.on('close', () => connections.delete(userId))
    socket.on('error', () => connections.delete(userId))
  })
})

export function notifyUser(userId: string, message: WsMessage): boolean {
  const socket = connections.get(userId) as unknown as { readyState: number; send: (data: string) => void } | undefined
  if (socket && socket.readyState === 1 /* OPEN */) {
    socket.send(JSON.stringify(message))
    return true
  }
  return false
}
