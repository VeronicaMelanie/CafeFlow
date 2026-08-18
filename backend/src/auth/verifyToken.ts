import type { Auth } from 'firebase-admin/auth';
import type { AuthenticatedUser } from './types.js';

export type TokenVerifier = (idToken: string) => Promise<AuthenticatedUser>;

export function createFirebaseTokenVerifier(auth: Auth): TokenVerifier {
  return async (idToken) => {
    const decoded = await auth.verifyIdToken(idToken);
    return {
      uid: decoded.uid,
      email: decoded.email,
      name: typeof decoded.name === 'string' ? decoded.name : undefined,
      authProvider: decoded.firebase?.sign_in_provider,
    };
  };
}
