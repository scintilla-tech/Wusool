import type { Role } from '@prisma/client';

export interface AuthContext {
  userId: string;
  tenantId: string | null;
  role: Role;
}

declare global {
  namespace Express {
    interface Request {
      auth?: AuthContext;
    }
  }
}

export {};
