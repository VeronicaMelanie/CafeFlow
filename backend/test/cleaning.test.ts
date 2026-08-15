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

const LIST_FIELDS = ['id', 'location_id', 'key'] as const;
const TASK_FIELDS = ['id', 'list_id', 'title', 'sort_order', 'is_active'] as const;
const COMPLETION_FIELDS = [
  'id',
  'user_id',
  'task_id',
  'week_id',
  'completed',
  'completed_at',
] as const;
const FORBIDDEN_FIELDS = [
  'created_at',
  'updated_at',
  'location',
  'employeeId',
  'listId',
  'order',
  'active',
];
const WEEK_ID = /^[0-9]{4}-W[0-9]{2}$/;
const TEST_TITLE_PREFIX = '__test_cleaning_write__';
const TEST_WEEK = '2099-W01';

async function cleanupCleaningWriteTests() {
  const testTasks = await prisma.cleaningTask.findMany({
    where: { title: { startsWith: TEST_TITLE_PREFIX } },
    select: { id: true },
  });
  const testTaskIds = testTasks.map((row) => row.id);
  await prisma.cleaningCompletion.deleteMany({
    where: {
      OR: [
        { weekId: TEST_WEEK },
        ...(testTaskIds.length > 0 ? [{ taskId: { in: testTaskIds } }] : []),
      ],
    },
  });
  if (testTaskIds.length > 0) {
    await prisma.cleaningTask.deleteMany({ where: { id: { in: testTaskIds } } });
  }
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

async function loadExistingList() {
  const list = await prisma.cleaningList.findFirst({
    select: {
      id: true,
      key: true,
      location: { select: { id: true, name: true } },
    },
    orderBy: [{ key: 'asc' }, { id: 'asc' }],
  });
  assert.ok(list, 'expected a PostgreSQL cleaning list');
  const task = await prisma.cleaningTask.findFirst({
    where: { listId: list.id, isActive: true },
    select: { id: true, listId: true, title: true },
    orderBy: [{ sortOrder: 'asc' }, { id: 'asc' }],
  });
  assert.ok(task, 'expected an active cleaning task');
  return { list, task };
}

async function expectedCleaningFromPostgres() {
  const [lists, tasks, completions] = await Promise.all([
    prisma.cleaningList.findMany({
      select: { id: true, locationId: true, key: true },
      orderBy: [{ key: 'asc' }, { id: 'asc' }],
    }),
    prisma.cleaningTask.findMany({
      select: {
        id: true,
        listId: true,
        title: true,
        sortOrder: true,
        isActive: true,
      },
      orderBy: [{ listId: 'asc' }, { sortOrder: 'asc' }, { id: 'asc' }],
    }),
    prisma.cleaningCompletion.findMany({
      select: {
        id: true,
        userId: true,
        taskId: true,
        weekId: true,
        completed: true,
        completedAt: true,
      },
      orderBy: [{ weekId: 'asc' }, { id: 'asc' }],
    }),
  ]);

  return {
    lists: lists.map((row) => ({
      id: row.id,
      location_id: row.locationId,
      key: row.key,
    })),
    tasks: tasks.map((row) => ({
      id: row.id,
      list_id: row.listId,
      title: row.title,
      sort_order: row.sortOrder,
      is_active: row.isActive,
    })),
    completions: completions.map((row) => ({
      id: row.id,
      user_id: row.userId,
      task_id: row.taskId,
      week_id: row.weekId,
      completed: row.completed,
      completed_at: row.completedAt ? row.completedAt.toISOString() : null,
    })),
  };
}

describe('GET /api/cleaning', () => {
  before(async () => {
    await cleanupCleaningWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).get('/api/cleaning');
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
      .get('/api/cleaning')
      .set('Authorization', 'Bearer not-a-real-token');
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
    assert.equal(JSON.stringify(res.body).includes('not-a-real-token'), false);
  });

  it('returns 200 with PostgreSQL lists, tasks, and completions plus constraints', async () => {
    const expected = await expectedCleaningFromPostgres();
    assert.equal(expected.lists.length, 3);
    assert.equal(expected.tasks.length, 7);
    assert.equal(expected.completions.length, 7);

    const locationIds = new Set(
      (await prisma.location.findMany({ select: { id: true } })).map((row) => row.id),
    );
    const userIds = new Set(
      (await prisma.user.findMany({ select: { id: true } })).map((row) => row.id),
    );

    const app = createApp(mockVerifier(async (token) => {
      assert.equal(token, 'valid-id-token');
      return validUser;
    }));
    const res = await request(app)
      .get('/api/cleaning')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.deepEqual(Object.keys(res.body).sort(), ['completions', 'lists', 'tasks']);
    assert.deepEqual(res.body, expected);

    const listIds = new Set(res.body.lists.map((row: { id: string }) => row.id));
    const taskIds = new Set(res.body.tasks.map((row: { id: string }) => row.id));

    for (const row of res.body.lists) {
      assert.deepEqual(Object.keys(row).sort(), [...LIST_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(locationIds.has(row.location_id), true);
    }

    for (const row of res.body.tasks) {
      assert.deepEqual(Object.keys(row).sort(), [...TASK_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(listIds.has(row.list_id), true);
    }

    for (const row of res.body.completions) {
      assert.deepEqual(Object.keys(row).sort(), [...COMPLETION_FIELDS].sort());
      for (const field of FORBIDDEN_FIELDS) {
        assert.equal(Object.hasOwn(row, field), false);
      }
      assert.equal(userIds.has(row.user_id), true);
      assert.equal(taskIds.has(row.task_id), true);
      assert.match(row.week_id, WEEK_ID);
      if (row.completed) {
        assert.ok(row.completed_at);
      } else {
        assert.equal(row.completed_at, null);
      }
    }

    assert.deepEqual(
      res.body.lists.map((row: { key: string; id: string }) => [row.key, row.id]),
      expected.lists.map((row) => [row.key, row.id]),
    );
    assert.deepEqual(
      res.body.tasks.map((row: { list_id: string; sort_order: number; id: string }) => [
        row.list_id,
        row.sort_order,
        row.id,
      ]),
      expected.tasks.map((row) => [row.list_id, row.sort_order, row.id]),
    );
  });

  it('reads cleaning through Prisma/PostgreSQL and does not use Firestore', async () => {
    const appSource = fs.readFileSync(
      path.join(path.dirname(fileURLToPath(import.meta.url)), '../src/app.ts'),
      'utf8',
    );
    assert.equal(/firestore/i.test(appSource), false);
    assert.match(appSource, /prisma\.cleaningList\.findMany/);
    assert.match(appSource, /prisma\.cleaningTask\.findMany/);
    assert.match(appSource, /prisma\.cleaningCompletion\.findMany/);
    assert.match(appSource, /prisma\.cleaningCompletion\.create/);
    assert.match(appSource, /prisma\.cleaningTask\.create/);
    assert.match(appSource, /prisma\.cleaningTask\.update/);
    assert.equal(/app\.(post|patch|put|delete)\(\s*'\/api\/cleaning\/lists/i.test(appSource), false);

    const [listCount, taskCount, completionCount] = await Promise.all([
      prisma.cleaningList.count(),
      prisma.cleaningTask.count(),
      prisma.cleaningCompletion.count(),
    ]);
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app)
      .get('/api/cleaning')
      .set('Authorization', 'Bearer valid-id-token');

    assert.equal(res.status, 200);
    assert.equal(res.body.lists.length, listCount);
    assert.equal(res.body.tasks.length, taskCount);
    assert.equal(res.body.completions.length, completionCount);
    assert.equal(res.body.lists.length + res.body.tasks.length + res.body.completions.length, 17);
  });
});

describe('PUT /api/cleaning/completions', () => {
  afterEach(async () => {
    await cleanupCleaningWriteTests();
  });

  it('returns 401 when Authorization header is missing', async () => {
    const { task } = await loadExistingList();
    const app = createApp(mockVerifier(async () => validUser));
    const res = await request(app).put('/api/cleaning/completions').send({
      task_id: task.id,
      week_id: TEST_WEEK,
      completed: true,
    });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 401 when Bearer token is invalid', async () => {
    const { task } = await loadExistingList();
    const app = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const res = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: true,
      });
    assert.equal(res.status, 401);
    assert.equal(res.body.error, 'unauthorized');
  });

  it('returns 403 when the Firebase UID is not a PostgreSQL user', async () => {
    const { task } = await loadExistingList();
    const app = createApp(
      mockVerifier(async () => ({
        uid: 'unknown-firebase-uid-cleaning-write',
      })),
    );
    const res = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: true,
      });
    assert.equal(res.status, 403);
    assert.equal(res.body.error, 'forbidden');
  });

  it('returns 400 for invalid task_id, week_id, or completed', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const { task } = await loadExistingList();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const missing = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ week_id: TEST_WEEK, completed: true });
    assert.equal(missing.status, 400);
    assert.equal(missing.body.error, 'invalid_cleaning');

    const badWeek = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: 'not-a-week',
        completed: true,
      });
    assert.equal(badWeek.status, 400);

    const badCompleted = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: 'yes',
      });
    assert.equal(badCompleted.status, 400);
  });

  it('returns 404 for an unknown task', async () => {
    const { employee } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const res = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: '00000000-0000-0000-0000-000000000001',
        week_id: TEST_WEEK,
        completed: true,
      });
    assert.equal(res.status, 404);
    assert.equal(res.body.error, 'not_found');
  });

  it('lets an employee toggle their own completion and forbids impersonation', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { task } = await loadExistingList();
    const app = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );

    const impersonate = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: true,
        user_id: admin.id,
      });
    assert.equal(impersonate.status, 403);
    assert.equal(impersonate.body.error, 'forbidden');

    const created = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: true,
      });
    assert.equal(created.status, 200);
    assert.equal(created.body.user_id, employee.id);
    assert.notEqual(created.body.user_id, admin.id);
    assert.equal(created.body.task_id, task.id);
    assert.equal(created.body.week_id, TEST_WEEK);
    assert.equal(created.body.completed, true);
    assert.ok(created.body.completed_at);

    const pgCreated = await prisma.cleaningCompletion.findUnique({
      where: { id: created.body.id },
    });
    assert.ok(pgCreated);
    assert.equal(pgCreated.userId, employee.id);
    assert.equal(pgCreated.taskId, task.id);
    assert.equal(pgCreated.weekId, TEST_WEEK);
    assert.equal(pgCreated.completed, true);
    assert.ok(pgCreated.completedAt);

    const unchecked = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: false,
      });
    assert.equal(unchecked.status, 200);
    assert.equal(unchecked.body.id, created.body.id);
    assert.equal(unchecked.body.completed, false);
    assert.equal(unchecked.body.completed_at, null);

    const pgUnchecked = await prisma.cleaningCompletion.findUnique({
      where: { id: created.body.id },
    });
    assert.equal(pgUnchecked?.completed, false);
    assert.equal(pgUnchecked?.completedAt, null);

    const getApp = createApp(mockVerifier(async () => validUser));
    const getRes = await request(getApp)
      .get('/api/cleaning')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(getRes.status, 200);
    const fromGet = getRes.body.completions.find(
      (row: { id: string }) => row.id === created.body.id,
    );
    assert.ok(fromGet);
    assert.equal(fromGet.completed, false);
    assert.equal(fromGet.user_id, employee.id);
  });

  it('lets an admin write a completion for another employee', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { task } = await loadExistingList();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const res = await request(app)
      .put('/api/cleaning/completions')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        task_id: task.id,
        week_id: TEST_WEEK,
        completed: true,
        user_id: employee.id,
      });
    assert.equal(res.status, 200);
    assert.equal(res.body.user_id, employee.id);
    assert.equal(res.body.completed, true);

    const pg = await prisma.cleaningCompletion.findUnique({
      where: { id: res.body.id },
    });
    assert.equal(pg?.userId, employee.id);
    assert.equal(pg?.completed, true);
  });
});

