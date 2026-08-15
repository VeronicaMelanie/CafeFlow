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
  'year',
  'month',
  'location_id',
  'scheduling_enabled',
  'locked_month',
  'enabled_by',
  'enabled_at',
  'max_hours_per_day',
  'max_employees_per_shift',
] as const;

const FORBIDDEN_FIELDS = ['created_at', 'updated_at', 'location', 'enabledBy'];

async function expectedSchedulingFromPostgres() {
  const rows = await prisma.schedulingConfig.findMany({
    select: {
      id: true,
      year: true,
      month: true,
      locationId: true,
      schedulingEnabled: true,
      lockedMonth: true,
      enabledById: true,
      enabledAt: true,
      maxHoursPerDay: true,
      maxEmployeesPerShift: true,
    },
    orderBy: [{ year: 'asc' }, { month: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    year: row.year,
    month: row.month,
    location_id: row.locationId,
    scheduling_enabled: row.schedulingEnabled,
    locked_month: row.lockedMonth,
    enabled_by: row.enabledById,
    enabled_at: row.enabledAt ? row.enabledAt.toISOString() : null,
    max_hours_per_day: row.maxHoursPerDay === null ? null : Number(row.maxHoursPerDay),
    max_employees_per_shift: row.maxEmployeesPerShift,
  }));
}

const WRITE_YEAR = 2099;
const WRITE_MONTH = 8;

async function cleanupSchedulingWriteTests() {
  await prisma.schedulingConfig.deleteMany({
    where: { year: WRITE_YEAR },
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

describe('GET /api/scheduling', () => {
  before(async () => {
    await cleanupSchedulingWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/scheduling');
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
      .get('/api/scheduling')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 4 PostgreSQL scheduling configs, constraints, and Prisma order', async () => {
    const expected = await expectedSchedulingFromPostgres();
    assert.equal(expected.length, 4);

    const userIds = new Set(
      (await prisma.user.findMany({ select: { id: true } })).map((row) => row.id),
    );
    const locationIds = new Set(
      (await prisma.location.findMany({ select: { id: true } })).map((row) => row.id),
    );
    const preview = JSON.parse(
      fs.readFileSync(
        path.join(
          path.dirname(fileURLToPath(import.meta.url)),
          '../migration-preview/scheduling_config.json',
        ),
        'utf8',
      ),
    ) as Array<{ id: string; year: number; month: number }>;
    const previewIds = new Set(preview.map((row) => row.id));

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 4);
    assert.deepEqual(res.body, expected);

    const seenYearMonth = new Set<string>();
    for (const row of res.body) {
      assert.deepEqual(Object.keys(row).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.ok(row.month >= 1 && row.month <= 12);
      assert.ok(row.year >= 2000 && row.year <= 2100);
      assert.equal(previewIds.has(row.id), true);
      if (row.location_id !== null) {
        assert.equal(locationIds.has(row.location_id), true);
      }
      if (row.enabled_by !== null) {
        assert.equal(userIds.has(row.enabled_by), true);
      }
      if (row.max_hours_per_day !== null) {
        assert.ok(row.max_hours_per_day > 0);
      }
      if (row.max_employees_per_shift !== null) {
        assert.ok(row.max_employees_per_shift > 0);
      }
      const key = `${row.year}|${row.month}|${row.location_id}`;
      assert.equal(seenYearMonth.has(key), false);
      seenYearMonth.add(key);
    }

    assert.deepEqual(
      res.body.map((row: { year: number; month: number; id: string }) => [
        row.year,
        row.month,
        row.id,
      ]),
      expected.map((row) => [row.year, row.month, row.id]),
    );
  });

  it('reads scheduling through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.schedulingConfig\.findMany/);
    assert.match(appSource, /prisma\.schedulingConfig\.create/);
    assert.match(appSource, /prisma\.schedulingConfig\.update/);

    const pgCount = await prisma.schedulingConfig.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 4);
  });
});

describe('POST /api/scheduling', () => {
  afterEach(async () => {
    await cleanupSchedulingWriteTests();
  });

  it('returns 401 when unauthorized or token is invalid', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app).post('/api/scheduling').send({
      year: WRITE_YEAR,
      month: WRITE_MONTH,
      scheduling_enabled: true,
    });
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        scheduling_enabled: true,
      });
    assert.equal(invalid.status, 401);
    assert.equal(invalid.body.error, 'unauthorized');
  });

  it('returns 403 for an unknown Firebase user and for an employee', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const unknownApp = createApp(
      mockVerifier(async () => ({ uid: 'no-such-firebase-uid' })),
    );
    const unknown = await request(unknownApp)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        scheduling_enabled: true,
      });
    assert.equal(unknown.status, 403);
    assert.equal(unknown.body.error, 'forbidden');

    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const employeeRes = await request(employeeApp)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        scheduling_enabled: true,
      });
    assert.equal(employeeRes.status, 403);
    assert.equal(employeeRes.body.error, 'forbidden');
    assert.equal(
      await prisma.schedulingConfig.count({ where: { year: WRITE_YEAR } }),
      0,
    );
  });

  it('returns 400 for invalid year or month', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const invalidYear = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: 1999,
        month: WRITE_MONTH,
        scheduling_enabled: true,
      });
    assert.equal(invalidYear.status, 400);
    assert.equal(invalidYear.body.error, 'invalid_scheduling');

    const invalidMonth = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: 13,
        scheduling_enabled: true,
      });
    assert.equal(invalidMonth.status, 400);
    assert.equal(invalidMonth.body.error, 'invalid_scheduling');
  });

  it('returns 404 for an unknown location name and 400/404 for an invalid location id', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const unknownName = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        location: 'NotACafe',
        scheduling_enabled: true,
      });
    assert.equal(unknownName.status, 404);
    assert.equal(unknownName.body.error, 'not_found');

    const badUuid = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        location_id: 'not-a-uuid',
        scheduling_enabled: true,
      });
    assert.equal(badUuid.status, 400);
    assert.equal(badUuid.body.error, 'invalid_scheduling');

    const missingLocation = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        location_id: '00000000-0000-0000-0000-000000000001',
        scheduling_enabled: true,
      });
    assert.equal(missingLocation.status, 404);
    assert.equal(missingLocation.body.error, 'not_found');
  });

  it('lets an admin create a global config, maps enabled_by from the token, and ignores spoofed enabled_by', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const res = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        scheduling_enabled: true,
        enabled_by: employee.id,
        max_hours_per_day: 22,
        max_employees_per_shift: 2,
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.year, WRITE_YEAR);
    assert.equal(res.body.month, WRITE_MONTH);
    assert.equal(res.body.location_id, null);
    assert.equal(res.body.scheduling_enabled, true);
    assert.equal(res.body.locked_month, false);
    assert.equal(res.body.enabled_by, admin.id);
    assert.notEqual(res.body.enabled_by, employee.id);
    assert.equal(res.body.max_hours_per_day, null);
    assert.equal(res.body.max_employees_per_shift, null);
    assert.ok(res.body.enabled_at);

    const pg = await prisma.schedulingConfig.findUnique({
      where: { id: res.body.id },
    });
    assert.ok(pg);
    assert.equal(pg.locationId, null);
    assert.equal(pg.enabledById, admin.id);
    assert.equal(pg.maxHoursPerDay, null);
    assert.equal(pg.maxEmployeesPerShift, null);
    assert.equal(pg.schedulingEnabled, true);
    assert.equal(pg.lockedMonth, false);

    const duplicate = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        scheduling_enabled: true,
      });
    assert.equal(duplicate.status, 409);
    assert.equal(duplicate.body.error, 'conflict');
  });

  it('maps a location name to location_id and does not store the display name', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const gara = await loadGaraLocation();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const res = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        location: 'Gara',
        scheduling_enabled: true,
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.location_id, gara.id);
    assert.equal(Object.hasOwn(res.body, 'location'), false);

    const pg = await prisma.schedulingConfig.findUnique({
      where: { id: res.body.id },
    });
    assert.equal(pg?.locationId, gara.id);
  });
});

