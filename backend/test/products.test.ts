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

const ALLOWED_FIELDS = ['id', 'name', 'category_id', 'sku', 'is_active'] as const;
const FORBIDDEN_FIELDS = ['created_at', 'updated_at', 'productName'];

async function expectedProductsFromPostgres() {
  const rows = await prisma.product.findMany({
    select: {
      id: true,
      name: true,
      categoryId: true,
      sku: true,
      isActive: true,
    },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    name: row.name,
    category_id: row.categoryId,
    sku: row.sku,
    is_active: row.isActive,
  }));
}

describe('GET /api/products', () => {
  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/products');
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
      .get('/api/products')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 8 PostgreSQL products, ordered, without forbidden fields', async () => {
    const expected = await expectedProductsFromPostgres();
    assert.equal(expected.length, 8);

    const preview = JSON.parse(
      fs.readFileSync(
        path.join(
          path.dirname(fileURLToPath(import.meta.url)),
          '../migration-preview/products.json',
        ),
        'utf8',
      ),
    ) as Array<{ id: string; name: string }>;
    const previewIds = new Set(preview.map((row) => row.id));

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/products')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 8);
    assert.deepEqual(res.body, expected);

    const categoryIds = new Set(
      (await prisma.productCategory.findMany({ select: { id: true } })).map((row) => row.id),
    );

    for (const row of res.body) {
      assert.deepEqual(Object.keys(row).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(previewIds.has(row.id), true);
      if (row.category_id !== null) {
        assert.equal(categoryIds.has(row.category_id), true);
      }
    }

    assert.deepEqual(
      res.body.map((row: { name: string; id: string }) => [row.name, row.id]),
      expected.map((row) => [row.name, row.id]),
    );
  });

  it('reads products through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.product\.findMany/);

    const pgCount = await prisma.product.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/products')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 8);
  });
});
