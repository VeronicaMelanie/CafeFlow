import 'dotenv/config';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';
import request from 'supertest';
import { createApp } from '../src/app';
import type { AuthenticatedUser } from '../src/auth/types';
import type { TokenVerifier } from '../src/auth/verifyToken';
import { prisma } from '../src/db';

const validUser: AuthenticatedUser = {
  uid: 'firebase-uid-123',
  email: 'employee@example.com',
  name: 'Test Employee',
  authProvider: 'google.com',
};

function mockVerifier(impl: TokenVerifier): TokenVerifier {
  return impl;
}

describe('GET /api/audit', () => {
  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/audit');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 401 when Bearer token is invalid', async () => {
    const app = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const res = await request(app)
      .get('/api/audit')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with zero audit rows because PostgreSQL has no audit table', async () => {
    const tables = await prisma.$queryRaw<Array<{ table_name: string }>>`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name IN ('audit', 'audit_logs', 'audits')
      ORDER BY table_name
    `;
    assert.equal(tables.length, 0);

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/audit')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 0);

    const timestamps = res.body.map((row: { created_at?: string }) => row.created_at).filter(Boolean);
    for (let i = 1; i < timestamps.length; i += 1) {
      assert.ok(timestamps[i - 1] <= timestamps[i]);
    }
  });

  it('reads audit state through PostgreSQL/Prisma and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /information_schema\.tables/);

    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/audit')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.deepEqual(res.body, []);
  });
});
