import 'dotenv/config';
import assert from 'node:assert/strict';
import { afterEach, describe, it } from 'node:test';
import request from 'supertest';
import { createApp } from '../src/app';
import type { AuthenticatedUser } from '../src/auth/types';
import type { TokenVerifier } from '../src/auth/verifyToken';
import { prisma } from '../src/db';
import { isSuperadminEmail, isSuperadminSession } from '../src/superadmin';

const TEST_UID_PREFIX = 'sa-test-';
const PRODUCT_PREFIX = 'sa-test-product-';
const LOCATION_PREFIX = 'sa-test-loc-';

function mockVerifier(impl: TokenVerifier): TokenVerifier {
  return impl;
}

function tokenUser(overrides: Partial<AuthenticatedUser> = {}): AuthenticatedUser {
  return {
    uid: `${TEST_UID_PREFIX}dev`,
    email: 'sa-dev@example.com',
    name: 'Superadmin Dev',
    authProvider: 'password',
    emailVerified: true,
    ...overrides,
  };
}

async function cleanup() {
  await prisma.product.deleteMany({
    where: { name: { startsWith: PRODUCT_PREFIX } },
  });
  await prisma.location.deleteMany({
    where: { name: { startsWith: LOCATION_PREFIX } },
  });
  const users = await prisma.user.findMany({
    where: { firebaseUid: { startsWith: TEST_UID_PREFIX } },
    select: { id: true },
  });
  for (const user of users) {
    await prisma.notification.deleteMany({ where: { userId: user.id } });
    await prisma.cleaningCompletion.deleteMany({ where: { userId: user.id } });
    await prisma.consumption.deleteMany({ where: { userId: user.id } });
    await prisma.shift.deleteMany({ where: { userId: user.id } });
    await prisma.availability.deleteMany({ where: { userId: user.id } });
    await prisma.vacation.deleteMany({ where: { userId: user.id } });
    await prisma.userLocation.deleteMany({ where: { userId: user.id } });
    await prisma.schedulingConfig.updateMany({
      where: { enabledById: user.id },
      data: { enabledById: null },
    });
    await prisma.user.delete({ where: { id: user.id } });
  }
}

async function createDevUser(overrides: {
  uid?: string;
  email?: string;
  name?: string;
  role?: 'admin' | 'employee';
} = {}) {
  return prisma.user.create({
    data: {
      firebaseUid: overrides.uid ?? `${TEST_UID_PREFIX}dev`,
      email: overrides.email ?? 'sa-dev@example.com',
      name: overrides.name ?? 'Superadmin Dev',
      role: overrides.role ?? 'employee',
      monthlyTargetHours: 160,
      needsContractType: false,
      authProvider: 'google',
    },
  });
}

describe('superadmin allowlist', () => {
  it('matches emails case-insensitively from SUPERADMIN_EMAILS', () => {
    const env = { SUPERADMIN_EMAILS: 'Dev@Example.com, other@cafe.ro' };
    assert.equal(isSuperadminEmail('dev@example.com', env), true);
    assert.equal(isSuperadminEmail('OTHER@cafe.ro', env), true);
    assert.equal(isSuperadminEmail('malina@example.com', env), false);
    assert.equal(isSuperadminEmail(null, env), false);
  });

  it('grants a superadmin session only for verified email/password sign-in', () => {
    const env = { SUPERADMIN_EMAILS: 'dev@yahoo.com' };
    const base = { email: 'dev@yahoo.com', authProvider: 'password' as const };
    assert.equal(isSuperadminSession({ ...base, emailVerified: true }, env), true);
    assert.equal(
      isSuperadminSession({ email: 'dev@yahoo.com', authProvider: 'email', emailVerified: true }, env),
      true,
    );
    assert.equal(
      isSuperadminSession({ ...base, emailVerified: false }, env),
      false,
    );
    assert.equal(
      isSuperadminSession({ ...base, authProvider: 'google.com', emailVerified: true }, env),
      false,
    );
    assert.equal(
      isSuperadminSession({ email: 'other@yahoo.com', authProvider: 'password', emailVerified: true }, env),
      false,
    );
  });
});

