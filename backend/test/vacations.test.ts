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
  'start_on',
  'end_on',
  'status',
  'admin_comment',
  'requested_at',
] as const;

const FORBIDDEN_FIELDS = ['created_at', 'updated_at', 'userName', 'startDate', 'endDate'];
const VALID_STATUSES = new Set(['pending', 'approved', 'rejected']);

const WRITE_START = '2099-07-01';
const WRITE_END = '2099-07-05';

async function cleanupVacationWriteTests() {
  await prisma.vacation.deleteMany({
    where: { startOn: { gte: new Date('2099-01-01T00:00:00.000Z') } },
  });
}

async function loadEmployeeAndAdmin() {
  const employee = await prisma.user.findFirst({
    where: { role: 'employee' },
    select: { id: true, firebaseUid: true, role: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });
  const admin = await prisma.user.findFirst({
    where: { role: 'admin' },
    select: { id: true, firebaseUid: true, role: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });
  assert.ok(employee, 'expected a PostgreSQL employee');
  assert.ok(admin, 'expected a PostgreSQL admin');
  assert.notEqual(employee.id, admin.id);
  return { employee, admin };
}

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function expectedVacationsFromPostgres() {
  const rows = await prisma.vacation.findMany({
    select: {
      id: true,
      userId: true,
      startOn: true,
      endOn: true,
      status: true,
      adminComment: true,
      requestedAt: true,
    },
    orderBy: [{ startOn: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    user_id: row.userId,
    start_on: formatDateOnly(row.startOn),
    end_on: formatDateOnly(row.endOn),
    status: row.status,
    admin_comment: row.adminComment,
    requested_at: row.requestedAt.toISOString(),
  }));
}

describe('GET /api/vacations', () => {
  before(async () => {
    await cleanupVacationWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/vacations');
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
      .get('/api/vacations')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 9 PostgreSQL vacations, constraints, and Prisma order', async () => {
    const expected = await expectedVacationsFromPostgres();
    assert.equal(expected.length, 9);

    const userIds = new Set(
      (await prisma.user.findMany({ select: { id: true } })).map((row) => row.id),
    );
    const preview = JSON.parse(
      fs.readFileSync(
        path.join(
          path.dirname(fileURLToPath(import.meta.url)),
          '../migration-preview/vacations.json',
        ),
        'utf8',
      ),
    ) as Array<{ id: string; user_id: string; start_on: string; end_on: string }>;
    const previewKeys = new Set(
      preview.map((row) => `${row.id}|${row.user_id}|${row.start_on}|${row.end_on}`),
    );

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 9);
    assert.deepEqual(res.body, expected);

    for (const row of res.body) {
      assert.deepEqual(Object.keys(row).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(VALID_STATUSES.has(row.status), true);
      assert.ok(row.requested_at);
      assert.equal(userIds.has(row.user_id), true);
      assert.ok(row.start_on <= row.end_on);
      assert.equal(
        previewKeys.has(`${row.id}|${row.user_id}|${row.start_on}|${row.end_on}`),
        true,
      );
    }

    assert.deepEqual(
      res.body.map((row: { start_on: string; id: string }) => [row.start_on, row.id]),
      expected.map((row) => [row.start_on, row.id]),
    );
  });

  it('reads vacations through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.vacation\.findMany/);

    const pgCount = await prisma.vacation.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 9);
  });
});

describe('POST /api/vacations', () => {
  afterEach(async () => {
    await cleanupVacationWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).post('/api/vacations').send({
      start_on: WRITE_START,
      end_on: WRITE_END,
    });
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
      .post('/api/vacations')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
      });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 403 when the Firebase UID is not a PostgreSQL user', async () => {
    const app = createApp(
      mockVerifier(async () => ({
        uid: 'unknown-firebase-uid-vacation-write',
      })),
    );
    const res = await request(app)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
      });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');
  });

  it('returns 400 for invalid dates and when end is before start', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const missing = await request(app)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ start_on: WRITE_START });
    assert.equal(missing.status, 400);
    assert.equal(missing.body.error, 'invalid_vacation');

    const invalidDate = await request(app)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: '2026-13-40',
        end_on: WRITE_END,
      });
    assert.equal(invalidDate.status, 400);

    const inverted = await request(app)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_END,
        end_on: WRITE_START,
      });
    assert.equal(inverted.status, 400);
    assert.equal(inverted.body.error, 'invalid_vacation');
  });

  it('creates a pending vacation for the authenticated owner, not another user', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const impersonate = await request(app)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
        user_id: admin.id,
      });
    assert.equal(impersonate.status, 403);
    assert.equal(impersonate.body.error, 'forbidden');

    const res = await request(app)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.user_id, employee.id);
    assert.notEqual(res.body.user_id, admin.id);
    assert.equal(res.body.start_on, WRITE_START);
    assert.equal(res.body.end_on, WRITE_END);
    assert.equal(res.body.status, 'pending');
    assert.equal(res.body.admin_comment, null);
    assert.ok(res.body.requested_at);

    const pg = await prisma.vacation.findUnique({ where: { id: res.body.id } });
    assert.ok(pg);
    assert.equal(pg.userId, employee.id);
    assert.equal(formatDateOnly(pg.startOn), WRITE_START);
    assert.equal(formatDateOnly(pg.endOn), WRITE_END);
    assert.equal(pg.status, 'pending');
    assert.equal(pg.requestedAt.toISOString(), res.body.requested_at);
  });
});

