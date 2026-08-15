import 'dotenv/config';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { afterEach, before, describe, it } from 'node:test';
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
  'user_id',
  'product_id',
  'location_id',
  'quantity',
  'consumed_on',
  'logged_at',
  'notes',
] as const;

const FORBIDDEN_FIELDS = ['created_at', 'updated_at', 'productName', 'date', 'userId'];
const WRITE_DATE = '2099-08-15';

async function cleanupConsumptionWriteTests() {
  await prisma.consumption.deleteMany({
    where: { consumedOn: { gte: new Date('2099-01-01T00:00:00.000Z') } },
  });
}

async function loadEmployeeAndAdmin() {
  const employee = await prisma.user.findFirst({
    where: { role: 'employee', userLocations: { some: {} } },
    select: { id: true, firebaseUid: true, role: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });
  const otherEmployee = await prisma.user.findFirst({
    where: {
      role: 'employee',
      ...(employee ? { id: { not: employee.id } } : {}),
    },
    select: { id: true, firebaseUid: true, role: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });
  const admin = await prisma.user.findFirst({
    where: { role: 'admin' },
    select: { id: true, firebaseUid: true, role: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });
  assert.ok(employee, 'expected a PostgreSQL employee');
  assert.ok(otherEmployee, 'expected a second PostgreSQL employee');
  assert.ok(admin, 'expected a PostgreSQL admin');
  return { employee, otherEmployee, admin };
}

async function loadProduct() {
  const product = await prisma.product.findFirst({
    where: { isActive: true },
    select: { id: true, name: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });
  assert.ok(product, 'expected an active PostgreSQL product');
  return product;
}

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function expectedConsumptionsFromPostgres() {
  const rows = await prisma.consumption.findMany({
    select: {
      id: true,
      userId: true,
      productId: true,
      locationId: true,
      quantity: true,
      consumedOn: true,
      loggedAt: true,
      notes: true,
    },
    orderBy: [{ consumedOn: 'asc' }, { loggedAt: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    user_id: row.userId,
    product_id: row.productId,
    location_id: row.locationId,
    quantity: Number(row.quantity),
    consumed_on: formatDateOnly(row.consumedOn),
    logged_at: row.loggedAt.toISOString(),
    notes: row.notes,
  }));
}

describe('GET /api/consumptions', () => {
  before(async () => {
    await cleanupConsumptionWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/consumptions');
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
      .get('/api/consumptions')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with zero PostgreSQL consumptions and valid empty constraints', async () => {
    const expected = await expectedConsumptionsFromPostgres();
    assert.equal(expected.length, 0);

    const preview = JSON.parse(
      fs.readFileSync(
        path.join(
          path.dirname(fileURLToPath(import.meta.url)),
          '../migration-preview/consumptions.json',
        ),
        'utf8',
      ),
    );
    assert.ok(Array.isArray(preview));
    assert.equal(preview.length, 0);

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 0);
    assert.deepEqual(res.body, expected);

    const userIds = new Set(
      (await prisma.user.findMany({ select: { id: true } })).map((row) => row.id),
    );
    const productIds = new Set(
      (await prisma.product.findMany({ select: { id: true } })).map((row) => row.id),
    );
    const locationIds = new Set(
      (await prisma.location.findMany({ select: { id: true } })).map((row) => row.id),
    );

    for (const row of res.body) {
      assert.deepEqual(Object.keys(row).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(userIds.has(row.user_id), true);
      assert.equal(productIds.has(row.product_id), true);
      assert.equal(locationIds.has(row.location_id), true);
      assert.ok(row.quantity > 0);
      assert.ok(row.consumed_on);
      assert.ok(row.logged_at);
    }
  });

  it('reads consumptions through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.consumption\.findMany/);
    assert.match(appSource, /prisma\.consumption\.create/);
    assert.match(appSource, /prisma\.consumption\.update/);
    assert.match(appSource, /prisma\.consumption\.delete/);

    const pgCount = await prisma.consumption.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 0);
  });
});

describe('POST /api/consumptions', () => {
  afterEach(async () => {
    await cleanupConsumptionWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const product = await loadProduct();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).post('/api/consumptions').send({
      product_id: product.id,
      consumed_on: WRITE_DATE,
      quantity: 1,
    });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 401 when Bearer token is invalid', async () => {
    const product = await loadProduct();
    const app = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const res = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 1,
      });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 403 when the Firebase UID is not a PostgreSQL user', async () => {
    const product = await loadProduct();
    const app = createApp(
      mockVerifier(async () => ({
        uid: 'unknown-firebase-uid-consumption-write',
      })),
    );
    const res = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 1,
      });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');
  });

  it('returns 400 for an invalid payload', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const product = await loadProduct();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const missing = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ product_id: product.id, quantity: 1 });
    assert.equal(missing.status, 400);
    assert.equal(missing.body.error, 'invalid_consumption');

    const badDate = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: '2026-13-40',
        quantity: 1,
      });
    assert.equal(badDate.status, 400);

    const badQuantity = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 0,
      });
    assert.equal(badQuantity.status, 400);
  });

  it('returns 404 for an unknown product', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: '00000000-0000-0000-0000-000000000001',
        consumed_on: WRITE_DATE,
        quantity: 1,
      });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('creates a consumption for the authenticated owner, not another user', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const product = await loadProduct();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const impersonate = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 2,
        user_id: admin.id,
      });
    assert.equal(impersonate.status, 403);
    assert.equal(impersonate.body.error, 'forbidden');

    const res = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 2,
        notes: 'test write',
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.user_id, employee.id);
    assert.notEqual(res.body.user_id, admin.id);
    assert.equal(res.body.product_id, product.id);
    assert.equal(res.body.consumed_on, WRITE_DATE);
    assert.equal(res.body.quantity, 2);
    assert.equal(res.body.notes, 'test write');
    assert.ok(res.body.location_id);
    assert.ok(res.body.logged_at);
    assert.equal(Object.hasOwn(res.body, 'productName'), false);

    const pg = await prisma.consumption.findUnique({ where: { id: res.body.id } });
    assert.ok(pg);
    assert.equal(pg.userId, employee.id);
    assert.equal(pg.productId, product.id);
    assert.equal(formatDateOnly(pg.consumedOn), WRITE_DATE);
    assert.equal(Number(pg.quantity), 2);
    assert.equal(pg.notes, 'test write');
    assert.equal(pg.locationId, res.body.location_id);

    const getApp = createApp(mockVerifier(async () => validUser));
    const getRes = await request(getApp)
      .get('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(getRes.status, 200);
    const fromGet = getRes.body.find((row: { id: string }) => row.id === res.body.id);
    assert.ok(fromGet);
    assert.equal(fromGet.user_id, employee.id);
    assert.equal(fromGet.product_id, product.id);
    assert.equal(fromGet.consumed_on, WRITE_DATE);
  });
});

