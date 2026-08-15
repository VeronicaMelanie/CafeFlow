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
  'work_date',
  'shift_type',
  'custom_start_time',
  'custom_end_time',
  'submitted_at',
] as const;

const FORBIDDEN_FIELDS = ['created_at', 'updated_at', 'is_full_day'];
const VALID_SHIFT_TYPES = new Set(['full_time', 'custom_hours']);

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function formatTimeOnly(value: Date | string | null): string | null {
  if (value == null) return null;
  if (typeof value === 'string') {
    const match = value.match(/^(\d{2}:\d{2}:\d{2})/);
    return match ? match[1] : value;
  }
  const hours = String(value.getUTCHours()).padStart(2, '0');
  const minutes = String(value.getUTCMinutes()).padStart(2, '0');
  const seconds = String(value.getUTCSeconds()).padStart(2, '0');
  return `${hours}:${minutes}:${seconds}`;
}

const WRITE_DATES = ['2099-06-15', '2099-06-16', '2099-06-17'] as const;

async function cleanupAvailabilityWriteTests() {
  await prisma.availability.deleteMany({
    where: {
      workDate: {
        in: WRITE_DATES.map((day) => new Date(`${day}T00:00:00.000Z`)),
      },
    },
  });
}

async function expectedAvailabilityFromPostgres() {
  const rows = await prisma.availability.findMany({
    select: {
      id: true,
      userId: true,
      workDate: true,
      shiftType: true,
      customStartTime: true,
      customEndTime: true,
      submittedAt: true,
    },
    orderBy: [{ workDate: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    user_id: row.userId,
    work_date: formatDateOnly(row.workDate),
    shift_type: row.shiftType,
    custom_start_time: formatTimeOnly(row.customStartTime),
    custom_end_time: formatTimeOnly(row.customEndTime),
    submitted_at: row.submittedAt.toISOString(),
  }));
}

describe('GET /api/availability', () => {
  before(async () => {
    await cleanupAvailabilityWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/availability');
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
      .get('/api/availability')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 64 PostgreSQL availability rows and schema constraints', async () => {
    const expected = await expectedAvailabilityFromPostgres();
    assert.equal(expected.length, 64);

    const preview = JSON.parse(
      fs.readFileSync(
        path.join(
          path.dirname(fileURLToPath(import.meta.url)),
          '../migration-preview/availability.json',
        ),
        'utf8',
      ),
    ) as Array<{ id: string; user_id: string; work_date: string }>;
    const previewKeys = new Set(preview.map((row) => `${row.user_id}|${row.work_date}`));

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/availability')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 64);
    assert.deepEqual(res.body, expected);

    for (const row of res.body) {
      assert.deepEqual(Object.keys(row).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(VALID_SHIFT_TYPES.has(row.shift_type), true);
      assert.ok(row.submitted_at);
      assert.notEqual(row.submitted_at, null);
      assert.equal(previewKeys.has(`${row.user_id}|${row.work_date}`), true);

      if (row.shift_type === 'full_time') {
        assert.equal(row.custom_start_time, null);
        assert.equal(row.custom_end_time, null);
      } else {
        assert.ok(row.custom_start_time);
        assert.ok(row.custom_end_time);
      }
    }

    assert.deepEqual(
      res.body.map((row: { work_date: string; id: string }) => [row.work_date, row.id]),
      expected.map((row) => [row.work_date, row.id]),
    );
  });

  it('reads availability through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.availability\.findMany/);

    const pgCount = await prisma.availability.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/availability')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 64);
  });
});

async function loadTwoUsers() {
  const users = await prisma.user.findMany({
    select: { id: true, firebaseUid: true, role: true },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
    take: 2,
  });
  assert.ok(users[0], 'expected at least one PostgreSQL user');
  assert.ok(users[1], 'expected a second PostgreSQL user for authorization tests');
  return { actor: users[0], other: users[1] };
}

describe('POST /api/availability', () => {
  afterEach(async () => {
    await cleanupAvailabilityWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).post('/api/availability').send({
      work_date: WRITE_DATES[0],
      shift_type: 'full_time',
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
      .post('/api/availability')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 403 when the Firebase UID is not a PostgreSQL user', async () => {
    const app = createApp(
      mockVerifier(async () => ({
        uid: 'unknown-firebase-uid-availability-write',
        email: 'ghost@example.com',
      })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');
    assert.equal(
      await prisma.availability.count({
        where: { workDate: new Date(`${WRITE_DATES[0]}T00:00:00.000Z`) },
      }),
      0,
    );
  });

  it('returns 400 for an invalid payload', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ shift_type: 'full_time' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_availability');
  });

  it('returns 400 for an invalid DATE', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: '2026-13-40',
        shift_type: 'full_time',
      });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_availability');
  });

  it('returns 400 for invalid TIME', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'custom_hours',
        custom_start_time: '25:00:00',
        custom_end_time: '10:00:00',
      });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_availability');
  });

  it('returns 400 when custom end TIME is not after start', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'custom_hours',
        custom_start_time: '16:00:00',
        custom_end_time: '10:00:00',
      });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_availability');
  });

  it('creates a full_time row for the authenticated user and writes PostgreSQL', async () => {
    const { actor, other } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
        user_id: other.id,
      });

    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');

    const allowed = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(allowed.status, 201);
    assert.equal(allowed.body.user_id, actor.id);
    assert.notEqual(allowed.body.user_id, other.id);
    assert.equal(allowed.body.work_date, WRITE_DATES[0]);
    assert.equal(allowed.body.shift_type, 'full_time');
    assert.equal(allowed.body.custom_start_time, null);
    assert.equal(allowed.body.custom_end_time, null);
    assert.ok(allowed.body.submitted_at);

    const pg = await prisma.availability.findUnique({
      where: { id: allowed.body.id },
    });
    assert.ok(pg);
    assert.equal(pg.userId, actor.id);
    assert.equal(formatDateOnly(pg.workDate), WRITE_DATES[0]);
    assert.equal(pg.shiftType, 'full_time');
    assert.equal(formatTimeOnly(pg.customStartTime), null);
  });

  it('creates custom_hours with wall-clock TIME, not UTC conversion', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'custom_hours',
        custom_start_time: '07:30:00',
        custom_end_time: '12:15:00',
      });
    assert.equal(res.status, 201);
    assert.equal(res.body.custom_start_time, '07:30:00');
    assert.equal(res.body.custom_end_time, '12:15:00');
    assert.equal(res.body.work_date, WRITE_DATES[0]);

    const pg = await prisma.availability.findUnique({
      where: { id: res.body.id },
    });
    assert.ok(pg);
    assert.equal(formatTimeOnly(pg.customStartTime), '07:30:00');
    assert.equal(formatTimeOnly(pg.customEndTime), '12:15:00');
  });

  it('returns 409 on duplicate user_id + work_date', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const first = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(first.status, 201);

    const second = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'custom_hours',
        custom_start_time: '08:00:00',
        custom_end_time: '12:00:00',
      });
    assert.equal(second.status, 409);
    assert.equal(second.body.error, 'conflict');
    assert.equal(
      await prisma.availability.count({
        where: {
          userId: actor.id,
          workDate: new Date(`${WRITE_DATES[0]}T00:00:00.000Z`),
        },
      }),
      1,
    );
  });
});