describe('PATCH /api/scheduling/:id', () => {
  afterEach(async () => {
    await cleanupSchedulingWriteTests();
  });

  async function createWriteConfig(adminUid: string) {
    const app = createApp(mockVerifier(async () => ({ uid: adminUid })));
    const created = await request(app)
      .post('/api/scheduling')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        year: WRITE_YEAR,
        month: WRITE_MONTH,
        scheduling_enabled: true,
      });
    assert.equal(created.status, 201);
    return { app, id: created.body.id as string, created: created.body };
  }

  it('returns 401 when unauthorized or token is invalid', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app)
      .patch('/api/scheduling/00000000-0000-0000-0000-000000000001')
      .send({ scheduling_enabled: false });
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .patch('/api/scheduling/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ scheduling_enabled: false });
    assert.equal(invalid.status, 401);
  });

  it('returns 403 when an employee tries to update config', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { id } = await createWriteConfig(admin.firebaseUid);
    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(employeeApp)
      .patch(`/api/scheduling/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ scheduling_enabled: false });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');

    const pg = await prisma.schedulingConfig.findUnique({ where: { id } });
    assert.equal(pg?.schedulingEnabled, true);
  });

  it('returns 404 when the config does not exist', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );
    const res = await request(app)
      .patch('/api/scheduling/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ locked_month: true });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('returns 400 for an invalid payload', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const { app, id } = await createWriteConfig(admin.firebaseUid);

    const empty = await request(app)
      .patch(`/api/scheduling/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({});
    assert.equal(empty.status, 400);
    assert.equal(empty.body.error, 'invalid_scheduling');

    const badType = await request(app)
      .patch(`/api/scheduling/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ scheduling_enabled: 'yes' });
    assert.equal(badType.status, 400);
    assert.equal(badType.body.error, 'invalid_scheduling');

    const badId = await request(app)
      .patch('/api/scheduling/not-a-uuid')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ locked_month: true });
    assert.equal(badId.status, 400);
    assert.equal(badId.body.error, 'invalid_scheduling');
  });

  it('lets an admin lock the month without changing enabled_by, and disable scheduling from the token', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { app, id, created } = await createWriteConfig(admin.firebaseUid);
    assert.equal(created.enabled_by, admin.id);

    const locked = await request(app)
      .patch(`/api/scheduling/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        locked_month: true,
        enabled_by: employee.id,
      });
    assert.equal(locked.status, 200);
    assert.equal(locked.body.locked_month, true);
    assert.equal(locked.body.scheduling_enabled, true);
    assert.equal(locked.body.enabled_by, admin.id);
    assert.equal(locked.body.enabled_at, created.enabled_at);

    const pgLocked = await prisma.schedulingConfig.findUnique({
      where: { id },
    });
    assert.equal(pgLocked?.lockedMonth, true);
    assert.equal(pgLocked?.enabledById, admin.id);
    assert.equal(pgLocked?.schedulingEnabled, true);

    const disabled = await request(app)
      .patch(`/api/scheduling/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        scheduling_enabled: false,
        enabled_by: employee.id,
      });
    assert.equal(disabled.status, 200);
    assert.equal(disabled.body.scheduling_enabled, false);
    assert.equal(disabled.body.locked_month, false);
    assert.equal(disabled.body.enabled_by, admin.id);
    assert.notEqual(disabled.body.enabled_by, employee.id);
    assert.ok(disabled.body.enabled_at);

    const pgDisabled = await prisma.schedulingConfig.findUnique({
      where: { id },
    });
    assert.equal(pgDisabled?.schedulingEnabled, false);
    assert.equal(pgDisabled?.lockedMonth, false);
    assert.equal(pgDisabled?.enabledById, admin.id);
    assert.equal(pgDisabled?.maxHoursPerDay, null);
    assert.equal(pgDisabled?.maxEmployeesPerShift, null);
  });
});
