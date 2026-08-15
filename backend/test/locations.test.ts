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

const ALLOWED_FIELDS = [
  'id',
  'code',
  'name',
  'is_active',
  'opened_on',
  'closed_on',
] as const;

const FORBIDDEN_FIELDS = ['created_at', 'updated_at'];

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function expectedLocationsFromPostgres() {
  const rows = await prisma.location.findMany({
    select: {
      id: true,
      code: true,
      name: true,
      isActive: true,
      openedOn: true,
      closedOn: true,
    },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    code: row.code,
    name: row.name,
    is_active: row.isActive,
    opened_on: formatDateOnly(row.openedOn),
    closed_on: formatDateOnly(row.closedOn),
  }));
}

describe('GET /api/locations', () => {
  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/locations');
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
      .get('/api/locations')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 2 PostgreSQL locations, ordered, without forbidden fields', async () => {
    const expected = await expectedLocationsFromPostgres();
    assert.equal(expected.length, 2);

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/locations')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 2);
    assert.deepEqual(res.body, expected);

    const byCode = new Map(
      res.body.map((row: { code: string; name: string; id: string }) => [row.code, row]),
    );
    assert.equal(byCode.get('gara')?.name, 'Gara');
    assert.equal(byCode.get('avantgarden')?.name, 'Avantgarden');
    assert.equal(byCode.get('gara')?.id, 'ff63f35a-ddd1-449e-9021-33ee78e2261a');
    assert.equal(byCode.get('avantgarden')?.id, 'cc643d67-081b-44e1-b4c0-c0194fbb9aab');

    for (const location of res.body) {
      assert.deepEqual(Object.keys(location).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(location, field), false);
      }
    }

    assert.deepEqual(
      res.body.map((row: { name: string; id: string }) => [row.name, row.id]),
      expected.map((row) => [row.name, row.id]),
    );
  });

  it('reads locations through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.location\.findMany/);

    const pgCount = await prisma.location.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/locations')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 2);
  });
});
