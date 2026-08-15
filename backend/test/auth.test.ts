import 'dotenv/config';
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import request from 'supertest';
import { createApp } from '../src/app';
import type { AuthenticatedUser } from '../src/auth/types';
import type { TokenVerifier } from '../src/auth/verifyToken';

class AuthError extends Error {
  constructor(
    message: string,
    readonly code: string,
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

function mockVerifier(impl: TokenVerifier): TokenVerifier {
  return impl;
}

const validUser: AuthenticatedUser = {
  uid: 'firebase-uid-123',
  email: 'employee@example.com',
  name: 'Test Employee',
  authProvider: 'google.com',
};

describe('GET /api/auth/me', () => {
  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/auth/me');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(res.body.uid, undefined);
  });

  it('returns 401 when Authorization header is malformed', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Basic abc');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 401 when Bearer token is invalid', async () => {
    const app = createApp(
      mockVerifier(async () => {
        throw new AuthError('invalid', 'auth/argument-error');
      }),
    );
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(res.body.token, undefined);
  });

  it('returns 401 when Bearer token is expired', async () => {
    const app = createApp(
      mockVerifier(async () => {
        throw new AuthError('expired', 'auth/id-token-expired');
      }),
    );
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer expired-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 200 and Firebase UID for an authenticated request', async () => {
    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 200);
    assert.deepEqual(res.body, {
      authenticated: true,
      uid: 'firebase-uid-123',
      email: 'employee@example.com',
      name: 'Test Employee',
    });
    assert.equal(res.body.authProvider, undefined);
  });
});

describe('local Flutter web CORS', () => {
  it('allows OPTIONS preflight from http://127.0.0.1:8765', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .options('/api/users')
      .set('Origin', 'http://127.0.0.1:8765')
      .set('Access-Control-Request-Method', 'GET')
      .set('Access-Control-Request-Headers', 'authorization,accept');

    assert.equal(res.status, 204);
    assert.equal(res.headers['access-control-allow-origin'], 'http://127.0.0.1:8765');
    assert.match(res.headers['access-control-allow-headers'] ?? '', /authorization/i);
    assert.match(res.headers['access-control-allow-methods'] ?? '', /GET/);
  });

  it('does not allow a foreign Origin', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/auth/me')
      .set('Origin', 'http://evil.example')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.headers['access-control-allow-origin'], undefined);
  });
});

describe('requireAuth does not leak secrets', () => {
  it('does not echo the submitted token', async () => {
    const app = createApp(
      mockVerifier(async () => {
        throw new Error('nope');
      }),
    );
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer super-secret-token');
    const body = JSON.stringify(res.body);
    assert.equal(body.includes('super-secret-token'), false);
  });
});
