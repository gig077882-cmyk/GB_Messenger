import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';

/**
 * Shared bridge to the Socket.IO server, so feature modules can emit
 * events without depending on the gateway itself.
 */
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private server: Server | null = null;

  setServer(server: Server): void {
    this.server = server;
  }

  emitToChat(chatId: string, event: string, payload: unknown): void {
    this.server?.to(`chat:${chatId}`).emit(event, payload);
  }

  emitToUser(userId: string, event: string, payload: unknown): void {
    this.server?.to(`user:${userId}`).emit(event, payload);
  }

  emitToUsers(userIds: string[], event: string, payload: unknown): void {
    for (const id of userIds) {
      this.emitToUser(id, event, payload);
    }
  }

  get connectedClients(): number {
    return this.server ? this.server.engine.clientsCount : 0;
  }
}
