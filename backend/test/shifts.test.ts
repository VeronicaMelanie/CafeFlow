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
  'location_id',
  'work_date',
  'start_at',
  'end_at',
  'type',
  'status',
] as const;

const FORBIDDEN_FIELDS = ['created_at', 'updated_at'];

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

async function expectedShiftsFromPostgres() {
  const rows = await prisma.shift.findMany({
    select: {
      id: true,
      userId: true,
      locationId: true,
      workDate: true,
      startAt: true,
      endAt: true,
      shiftType: true,
      status: true,
    },
    orderBy: [{ workDate: 'asc' }, { startAt: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    user_id: row.userId,
    location_id: row.locationId,
    work_date: formatDateOnly(row.workDate),
    start_at: row.startAt.toISOString(),
    end_at: row.endAt.toISOString(),
    type: row.shiftType,
    status: row.status,
  }));
}

const WRITE_DATE = '2099-08-15';
const WRITE_START = '2099-08-15T04:30:00.000Z';
const WRITE_END = '2099-08-15T15:30:00.000Z';

async function cleanupShiftWriteTests() {
  await prisma.shift.deleteMany({
    where: { workDate: { gte: new Date('2099-01-01T00:00:00.000Z') } },
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

async function loadGaraLocation() {
  const location = await prisma.location.findFirst({
    where: { name: 'Gara' },
    select: { id: true, name: true },
  });
  assert.ok(location, 'expected PostgreSQL location Gara');
  return location;
}

function shiftPayload(overrides: Record<string, unknown> = {}) {
  return {
    work_date: WRITE_DATE,
    start_at: WRITE_START,
    end_at: WRITE_END,
    type: 'CUSTOM',
    status: 'approved',
    location: 'Gara',
    ...overrides,
  };
}

describe('GET /api/shifts', () => {
  before(async () => {
    await cleanupShiftWriteTests();
  });
  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/shifts');
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
      .get('/api/shifts')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 1 PostgreSQL shift, ordered, without forbidden fields', async () => {
    const expected = await expectedShiftsFromPostgres();
    assert.equal(expected.length, 1);

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 1);
    assert.deepEqual(res.body, expected);

    const shift = res.body[0];
    assert.equal(shift.id, '33ac4f49-7d6b-4624-8156-f010f86813eb');
    assert.equal(shift.user_id, 'de3180fa-77c6-4dd5-a6dc-95052760acd9');
    assert.equal(shift.location_id, 'ff63f35a-ddd1-449e-9021-33ee78e2261a');
    assert.equal(shift.work_date, '2026-05-17');
    assert.equal(shift.start_at, '2026-05-17T04:00:00.000Z');
    assert.equal(shift.end_at, '2026-05-17T15:00:00.000Z');
    assert.equal(shift.type, 'CUSTOM');
    assert.equal(shift.status, 'pending');
    assert.ok(new Date(shift.end_at) >= new Date(shift.start_at));

    assert.deepEqual(Object.keys(shift).sort(), [...ALLOWED_FIELDS].sort());
    for (const field of FORBIDDEN_FIELDS) {
      assert.equal(Object.hasOwn(shift, field), false);
    }

    assert.deepEqual(
      res.body.map((row: { work_date: string; start_at: string; id: string }) => [
        row.work_date,
        row.start_at,
        row.id,
      ]),
      expected.map((row) => [row.work_date, row.start_at, row.id]),
    );
  });

  it('reads shifts through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.shift\.findMany/);
    assert.match(appSource, /prisma\.shift\.create/);
    assert.match(appSource, /prisma\.\$transaction/);

    const pgCount = await prisma.shift.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 1);
  });
});