describe('GET /api/auth/me superadmin flag', () => {
  const previous = process.env.SUPERADMIN_EMAILS;

  afterEach(() => {
    if (previous === undefined) delete process.env.SUPERADMIN_EMAILS;
    else process.env.SUPERADMIN_EMAILS = previous;
  });

  it('returns is_superadmin true only for allowlisted email/password sign-in', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const app = createApp(
      mockVerifier(async () => tokenUser()),
    );
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 200);
    assert.equal(res.body.is_superadmin, true);
  });

  it('returns is_superadmin false when the allowlisted email is not verified', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const app = createApp(
      mockVerifier(async () => tokenUser({ emailVerified: false })),
    );
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 200);
    assert.equal(res.body.is_superadmin, false);
  });

  it('returns is_superadmin false when the allowlisted email signs in with Google', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const app = createApp(
      mockVerifier(async () => tokenUser({ authProvider: 'google.com' })),
    );
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 200);
    assert.equal(res.body.is_superadmin, false);
  });
});

describe('/api/superadmin', () => {
  const previous = process.env.SUPERADMIN_EMAILS;

  afterEach(async () => {
    if (previous === undefined) delete process.env.SUPERADMIN_EMAILS;
    else process.env.SUPERADMIN_EMAILS = previous;
    await cleanup();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => tokenUser()));
    const res = await request(app).get('/api/superadmin/overview');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 403 for a cafe admin who is not on the email allowlist', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const admin = await prisma.user.findFirst({
      where: { role: 'admin' },
      select: { firebaseUid: true, email: true, name: true },
    });
    assert.ok(admin);
    const app = createApp(
      mockVerifier(async () => ({
        uid: admin.firebaseUid,
        email: admin.email,
        name: admin.name,
        authProvider: 'google.com',
      })),
    );
    const res = await request(app)
      .get('/api/superadmin/overview')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');
  });

  it('lets an allowlisted developer read overview, change role, and delete a user', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const dev = await createDevUser();
    const target = await createDevUser({
      uid: `${TEST_UID_PREFIX}target`,
      email: 'sa-target@example.com',
      name: 'Disposable Target',
      role: 'employee',
    });

    const app = createApp(mockVerifier(async () => tokenUser({ uid: dev.firebaseUid })));

    const overview = await request(app)
      .get('/api/superadmin/overview')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(overview.status, 200);
    assert.equal(typeof overview.body.users, 'number');
    assert.ok(overview.body.users >= 2);

    const patched = await request(app)
      .patch(`/api/superadmin/users/${target.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ role: 'admin' });
    assert.equal(patched.status, 200);
    assert.equal(patched.body.role, 'admin');

    const deleted = await request(app)
      .delete(`/api/superadmin/users/${target.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(deleted.status, 204);
    const gone = await prisma.user.findUnique({ where: { id: target.id } });
    assert.equal(gone, null);
  });

  it('refuses to delete the signed-in superadmin', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const dev = await createDevUser();
    const app = createApp(mockVerifier(async () => tokenUser({ uid: dev.firebaseUid })));
    const res = await request(app)
      .delete(`/api/superadmin/users/${dev.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(res.status, 400);
    assert.equal(res.body.error, 'invalid_user');
  });

  it('creates, updates, and deletes a product', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const dev = await createDevUser();
    const app = createApp(mockVerifier(async () => tokenUser({ uid: dev.firebaseUid })));
    const name = `${PRODUCT_PREFIX}${Date.now()}`;

    const created = await request(app)
      .post('/api/superadmin/products')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name });
    assert.equal(created.status, 201);
    assert.equal(created.body.name, name);
    assert.equal(created.body.is_active, true);

    const updated = await request(app)
      .patch(`/api/superadmin/products/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ is_active: false });
    assert.equal(updated.status, 200);
    assert.equal(updated.body.is_active, false);

    const deleted = await request(app)
      .delete(`/api/superadmin/products/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(deleted.status, 204);
  });

  it('creates a location and can deactivate it', async () => {
    process.env.SUPERADMIN_EMAILS = 'sa-dev@example.com';
    const dev = await createDevUser();
    const app = createApp(mockVerifier(async () => tokenUser({ uid: dev.firebaseUid })));
    const name = `${LOCATION_PREFIX}${Date.now()}`;

    const created = await request(app)
      .post('/api/superadmin/locations')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ name });
    assert.equal(created.status, 201);
    assert.equal(created.body.name, name);
    assert.equal(created.body.is_active, true);

    const updated = await request(app)
      .patch(`/api/superadmin/locations/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ is_active: false });
    assert.equal(updated.status, 200);
    assert.equal(updated.body.is_active, false);
  });
});