describe('PATCH /api/availability/:id', () => {
  afterEach(async () => {
    await cleanupAvailabilityWriteTests();
  });

  it('returns 401 when unauthorized', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .patch('/api/availability/00000000-0000-0000-0000-000000000001')
      .send({ shift_type: 'full_time' });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 401 for an invalid token', async () => {
    const app = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const res = await request(app)
      .patch('/api/availability/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ shift_type: 'full_time' });
    assert.equal(res.status, 401);
  });

  it('returns 400 for an invalid payload', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const created = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(created.status, 201);

    const res = await request(app)
      .patch(`/api/availability/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ shift_type: 'not_a_shift' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_availability');
  });

  it('returns 404 when the row does not exist', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(app)
      .patch('/api/availability/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ shift_type: 'full_time' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('returns 403 when a user patches another user availability', async () => {
    const { actor, other } = await loadTwoUsers();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: other.firebaseUid })),
    );
    const created = await request(ownerApp)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(created.status, 201);

    const actorApp = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const res = await request(actorApp)
      .patch(`/api/availability/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        shift_type: 'custom_hours',
        custom_start_time: '08:00:00',
        custom_end_time: '11:00:00',
      });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');

    const pg = await prisma.availability.findUnique({
      where: { id: created.body.id },
    });
    assert.ok(pg);
    assert.equal(pg.userId, other.id);
    assert.equal(pg.shiftType, 'full_time');
  });

  it('updates the owner row in PostgreSQL and preserves submitted_at', async () => {
    const { actor } = await loadTwoUsers();
    const app = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const created = await request(app)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(created.status, 201);
    const originalSubmittedAt = created.body.submitted_at;

    const res = await request(app)
      .patch(`/api/availability/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'custom_hours',
        custom_start_time: '09:00:00',
        custom_end_time: '14:00:00',
      });
    assert.equal(res.status, 200);
    assert.equal(res.body.shift_type, 'custom_hours');
    assert.equal(res.body.custom_start_time, '09:00:00');
    assert.equal(res.body.custom_end_time, '14:00:00');
    assert.equal(res.body.submitted_at, originalSubmittedAt);

    const pg = await prisma.availability.findUnique({
      where: { id: created.body.id },
    });
    assert.ok(pg);
    assert.equal(pg.shiftType, 'custom_hours');
    assert.equal(formatTimeOnly(pg.customStartTime), '09:00:00');
    assert.equal(formatTimeOnly(pg.customEndTime), '14:00:00');
    assert.equal(pg.submittedAt.toISOString(), originalSubmittedAt);
  });
});

describe('DELETE /api/availability/:id', () => {
  afterEach(async () => {
    await cleanupAvailabilityWriteTests();
  });

  it('lets the owner delete their row and forbids deleting another user', async () => {
    const { actor, other } = await loadTwoUsers();
    const ownerApp = createApp(
      mockVerifier(async () => ({ uid: other.firebaseUid })),
    );
    const created = await request(ownerApp)
      .post('/api/availability')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        work_date: WRITE_DATES[0],
        shift_type: 'full_time',
      });
    assert.equal(created.status, 201);

    const actorApp = createApp(
      mockVerifier(async () => ({ uid: actor.firebaseUid })),
    );
    const forbidden = await request(actorApp)
      .delete(`/api/availability/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(forbidden.status, 403);

    const deleted = await request(ownerApp)
      .delete(`/api/availability/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(deleted.status, 204);
    assert.equal(
      await prisma.availability.findUnique({ where: { id: created.body.id } }),
      null,
    );
  });
});