describe('POST /api/shifts', () => {
  afterEach(async () => {
    await cleanupShiftWriteTests();
  });

  it('returns 401 when unauthorized or token is invalid', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app)
      .post('/api/shifts')
      .send(shiftPayload({ user_id: employee.id }));
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .post('/api/shifts')
      .set('Authorization', 'Bearer not-a-real-token')
      .send(shiftPayload({ user_id: employee.id }));
    assert.equal(invalid.status, 401);
  });

  it('returns 403 for an unknown Firebase user and when an employee impersonates', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const unknownApp = createApp(
      mockVerifier(async () => ({ uid: 'no-such-firebase-uid' })),
    );
    const unknown = await request(unknownApp)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id }));
    assert.equal(unknown.status, 403);

    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const impersonate = await request(employeeApp)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: admin.id }));
    assert.equal(impersonate.status, 403);
    assert.equal(impersonate.body.error, 'forbidden');
    assert.equal(
      await prisma.shift.count({
        where: { workDate: new Date('2099-08-15T00:00:00.000Z') },
      }),
      0,
    );
  });

  it('returns 400 for invalid date, time, range, and 404 for unknown user/location', async () => {
    const { admin, employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const badDate = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id, work_date: '2099-13-40' }));
    assert.equal(badDate.status, 400);
    assert.equal(badDate.body.error, 'invalid_shift');

    const badTime = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id, start_at: '07:30:00' }));
    assert.equal(badTime.status, 400);
    assert.equal(badTime.body.error, 'invalid_shift');

    const badRange = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(
        shiftPayload({
          user_id: employee.id,
          start_at: WRITE_END,
          end_at: WRITE_START,
        }),
      );
    assert.equal(badRange.status, 400);
    assert.equal(badRange.body.error, 'invalid_shift');

    const unknownUser = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(
        shiftPayload({ user_id: '00000000-0000-0000-0000-000000000001' }),
      );
    assert.equal(unknownUser.status, 404);

    const unknownLocation = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id, location: 'NotACafe' }));
    assert.equal(unknownLocation.status, 404);

    const badLocationId = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id, location_id: 'not-a-uuid' }));
    assert.equal(badLocationId.status, 400);
  });

  it('lets an admin create a shift with location name → UUID and DATE/TIMESTAMPTZ', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const gara = await loadGaraLocation();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const res = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        ...shiftPayload({ user_id: employee.id }),
        userName: 'Spoofed',
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.user_id, employee.id);
    assert.equal(res.body.location_id, gara.id);
    assert.equal(res.body.work_date, WRITE_DATE);
    assert.equal(res.body.start_at, WRITE_START);
    assert.equal(res.body.end_at, WRITE_END);
    assert.equal(res.body.type, 'CUSTOM');
    assert.equal(res.body.status, 'approved');
    assert.equal(Object.hasOwn(res.body, 'userName'), false);
    assert.equal(Object.hasOwn(res.body, 'location'), false);

    const pg = await prisma.shift.findUnique({ where: { id: res.body.id } });
    assert.ok(pg);
    assert.equal(pg.userId, employee.id);
    assert.equal(pg.locationId, gara.id);
    assert.equal(formatDateOnly(pg.workDate), WRITE_DATE);
    assert.equal(pg.startAt.toISOString(), WRITE_START);
    assert.equal(pg.endAt.toISOString(), WRITE_END);
  });

  it('lets an employee create a shift only for themselves', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id }));
    assert.equal(res.status, 201);
    assert.equal(res.body.user_id, employee.id);
  });
});