describe('PATCH /api/vacations/:id', () => {
  afterEach(async () => {
    await cleanupVacationWriteTests();
  });

  it('returns 401 when unauthorized or token is invalid', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app)
      .patch('/api/vacations/00000000-0000-0000-0000-000000000001')
      .send({ status: 'approved' });
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .patch('/api/vacations/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ status: 'approved' });
    assert.equal(invalid.status, 401);
  });

  it('returns 403 when an employee tries to approve or reject', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const created = await request(ownerApp)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
      });
    assert.equal(created.status, 201);

    const res = await request(ownerApp)
      .patch(`/api/vacations/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'approved' });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');

    const pg = await prisma.vacation.findUnique({
      where: { id: created.body.id },
    });
    assert.equal(pg?.status, 'pending');
  });

  it('returns 404 when the vacation does not exist', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );
    const res = await request(app)
      .patch('/api/vacations/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'approved' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('returns 400 for an invalid payload and invalid transition', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const adminApp = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );
    const created = await request(ownerApp)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
      });
    assert.equal(created.status, 201);

    const badStatus = await request(adminApp)
      .patch(`/api/vacations/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'pending' });
    assert.equal(badStatus.status, 400);
    assert.equal(badStatus.body.error, 'invalid_vacation');

    const approved = await request(adminApp)
      .patch(`/api/vacations/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'approved' });
    assert.equal(approved.status, 200);

    const again = await request(adminApp)
      .patch(`/api/vacations/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'rejected' });
    assert.equal(again.status, 400);
    assert.equal(again.body.error, 'invalid_transition');
  });

  it('lets an admin approve and reject, optionally setting admin_comment', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const adminApp = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const toApprove = await request(ownerApp)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: WRITE_START,
        end_on: WRITE_END,
      });
    assert.equal(toApprove.status, 201);

    const approved = await request(adminApp)
      .patch(`/api/vacations/${toApprove.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        status: 'approved',
        admin_comment: 'Covered',
      });
    assert.equal(approved.status, 200);
    assert.equal(approved.body.status, 'approved');
    assert.equal(approved.body.admin_comment, 'Covered');
    assert.equal(approved.body.requested_at, toApprove.body.requested_at);

    const pgApproved = await prisma.vacation.findUnique({
      where: { id: toApprove.body.id },
    });
    assert.equal(pgApproved?.status, 'approved');
    assert.equal(pgApproved?.adminComment, 'Covered');

    const toReject = await request(ownerApp)
      .post('/api/vacations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_on: '2099-07-10',
        end_on: '2099-07-12',
      });
    assert.equal(toReject.status, 201);

    const rejected = await request(adminApp)
      .patch(`/api/vacations/${toReject.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'rejected' });
    assert.equal(rejected.status, 200);
    assert.equal(rejected.body.status, 'rejected');
    assert.equal(rejected.body.admin_comment, null);

    const pgRejected = await prisma.vacation.findUnique({
      where: { id: toReject.body.id },
    });
    assert.equal(pgRejected?.status, 'rejected');
    assert.equal(pgRejected?.adminComment, null);
  });
});

