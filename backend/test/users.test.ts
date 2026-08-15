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
  'firebase_uid',
  'email',
  'name',
  'role',
  'contract_type',
  'employment_started_on',
  'monthly_target_hours',
  'needs_contract_type',
  'auth_provider',
] as const;

const FORBIDDEN_FIELDS = ['fcm_token', 'created_at', 'updated_at'];

function formatDateOnly(value: Date | null): string | null {
  if (!value) return null;
  const year = value.getUTCFullYear();
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  const day = String(value.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

const TEST_UID_PREFIX = 'profile-write-test-';

async function cleanupProfileWriteTests() {
  await prisma.user.deleteMany({
    where: { firebaseUid: { startsWith: TEST_UID_PREFIX } },
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

function writeTestUser(overrides: Partial<AuthenticatedUser> = {}): AuthenticatedUser {
  return {
    uid: `${TEST_UID_PREFIX}create`,
    email: 'profile-write-test@example.com',
    name: 'Write Profile Employee',
    authProvider: 'google.com',
    ...overrides,
  };
}

async function expectedUsersFromPostgres() {
  const rows = await prisma.user.findMany({
    select: {
      id: true,
      firebaseUid: true,
      email: true,
      name: true,
      role: true,
      contractType: true,
      employmentStartedOn: true,
      monthlyTargetHours: true,
      needsContractType: true,
      authProvider: true,
    },
    orderBy: [{ name: 'asc' }, { id: 'asc' }],
  });

  return rows.map((row) => ({
    id: row.id,
    firebase_uid: row.firebaseUid,
    email: row.email,
    name: row.name,
    role: row.role,
    contract_type: row.contractType,
    employment_started_on: formatDateOnly(row.employmentStartedOn),
    monthly_target_hours: row.monthlyTargetHours,
    needs_contract_type: row.needsContractType,
    auth_provider: row.authProvider,
  }));
}

describe('GET /api/users', () => {
  before(async () => {
    await cleanupProfileWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/users');
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
      .get('/api/users')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with the 10 PostgreSQL users, ordered, without forbidden fields', async () => {
    const expected = await expectedUsersFromPostgres();
    assert.equal(expected.length, 10);

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.ok(Array.isArray(res.body));
    assert.equal(res.body.length, 10);
    assert.deepEqual(res.body, expected);

    for (const user of res.body) {
      assert.deepEqual(Object.keys(user).sort(), [...ALLOWED_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(user, field), false);
      }
    }

    assert.deepEqual(
      res.body.map((user: { name: string; id: string }) => [user.name, user.id]),
      expected.map((user) => [user.name, user.id]),
    );
  });

  it('reads users through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.user\.findMany/);
    assert.match(appSource, /prisma\.user\.create/);
    assert.match(appSource, /prisma\.user\.update/);

    const pgCount = await prisma.user.count();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.length, pgCount);
    assert.equal(res.body.length, 10);
  });
});

describe('POST /api/users', () => {
  afterEach(async () => {
    await cleanupProfileWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => writeTestUser()));
    const res = await request(app).post('/api/users').send({ name: 'Nope' });
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
      .post('/api/users')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ name: 'Nope' });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('rejects a spoofed firebase_uid and does not create a row', async () => {
    const tokenUser = writeTestUser();
    const app = createApp(mockVerifier(async () => tokenUser));
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ firebase_uid: 'spoofed-firebase-uid', name: 'Spoofed' });

    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');

    const spoofed = await prisma.user.findUnique({
      where: { firebaseUid: 'spoofed-firebase-uid' },
    });
    const created = await prisma.user.findUnique({
      where: { firebaseUid: tokenUser.uid },
    });
    assert.equal(spoofed, null);
    assert.equal(created, null);
  });

  it('creates a PostgreSQL profile from the token identity', async () => {
    const tokenUser = writeTestUser();
    const app = createApp(mockVerifier(async () => tokenUser));
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name: 'Write Profile Employee' });

    assert.equal(res.status, 201);
    assert.equal(res.body.firebase_uid, tokenUser.uid);
    assert.notEqual(res.body.id, tokenUser.uid);
    assert.equal(res.body.email, tokenUser.email);
    assert.equal(res.body.name, 'Write Profile Employee');
    assert.equal(res.body.role, 'employee');
    assert.equal(res.body.contract_type, null);
    assert.equal(res.body.needs_contract_type, true);
    assert.equal(res.body.monthly_target_hours, 160);
    assert.equal(res.body.auth_provider, 'google');
    assert.equal(res.body.employment_started_on, null);
    for (const field of FORBIDDEN_FIELDS) {
      assert.equal(Object.hasOwn(res.body, field), false);
    }

    const pg = await prisma.user.findUnique({
      where: { firebaseUid: tokenUser.uid },
    });
    assert.ok(pg);
    assert.equal(pg.id, res.body.id);
    assert.equal(pg.firebaseUid, tokenUser.uid);
    assert.equal(pg.role, 'employee');
    assert.equal(pg.needsContractType, true);
    assert.equal(pg.fcmToken, null);
  });

  it('is idempotent for the authenticated Firebase UID', async () => {
    const tokenUser = writeTestUser();
    const app = createApp(mockVerifier(async () => tokenUser));
    const first = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer valid-id-token')
      .send({});
    assert.equal(first.status, 201);

    const second = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name: 'Ignored On Existing' });
    assert.equal(second.status, 200);
    assert.equal(second.body.id, first.body.id);
    assert.equal(second.body.name, first.body.name);
    assert.notEqual(second.body.name, 'Ignored On Existing');
  });

  it('assigns admin from the existing onboarding name tokens', async () => {
    const tokenUser = writeTestUser({
      uid: `${TEST_UID_PREFIX}florin`,
      name: 'Write Test Florin',
    });
    const app = createApp(mockVerifier(async () => tokenUser));
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name: 'Write Test Florin' });

    assert.equal(res.status, 201);
    assert.equal(res.body.role, 'admin');
    const pg = await prisma.user.findUnique({
      where: { firebaseUid: tokenUser.uid },
    });
    assert.equal(pg?.role, 'admin');
  });
});