describe('PATCH /api/shifts/:id', () => {
  afterEach(async () => {
    await cleanupShiftWriteTests();
  });

  async function createWriteShift(adminUid: string, userId: string) {
    const app = createApp(mockVerifier(async () => ({ uid: adminUid })));
    const created = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: userId }));
    assert.equal(created.status, 201);
    return { app, id: created.body.id as string };
  }

  it('returns 401 when unauthorized or token is invalid', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app)
      .patch('/api/shifts/00000000-0000-0000-0000-000000000001')
      .send({ status: 'pending' });
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .patch('/api/shifts/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ status: 'pending' });
    assert.equal(invalid.status, 401);
  });

  it('returns 403 when an employee patches another user shift', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { id } = await createWriteShift(admin.firebaseUid, admin.id);
    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(employeeApp)
      .patch(`/api/shifts/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'pending' });
    assert.equal(res.status, 403);
  });

  it('returns 404 when the shift does not exist and 400 for invalid range', async () => {
    const { admin, employee } = await loadEmployeeAndAdmin();
    const { app, id } = await createWriteShift(admin.firebaseUid, employee.id);

    const missing = await request(app)
      .patch('/api/shifts/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ status: 'pending' });
    assert.equal(missing.status, 404);

    const badRange = await request(app)
      .patch(`/api/shifts/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ start_at: WRITE_END, end_at: WRITE_START });
    assert.equal(badRange.status, 400);
    assert.equal(badRange.body.error, 'invalid_shift');
  });

  it('lets an admin update times and status without changing user_id', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { app, id } = await createWriteShift(admin.firebaseUid, employee.id);
    const nextStart = '2099-08-15T05:00:00.000Z';
    const nextEnd = '2099-08-15T14:00:00.000Z';

    const res = await request(app)
      .patch(`/api/shifts/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        start_at: nextStart,
        end_at: nextEnd,
        status: 'pending',
        user_id: admin.id,
      });
    assert.equal(res.status, 200);
    assert.equal(res.body.user_id, employee.id);
    assert.equal(res.body.start_at, nextStart);
    assert.equal(res.body.end_at, nextEnd);
    assert.equal(res.body.status, 'pending');

    const pg = await prisma.shift.findUnique({ where: { id } });
    assert.equal(pg?.userId, employee.id);
    assert.equal(pg?.status, 'pending');
    assert.equal(pg?.startAt.toISOString(), nextStart);
  });
});

describe('DELETE /api/shifts/:id', () => {
  afterEach(async () => {
    await cleanupShiftWriteTests();
  });

  it('returns 401 when unauthorized', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).delete(
      '/api/shifts/00000000-0000-0000-0000-000000000001',
    );
    assert.equal(res.status, 401);
  });

  it('returns 403 when an employee deletes another user shift', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const adminApp = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );
    const created = await request(adminApp)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: admin.id }));
    assert.equal(created.status, 201);

    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(employeeApp)
      .delete(`/api/shifts/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 403);
    assert.ok(
      await prisma.shift.findUnique({ where: { id: created.body.id } }),
    );
  });

  it('returns 404 when the shift does not exist', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );
    const res = await request(app)
      .delete('/api/shifts/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 404);
  });

  it('lets an admin delete a shift from PostgreSQL', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );
    const created = await request(app)
      .post('/api/shifts')
      .set('Authorization', 'Bearer valid-id-token')
      .send(shiftPayload({ user_id: employee.id }));
    assert.equal(created.status, 201);

    const res = await request(app)
      .delete(`/api/shifts/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 204);
    assert.equal(
      await prisma.shift.findUnique({ where: { id: created.body.id } }),
      null,
    );
  });
});

describe('POST /api/shifts/bulk', () => {
  afterEach(async () => {
    await cleanupShiftWriteTests();
  });

  it('returns 401 when unauthorized and 403 for an employee', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app)
      .post('/api/shifts/bulk')
      .send({ shifts: [shiftPayload({ user_id: employee.id })] });
    assert.equal(missing.status, 401);

    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const forbidden = await request(employeeApp)
      .post('/api/shifts/bulk')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ shifts: [shiftPayload({ user_id: employee.id })] });
    assert.equal(forbidden.status, 403);
    assert.equal(
      await prisma.shift.count({
        where: { workDate: new Date('2099-08-15T00:00:00.000Z') },
      }),
      0,
    );
  });

  it('creates all rows in a transaction and rolls back when one item is invalid', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const gara = await loadGaraLocation();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const created = await request(app)
      .post('/api/shifts/bulk')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        shifts: [
          shiftPayload({ user_id: employee.id, status: 'approved' }),
          shiftPayload({
            user_id: admin.id,
            start_at: '2099-08-15T06:00:00.000Z',
            end_at: '2099-08-15T12:00:00.000Z',
            type: 'FULL',
            status: 'approved',
          }),
        ],
      });
    assert.equal(created.status, 201);
    assert.equal(created.body.length, 2);
    assert.equal(created.body[0].location_id, gara.id);
    assert.equal(created.body[0].user_id, employee.id);
    assert.equal(created.body[1].user_id, admin.id);
    assert.equal(
      await prisma.shift.count({
        where: { workDate: new Date('2099-08-15T00:00:00.000Z') },
      }),
      2,
    );

    await cleanupShiftWriteTests();

    const failed = await request(app)
      .post('/api/shifts/bulk')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        shifts: [
          shiftPayload({ user_id: employee.id }),
          shiftPayload({ user_id: admin.id, location: 'NotACafe' }),
        ],
      });
    assert.equal(failed.status, 404);
    assert.equal(
      await prisma.shift.count({
        where: { workDate: new Date('2099-08-15T00:00:00.000Z') },
      }),
      0,
    );
  });
});