describe('PATCH /api/consumptions/:id', () => {
  afterEach(async () => {
    await cleanupConsumptionWriteTests();
  });

  it('returns 401 when unauthorized or token is invalid', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app)
      .patch('/api/consumptions/00000000-0000-0000-0000-000000000001')
      .send({ quantity: 3 });
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .patch('/api/consumptions/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ quantity: 3 });
    assert.equal(invalid.status, 401);
  });

  it('returns 403 when another employee patches the row', async () => {
    const { employee, otherEmployee } = await loadEmployeeAndAdmin();
    const product = await loadProduct();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const otherApp = createApp(
      mockVerifier(async () => ({ uid: otherEmployee.firebaseUid })),
    );
    const created = await request(ownerApp)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 1,
      });
    assert.equal(created.status, 201);

    const res = await request(otherApp)
      .patch(`/api/consumptions/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ quantity: 9 });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');

    const pg = await prisma.consumption.findUnique({
      where: { id: created.body.id },
    });
    assert.equal(Number(pg?.quantity), 1);
  });

  it('returns 404 when the consumption does not exist', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(app)
      .patch('/api/consumptions/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ quantity: 3 });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('lets the owner update product, quantity, and notes', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const product = await loadProduct();
    const otherProduct = await prisma.product.findFirst({
      where: { isActive: true, id: { not: product.id } },
      select: { id: true },
      orderBy: [{ name: 'asc' }, { id: 'asc' }],
    });
    assert.ok(otherProduct, 'expected a second product');
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const created = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 1,
        notes: 'before',
      });
    assert.equal(created.status, 201);

    const res = await request(app)
      .patch(`/api/consumptions/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: otherProduct.id,
        quantity: 4,
        notes: 'after',
      });
    assert.equal(res.status, 200);
    assert.equal(res.body.product_id, otherProduct.id);
    assert.equal(res.body.quantity, 4);
    assert.equal(res.body.notes, 'after');
    assert.equal(res.body.consumed_on, WRITE_DATE);
    assert.equal(res.body.logged_at, created.body.logged_at);

    const pg = await prisma.consumption.findUnique({
      where: { id: created.body.id },
    });
    assert.equal(pg?.productId, otherProduct.id);
    assert.equal(Number(pg?.quantity), 4);
    assert.equal(pg?.notes, 'after');
  });
});

describe('DELETE /api/consumptions/:id', () => {
  afterEach(async () => {
    await cleanupConsumptionWriteTests();
  });

  it('returns 401 when unauthorized', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).delete(
      '/api/consumptions/00000000-0000-0000-0000-000000000001',
    );
    assert.equal(res.status, 401);
  });

  it('returns 403 when another employee deletes the row', async () => {
    const { employee, otherEmployee } = await loadEmployeeAndAdmin();
    const product = await loadProduct();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const otherApp = createApp(
      mockVerifier(async () => ({ uid: otherEmployee.firebaseUid })),
    );
    const created = await request(ownerApp)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 1,
      });
    assert.equal(created.status, 201);

    const res = await request(otherApp)
      .delete(`/api/consumptions/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 403);

    const pg = await prisma.consumption.findUnique({
      where: { id: created.body.id },
    });
    assert.ok(pg);
  });

  it('returns 404 when the consumption does not exist', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(app)
      .delete('/api/consumptions/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('lets the owner delete the row from PostgreSQL', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const product = await loadProduct();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const created = await request(app)
      .post('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        product_id: product.id,
        consumed_on: WRITE_DATE,
        quantity: 1,
      });
    assert.equal(created.status, 201);

    const res = await request(app)
      .delete(`/api/consumptions/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 204);

    const pg = await prisma.consumption.findUnique({
      where: { id: created.body.id },
    });
    assert.equal(pg, null);

    const getApp = createApp(mockVerifier(async () => validUser));
    const getRes = await request(getApp)
      .get('/api/consumptions')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(
      getRes.body.some((row: { id: string }) => row.id === created.body.id),
      false,
    );
  });
});