describe('PATCH /api/users/:id', () => {
  afterEach(async () => {
    await cleanupProfileWriteTests();
  });

  async function createWriteUser(overrides: Partial<AuthenticatedUser> = {}) {
    const tokenUser = writeTestUser(overrides);
    const app = createApp(mockVerifier(async () => tokenUser));
    const res = await request(app)
      .post('/api/users')
      .set('Authorization', 'Bearer valid-id-token')
      .send({});
    assert.ok(res.status === 201 || res.status === 200);
    return { tokenUser, id: res.body.id as string, app };
  }

  it('returns 401 when Authorization header is missing', async () => {
    const { id } = await createWriteUser();
    const app = createApp(mockVerifier(async () => writeTestUser()));
    const res = await request(app)
      .patch(`/api/users/${id}`)
      .send({ contract_type: 'full_time' });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 401 when Bearer token is invalid', async () => {
    const { id } = await createWriteUser();
    const app = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const res = await request(app)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer not-a-real-token')
      .send({ contract_type: 'full_time' });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('lets the owner set a valid contract type', async () => {
    const { tokenUser, id } = await createWriteUser();
    const app = createApp(mockVerifier(async () => tokenUser));
    const res = await request(app)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ contract_type: 'part_time' });

    assert.equal(res.status, 200);
    assert.equal(res.body.contract_type, 'part_time');
    assert.equal(res.body.needs_contract_type, false);
    assert.equal(res.body.monthly_target_hours, 160);

    const pg = await prisma.user.findUnique({ where: { id } });
    assert.equal(pg?.contractType, 'part_time');
    assert.equal(pg?.needsContractType, false);
    assert.equal(pg?.monthlyTargetHours, 160);
  });

  it('returns 400 for an invalid contract type', async () => {
    const { tokenUser, id } = await createWriteUser();
    const app = createApp(mockVerifier(async () => tokenUser));
    const res = await request(app)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ contract_type: 'FULL_TIME' });
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_user');
  });

  it('rejects owner edits of another user and of name/hours', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const { id } = await createWriteUser();
    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const other = await request(employeeApp)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ contract_type: 'full_time' });
    assert.equal(other.status, 403);
    assert.equal(other.body.error, 'forbidden');

    const ownerApp = createApp(mockVerifier(async () => writeTestUser()));
    const nameEdit = await request(ownerApp)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name: 'Hacked Name' });
    assert.equal(nameEdit.status, 403);
  });

  it('lets an admin update employee profile fields', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const { id } = await createWriteUser({ uid: `${TEST_UID_PREFIX}employee-edit` });
    const original = await prisma.user.findUnique({ where: { id: admin.id } });
    const app = createApp(mockVerifier(async () => ({ uid: admin.firebaseUid })));

    const res = await request(app)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        name: 'Edited Write Employee',
        monthly_target_hours: 80,
        contract_type: 'part_time',
        employment_started_on: '2099-08-15',
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.name, 'Edited Write Employee');
    assert.equal(res.body.monthly_target_hours, 80);
    assert.equal(res.body.contract_type, 'part_time');
    assert.equal(res.body.employment_started_on, '2099-08-15');

    const pg = await prisma.user.findUnique({ where: { id } });
    assert.equal(pg?.name, 'Edited Write Employee');
    assert.equal(formatDateOnly(pg?.employmentStartedOn ?? null), '2099-08-15');

    const adminAfter = await prisma.user.findUnique({ where: { id: admin.id } });
    assert.equal(adminAfter?.name, original?.name);
    assert.equal(adminAfter?.monthlyTargetHours, original?.monthlyTargetHours);
  });

  it('returns 403 when an employee tries employee-management fields', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const { id } = await createWriteUser({ uid: `${TEST_UID_PREFIX}blocked` });
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(app)
      .patch(`/api/users/${id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name: 'Should Fail', monthly_target_hours: 80 });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');
  });

  it('returns 404 for an unknown user id', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(mockVerifier(async () => ({ uid: admin.firebaseUid })));
    const res = await request(app)
      .patch('/api/users/00000000-0000-4000-8000-000000000000')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name: 'Missing' });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });
});
