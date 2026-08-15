import 'dotenv/config';
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import request from 'supertest';
import { createApp } from '../src/app';
import { getFirebaseAuth, getFirebaseProjectId } from '../src/firebase';
import { createFirebaseTokenVerifier } from '../src/auth/verifyToken';

describe('Firebase Admin SDK', () => {
  it('initializes for project cafeflow-5tg', () => {
    const auth = getFirebaseAuth();
    assert.ok(auth);
    assert.equal(getFirebaseProjectId(), 'cafeflow-5tg');
  });

  it('rejects an invalid ID token', async () => {
    await assert.rejects(() => getFirebaseAuth().verifyIdToken('not-a-firebase-token'));
  });
});

describe('GET /api/auth/me with Firebase Admin verifier', () => {
  const app = createApp(createFirebaseTokenVerifier(getFirebaseAuth()));

  it('returns 401 for a missing token', async () => {
    const res = await request(app).get('/api/auth/me');
    assert.equal(res.status, 401);
  });

  it('returns 401 for an invalid Bearer token', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer not-a-firebase-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });
});
