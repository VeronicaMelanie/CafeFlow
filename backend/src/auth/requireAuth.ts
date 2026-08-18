import type { RequestHandler } from 'express';
import type { TokenVerifier } from './verifyToken.js';

function unauthorized(res: Parameters<RequestHandler>[1]) {
  res.status(401).json({ error: 'unauthorized' });
}

export function requireAuth(verifyIdToken: TokenVerifier): RequestHandler {
  return async (req, res, next) => {
    const header = req.headers.authorization;
    if (typeof header !== 'string' || header.trim() === '') {
      unauthorized(res);
      return;
    }

    const match = /^Bearer\s+(\S+)$/i.exec(header.trim());
    if (!match) {
      unauthorized(res);
      return;
    }

    try {
      req.authUser = await verifyIdToken(match[1]);
      next();
    } catch {
      unauthorized(res);
    }
  };
}