describe('POST/PATCH/DELETE /api/cleaning/tasks', () => {
  afterEach(async () => {
    await cleanupCleaningWriteTests();
  });

  it('returns 401 when unauthorized or token is invalid', async () => {
    const app = createApp(mockVerifier(async () => validUser));
    const missing = await request(app).post('/api/cleaning/tasks').send({
      location: 'Gara',
      key: 'closing',
      title: `${TEST_TITLE_PREFIX} missing`,
    });
    assert.equal(missing.status, 401);

    const invalidApp = createApp(
      mockVerifier(async () => {
        throw new Error('invalid');
      }),
    );
    const invalid = await request(invalidApp)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer not-a-real-token')
      .send({
        location: 'Gara',
        key: 'closing',
        title: `${TEST_TITLE_PREFIX} invalid`,
      });
    assert.equal(invalid.status, 401);
  });

  it('returns 403 when an employee tries to create, update, delete, or reorder', async () => {
    const { employee, admin } = await loadEmployeeAndAdmin();
    const { list } = await loadExistingList();
    const employeeApp = createApp(
      mockVerifier(async () => ({ uid: employee.firebaseUid })),
    );
    const adminApp = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const created = await request(adminApp)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: list.location.name,
        key: list.key,
        title: `${TEST_TITLE_PREFIX} protected`,
      });
    assert.equal(created.status, 201);

    const create = await request(employeeApp)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: list.location.name,
        key: list.key,
        title: `${TEST_TITLE_PREFIX} employee`,
      });
    assert.equal(create.status, 403);
    assert.equal(create.body.error, 'forbidden');

    const patch = await request(employeeApp)
      .patch(`/api/cleaning/tasks/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ title: `${TEST_TITLE_PREFIX} hijack` });
    assert.equal(patch.status, 403);

    const del = await request(employeeApp)
      .delete(`/api/cleaning/tasks/${created.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(del.status, 403);

    const reorder = await request(employeeApp)
      .put('/api/cleaning/tasks/reorder')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ ids: [created.body.id] });
    assert.equal(reorder.status, 403);

    const pg = await prisma.cleaningTask.findUnique({
      where: { id: created.body.id },
    });
    assert.equal(pg?.title, `${TEST_TITLE_PREFIX} protected`);
    assert.equal(pg?.isActive, true);
  });

  it('returns 404 for an unknown list or task and 400 for invalid payloads', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const emptyTitle = await request(app)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: 'Gara',
        key: 'closing',
        title: '   ',
      });
    assert.equal(emptyTitle.status, 400);
    assert.equal(emptyTitle.body.error, 'invalid_cleaning');

    const unknownList = await request(app)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: 'NoSuchPlace',
        key: 'closing',
        title: `${TEST_TITLE_PREFIX} missing list`,
      });
    assert.equal(unknownList.status, 404);

    const unknownKeyCombo = await request(app)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: 'Gara',
        key: 'notaday',
        title: `${TEST_TITLE_PREFIX} bad key`,
      });
    assert.equal(unknownKeyCombo.status, 400);

    const missingTask = await request(app)
      .patch('/api/cleaning/tasks/00000000-0000-0000-0000-000000000001')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ title: `${TEST_TITLE_PREFIX} gone` });
    assert.equal(missingTask.status, 404);

    const badId = await request(app)
      .delete('/api/cleaning/tasks/not-a-uuid')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(badId.status, 400);
  });

  it('lets an admin create, update, reorder, and soft-delete a task', async () => {
    const { admin } = await loadEmployeeAndAdmin();
    const { list } = await loadExistingList();
    const app = createApp(
      mockVerifier(async () => ({ uid: admin.firebaseUid })),
    );

    const first = await request(app)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: list.location.name,
        key: list.key,
        title: `${TEST_TITLE_PREFIX} first`,
      });
    assert.equal(first.status, 201);
    assert.equal(first.body.title, `${TEST_TITLE_PREFIX} first`);
    assert.equal(first.body.list_id, list.id);
    assert.equal(first.body.is_active, true);
    assert.equal(typeof first.body.sort_order, 'number');
    assert.notEqual(first.body.id, `${list.location.name}_${list.key}`);

    const pgFirst = await prisma.cleaningTask.findUnique({
      where: { id: first.body.id },
    });
    assert.ok(pgFirst);
    assert.equal(pgFirst.listId, list.id);
    assert.equal(pgFirst.title, `${TEST_TITLE_PREFIX} first`);

    const second = await request(app)
      .post('/api/cleaning/tasks')
      .set('Authorization', 'Bearer valid-id-token')
      .send({
        location: list.location.name,
        key: list.key,
        title: `${TEST_TITLE_PREFIX} second`,
      });
    assert.equal(second.status, 201);
    assert.ok(second.body.sort_order > first.body.sort_order);

    const renamed = await request(app)
      .patch(`/api/cleaning/tasks/${first.body.id}`)
      .set('Authorization', 'Bearer valid-id-token')
      .send({ title: `${TEST_TITLE_PREFIX} renamed` });
    assert.equal(renamed.status, 200);
    assert.equal(renamed.body.title, `${TEST_TITLE_PREFIX} renamed`);

    const reordered = await request(app)
      .put('/api/cleaning/tasks/reorder')
      .set('Authorization', 'Bearer valid-id-token')
      .send({ ids: [second.body.id, first.body.id] });
    assert.equal(reordered.status, 200);
    assert.equal(reordered.body[0].id, second.body.id);
    assert.equal(reordered.body[0].sort_order, 0);
    assert.equal(reordered.body[1].id, first.body.id);
    assert.equal(reordered.body[1].sort_order, 1);

    const deleted = await request(app)
      .delete(`/api/cleaning/tasks/${second.body.id}`)
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(deleted.status, 200);
    assert.equal(deleted.body.is_active, false);

    const pgDeleted = await prisma.cleaningTask.findUnique({
      where: { id: second.body.id },
    });
    assert.equal(pgDeleted?.isActive, false);
    assert.ok(pgDeleted, 'soft delete must keep the PostgreSQL row');

    const getApp = createApp(mockVerifier(async () => validUser));
    const getRes = await request(getApp)
      .get('/api/cleaning')
      .set('Authorization', 'Bearer valid-id-token');
    assert.equal(getRes.status, 200);
    const fromGet = getRes.body.tasks.find(
      (row: { id: string }) => row.id === first.body.id,
    );
    assert.equal(fromGet.title, `${TEST_TITLE_PREFIX} renamed`);
    assert.equal(fromGet.sort_order, 1);
    const deletedFromGet = getRes.body.tasks.find(
      (row: { id: string }) => row.id === second.body.id,
    );
    assert.equal(deletedFromGet.is_active, false);
    assert.equal(
      getRes.body.lists.some(
        (row: { id: string }) => row.id === `${list.location.name}_${list.key}`,
      ),
      false,
    );
  });
});
