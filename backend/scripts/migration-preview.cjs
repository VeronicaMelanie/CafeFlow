const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const AUDIT_DIR = path.join(__dirname, '..', 'audit');
const FIRESTORE_DIR = path.join(AUDIT_DIR, 'firestore');
const OUTPUT_DIR = path.join(__dirname, '..', 'migration-preview');

const USER_ROLES = new Set(['employee', 'admin']);
const CONTRACT_TYPES = new Set(['full_time', 'part_time']);
const AUTH_PROVIDERS = new Set(['google', 'email']);
const SHIFT_TYPES = new Set(['FULL', 'CUSTOM', 'VACATION']);
const SHIFT_STATUSES = new Set(['pending', 'approved', 'auto-assigned']);
const AVAILABILITY_SHIFT_TYPES = new Set(['full_time', 'custom_hours']);
const VACATION_STATUSES = new Set(['pending', 'approved', 'rejected']);
const CLEANING_LIST_KEYS = new Set([
  'closing',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday'
]);

fs.mkdirSync(OUTPUT_DIR, { recursive: true });

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function load(name) {
  return readJson(path.join(FIRESTORE_DIR, `${name}.json`));
}

function normalize(value) {
  if (value === null || value === undefined) return null;

  const result = String(value).trim();

  return result === '' ? null : result;
}

function slug(value) {
  return (
    normalize(value)
      ?.toLowerCase()
      .replace(/\s+/g, ' ')
      .trim() || null
  );
}

function uuid() {
  return crypto.randomUUID();
}

function write(name, data) {
  fs.writeFileSync(
    path.join(OUTPUT_DIR, name),
    JSON.stringify(data, null, 2),
    'utf8'
  );
}

function parseDate(value) {
  if (!value) return null;

  const date = new Date(value);

  if (Number.isNaN(date.getTime())) {
    return null;
  }

  return date.toISOString();
}

function dateOnly(value) {
  const parsed = parseDate(value);

  if (!parsed) return null;

  return parsed.slice(0, 10);
}

function timeOnlyUtc(value) {
  const parsed = parseDate(value);

  if (!parsed) return null;

  const match = parsed.match(/T(\d{2}:\d{2}:\d{2}(?:\.\d+)?)/);

  return match ? match[1] : null;
}

function isUserLocationApplicableOn(userLocation, consumedOn) {
  if (!consumedOn) return false;

  // valid_from is required for applicability. Do not invent a start date.
  if (!userLocation.valid_from) return false;

  if (userLocation.valid_from > consumedOn) return false;

  if (
    userLocation.valid_until != null &&
    userLocation.valid_until < consumedOn
  ) {
    return false;
  }

  return true;
}

function uniqueSorted(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

function parsePositiveQuantity(value) {
  if (value === null || value === undefined || value === '') return null;

  const number = typeof value === 'number' ? value : Number(value);

  if (!Number.isFinite(number) || number <= 0) return null;

  return number;
}

function resolveAvailabilityShiftType(data) {
  const raw = normalize(data.shiftType);

  if (raw === 'full_time' || raw === 'custom_hours') return raw;

  // Documented Firestore legacy value.
  if (raw === 'part_time') return 'custom_hours';

  if (raw) return null;

  if (data.isFullDay === true) return 'full_time';
  if (data.isFullDay === false) return 'custom_hours';

  return null;
}

function parseCleaningListSource(listId, locationIdMap) {
  const raw = normalize(listId);

  if (!raw) return null;

  const separator = raw.lastIndexOf('_');

  if (separator <= 0 || separator === raw.length - 1) return null;

  const locationName = raw.slice(0, separator);
  const key = raw.slice(separator + 1);

  if (!CLEANING_LIST_KEYS.has(key)) return null;

  const locationId = locationIdMap.get(slug(locationName));

  if (!locationId) return null;

  return {
    sourceId: raw,
    locationId,
    key,
    locationName
  };
}

function main() {
  console.log('======================================');
  console.log('CafeFlow MIGRATION PREVIEW');
  console.log('NO POSTGRESQL WRITES');
  console.log('======================================');

  const authUsers = readJson(
    path.join(AUDIT_DIR, 'auth-users.json')
  );

  const users = load('users');
  const shifts = load('shifts');
  const availability = load('availability');
  const vacations = load('vacations');
  const consumptions = load('consumptions');
  const cleaningTasks = load('cleaning_tasks');
  const cleaningCompletions = load('cleaning_completions');
  const schedulingConfig = load('scheduling_config');

  const report = {
    generatedAt: new Date().toISOString(),
    mode: 'PREVIEW_ONLY',
    postgresqlWrites: false,
    unresolved: [],
    ambiguous: [],
    warnings: [],
    counts: {}
  };

  // ------------------------------------------------------------
  // USERS
  // ------------------------------------------------------------

  console.log('\n[1] USERS');

  const authByUid = new Map(
    authUsers.map(user => [user.uid, user])
  );

  const userIdMap = new Map();
  const pgUsers = [];

  for (const userDoc of users) {
    const uid = userDoc.id;
    const data = userDoc.data || {};
    const auth = authByUid.get(uid);

    if (!auth) {
      report.unresolved.push({
        type: 'USER_WITHOUT_AUTH',
        firebaseUid: uid
      });

      continue;
    }

    const email = normalize(data.email) || normalize(auth.email);
    const name = normalize(data.name) || normalize(auth.displayName);
    const role = normalize(data.role) || 'employee';
    const contractType = normalize(data.contractType);
    const authProvider = normalize(data.authProvider);

    if (!email || !name) {
      report.unresolved.push({
        type: 'USER_REQUIRED_FIELDS_UNRESOLVED',
        firebaseUid: uid,
        reason: 'MISSING_EMAIL_OR_NAME'
      });

      continue;
    }

    if (!USER_ROLES.has(role)) {
      report.unresolved.push({
        type: 'USER_ROLE_UNRESOLVED',
        firebaseUid: uid,
        role
      });

      continue;
    }

    const pgId = uuid();

    userIdMap.set(uid, pgId);

    pgUsers.push({
      id: pgId,
      firebase_uid: uid,
      email,
      name,
      role,
      contract_type:
        contractType && CONTRACT_TYPES.has(contractType)
          ? contractType
          : null,
      monthly_target_hours:
        data.monthlyTargetHours == null ? 160 : data.monthlyTargetHours,
      needs_contract_type:
        data.needsContractType == null ? false : data.needsContractType === true,
      auth_provider:
        authProvider && AUTH_PROVIDERS.has(authProvider)
          ? authProvider
          : null,
      employment_started_on: dateOnly(data.employmentDate),
      fcm_token: normalize(data.fcmToken)
    });
  }

  write('users.json', pgUsers);

  report.counts.users = pgUsers.length;

  console.log(`  Preview users: ${pgUsers.length}`);

  // ------------------------------------------------------------
  // LOCATIONS
  // ------------------------------------------------------------

  console.log('\n[2] LOCATIONS');

  const locationNames = new Map();

  function collectLocation(value) {
    const name = normalize(value);

    if (!name) return;

    const key = slug(name);

    if (!locationNames.has(key)) {
      locationNames.set(key, name);
    }
  }

  for (const user of users) {
    collectLocation(user.data?.primaryLocation);
    collectLocation(user.data?.secondaryLocation);
  }

  for (const shift of shifts) {
    collectLocation(shift.data?.location);
  }

  for (const task of cleaningTasks) {
    collectLocation(task.data?.location);
  }

  for (const completion of cleaningCompletions) {
    collectLocation(completion.data?.location);
  }

  const locationIdMap = new Map();
  const pgLocations = [];

  for (const [key, name] of locationNames) {
    const id = uuid();

    locationIdMap.set(key, id);

    pgLocations.push({
      id,
      code: key.replace(/[^a-z0-9]+/g, '_'),
      name
    });
  }

  write('locations.json', pgLocations);

  report.counts.locations = pgLocations.length;

  console.log(`  Preview locations: ${pgLocations.length}`);

  // ------------------------------------------------------------
  // PRODUCTS
  // ------------------------------------------------------------

  console.log('\n[3] PRODUCTS');

  const productMap = new Map();

  for (const consumption of consumptions) {
    const name = normalize(consumption.data?.productName);

    if (!name) {
      report.unresolved.push({
        type: 'CONSUMPTION_MISSING_PRODUCT',
        id: consumption.id
      });

      continue;
    }

    const key = slug(name);

    if (!productMap.has(key)) {
      productMap.set(key, {
        id: uuid(),
        name,
        source_variants: [name]
      });
    } else {
      const product = productMap.get(key);

      if (!product.source_variants.includes(name)) {
        product.source_variants.push(name);

        report.ambiguous.push({
          type: 'PRODUCT_NAME_VARIANT',
          canonical_key: key,
          variants: [...product.source_variants]
        });
      }
    }
  }

  const pgProducts = [...productMap.values()].map(product => ({
    id: product.id,
    name: product.name
  }));

  write('products.json', pgProducts);

  report.counts.products = pgProducts.length;

  console.log(`  Preview products: ${pgProducts.length}`);

  // ------------------------------------------------------------
  // USER LOCATIONS
  // ------------------------------------------------------------

  console.log('\n[4] USER LOCATIONS');

  const pgUserLocations = [];

  for (const user of users) {
    const pgUserId = userIdMap.get(user.id);

    if (!pgUserId) continue;

    const validFrom = dateOnly(user.data?.employmentDate);

    const locations = [
      {
        value: user.data?.primaryLocation,
        isPrimary: true
      },
      {
        value: user.data?.secondaryLocation,
        isPrimary: false
      }
    ];

    for (const item of locations) {
      const name = normalize(item.value);

      if (!name) continue;

      const locationId = locationIdMap.get(slug(name));

      if (!locationId) {
        report.unresolved.push({
          type: 'USER_LOCATION_NOT_FOUND',
          userId: user.id,
          location: name
        });

        continue;
      }

      if (!validFrom) {
        report.unresolved.push({
          type: 'USER_LOCATION_VALID_FROM_UNRESOLVED',
          userId: user.id,
          location: name,
          reason: 'NO_EMPLOYMENT_DATE_OR_ASSIGNMENT_DATE'
        });

        continue;
      }

      pgUserLocations.push({
        id: uuid(),
        user_id: pgUserId,
        location_id: locationId,
        is_primary: item.isPrimary,
        valid_from: validFrom,
        valid_until: dateOnly(user.data?.validUntil)
      });
    }
  }

  write('user_locations.json', pgUserLocations);

  report.counts.user_locations = pgUserLocations.length;

  console.log(`  Preview user_locations: ${pgUserLocations.length}`);

  // ------------------------------------------------------------
  // SHIFTS
  // ------------------------------------------------------------

  console.log('\n[5] SHIFTS');

  const pgShifts = [];

  for (const shift of shifts) {
    const data = shift.data || {};
    const userId = userIdMap.get(data.userId);

    if (!userId) {
      report.unresolved.push({
        type: 'SHIFT_USER_NOT_FOUND',
        shiftId: shift.id,
        userId: data.userId || null
      });

      continue;
    }

    const locationName = normalize(data.location);
    const locationId = locationName
      ? locationIdMap.get(slug(locationName))
      : null;

    if (!locationId) {
      report.unresolved.push({
        type: 'SHIFT_LOCATION_NOT_FOUND',
        shiftId: shift.id,
        location: locationName
      });

      continue;
    }

    const workDate = dateOnly(data.date);
    const startAt = parseDate(data.startTime);
    const endAt = parseDate(data.endTime);
    const type = normalize(data.type);
    const status = normalize(data.status);

    if (!workDate || !startAt || !endAt) {
      report.unresolved.push({
        type: 'SHIFT_DATETIME_UNRESOLVED',
        shiftId: shift.id,
        reason: 'MISSING_WORK_DATE_OR_TIMES'
      });

      continue;
    }

    if (!type || !SHIFT_TYPES.has(type)) {
      report.unresolved.push({
        type: 'SHIFT_TYPE_UNRESOLVED',
        shiftId: shift.id,
        type
      });

      continue;
    }

    if (!status || !SHIFT_STATUSES.has(status)) {
      report.unresolved.push({
        type: 'SHIFT_STATUS_UNRESOLVED',
        shiftId: shift.id,
        status
      });

      continue;
    }

    if (endAt < startAt) {
      report.unresolved.push({
        type: 'SHIFT_TIME_RANGE_INVALID',
        shiftId: shift.id,
        start_at: startAt,
        end_at: endAt
      });

      continue;
    }

    pgShifts.push({
      id: uuid(),
      user_id: userId,
      location_id: locationId,
      work_date: workDate,
      start_at: startAt,
      end_at: endAt,
      type,
      status
    });
  }

  write('shifts.json', pgShifts);

  report.counts.shifts = pgShifts.length;

  console.log(`  Preview shifts: ${pgShifts.length}`);

  // ------------------------------------------------------------
  // AVAILABILITY
  // ------------------------------------------------------------

  console.log('\n[6] AVAILABILITY');

  const pgAvailability = [];

  for (const item of availability) {
    const data = item.data || {};
    const userId = userIdMap.get(data.userId);

    if (!userId) {
      report.unresolved.push({
        type: 'AVAILABILITY_USER_NOT_FOUND',
        id: item.id,
        userId: data.userId || null
      });

      continue;
    }

    const workDate = dateOnly(data.date);

    if (!workDate) {
      report.unresolved.push({
        type: 'AVAILABILITY_DATE_UNRESOLVED',
        id: item.id
      });

      continue;
    }

    const shiftType = resolveAvailabilityShiftType(data);

    if (!shiftType || !AVAILABILITY_SHIFT_TYPES.has(shiftType)) {
      report.unresolved.push({
        type: 'AVAILABILITY_SHIFT_TYPE_UNRESOLVED',
        id: item.id,
        userId: data.userId || null,
        shiftType: data.shiftType ?? null,
        isFullDay: data.isFullDay ?? null
      });

      continue;
    }

    const submittedAt = parseDate(data.submissionTimestamp);

    if (!submittedAt) {
      report.unresolved.push({
        type: 'AVAILABILITY_SUBMITTED_AT_UNRESOLVED',
        id: item.id,
        userId: data.userId || null
      });

      continue;
    }

    let customStartTime = null;
    let customEndTime = null;

    if (shiftType === 'custom_hours') {
      customStartTime = timeOnlyUtc(data.customStartTime);
      customEndTime = timeOnlyUtc(data.customEndTime);

      if (!customStartTime || !customEndTime || customEndTime <= customStartTime) {
        report.unresolved.push({
          type: 'AVAILABILITY_CUSTOM_HOURS_INVALID',
          id: item.id,
          userId: data.userId || null
        });

        continue;
      }
    }

    pgAvailability.push({
      id: uuid(),
      user_id: userId,
      work_date: workDate,
      shift_type: shiftType,
      custom_start_time: customStartTime,
      custom_end_time: customEndTime,
      submitted_at: submittedAt
    });
  }

  write('availability.json', pgAvailability);

  report.counts.availability = pgAvailability.length;

  console.log(`  Preview availability: ${pgAvailability.length}`);

  // ------------------------------------------------------------
  // VACATIONS
  // ------------------------------------------------------------

  console.log('\n[7] VACATIONS');

  const pgVacations = [];

  for (const item of vacations) {
    const data = item.data || {};
    const userId = userIdMap.get(data.userId);

    if (!userId) {
      report.unresolved.push({
        type: 'VACATION_USER_NOT_FOUND',
        id: item.id,
        userId: data.userId || null
      });

      continue;
    }

    const startOn = dateOnly(data.startDate);
    const endOn = dateOnly(data.endDate);
    const status = normalize(data.status);
    const requestedAt = parseDate(data.requestedAt);

    if (!startOn || !endOn || !requestedAt) {
      report.unresolved.push({
        type: 'VACATION_DATETIME_UNRESOLVED',
        id: item.id
      });

      continue;
    }

    if (!status || !VACATION_STATUSES.has(status)) {
      report.unresolved.push({
        type: 'VACATION_STATUS_UNRESOLVED',
        id: item.id,
        status
      });

      continue;
    }

    if (endOn < startOn) {
      report.unresolved.push({
        type: 'VACATION_DATE_RANGE_INVALID',
        id: item.id,
        start_on: startOn,
        end_on: endOn
      });

      continue;
    }

    pgVacations.push({
      id: uuid(),
      user_id: userId,
      start_on: startOn,
      end_on: endOn,
      status,
      requested_at: requestedAt,
      admin_comment: normalize(data.adminComment)
    });
  }

  write('vacations.json', pgVacations);

  report.counts.vacations = pgVacations.length;

  console.log(`  Preview vacations: ${pgVacations.length}`);

  // ------------------------------------------------------------
  // CONSUMPTIONS
  // ------------------------------------------------------------

  console.log('\n[8] CONSUMPTIONS');

  const pgConsumptions = [];

  for (const item of consumptions) {
    const data = item.data || {};
    const userId = userIdMap.get(data.userId);

    if (!userId) {
      report.unresolved.push({
        type: 'CONSUMPTION_USER_NOT_FOUND',
        id: item.id,
        userId: data.userId || null
      });

      continue;
    }

    const productName = normalize(data.productName);
    const product = productName
      ? productMap.get(slug(productName))
      : null;

    if (!product) {
      report.unresolved.push({
        type: 'CONSUMPTION_PRODUCT_NOT_FOUND',
        id: item.id,
        productName
      });

      continue;
    }

    const quantity = parsePositiveQuantity(data.quantity);

    if (quantity == null) {
      report.unresolved.push({
        type: 'CONSUMPTION_INVALID_QUANTITY',
        id: item.id,
        userId: data.userId,
        productName,
        quantity: data.quantity ?? null
      });

      continue;
    }

    const consumedDate = dateOnly(data.date);
    const loggedAt = parseDate(data.date);

    // ----------------------------------------------------------
    // LOCATION RESOLUTION
    //
    // Firestore consumptions do not contain location.
    // Never invent a location. Never pick primary / first / only-in-system.
    //
    // 1. Exactly one distinct shift location for the same user/day.
    // 2. Else exactly one user_location applicable on consumed_on
    //    (valid_from <= day AND (valid_until IS NULL OR valid_until >= day)).
    // 3. Multiple distinct locations → AMBIGUOUS. Zero → UNRESOLVED.
    // ----------------------------------------------------------

    if (!consumedDate || !loggedAt) {
      report.unresolved.push({
        type: 'CONSUMPTION_LOCATION_UNRESOLVED',
        id: item.id,
        userId: data.userId,
        productName,
        date: data.date || null,
        reason: 'MISSING_CONSUMED_DATE'
      });

      continue;
    }

    const matchingShifts = shifts.filter(shift => {
      const shiftData = shift.data || {};

      return (
        shiftData.userId === data.userId &&
        dateOnly(shiftData.date) === consumedDate
      );
    });

    const shiftLocationKeys = uniqueSorted(
      matchingShifts
        .map(shift => slug(normalize(shift.data?.location)))
    );

    if (shiftLocationKeys.length > 1) {
      report.ambiguous.push({
        type: 'CONSUMPTION_LOCATION_AMBIGUOUS',
        id: item.id,
        userId: data.userId,
        productName,
        date: data.date || null,
        locations: shiftLocationKeys.map(
          key => locationNames.get(key) || key
        )
      });

      continue;
    }

    if (shiftLocationKeys.length === 1) {
      const locationId = locationIdMap.get(shiftLocationKeys[0]) || null;

      if (!locationId) {
        report.unresolved.push({
          type: 'CONSUMPTION_LOCATION_UNRESOLVED',
          id: item.id,
          userId: data.userId,
          productName,
          date: data.date || null,
          reason: 'SHIFT_LOCATION_NOT_FOUND'
        });

        continue;
      }

      pgConsumptions.push({
        id: uuid(),
        user_id: userId,
        product_id: product.id,
        location_id: locationId,
        consumed_on: consumedDate,
        logged_at: loggedAt,
        quantity,
        notes: normalize(data.notes)
      });

      continue;
    }

    const applicableUserLocations = pgUserLocations.filter(
      userLocation =>
        userLocation.user_id === userId &&
        isUserLocationApplicableOn(userLocation, consumedDate)
    );

    const applicableLocationIds = uniqueSorted(
      applicableUserLocations.map(userLocation => userLocation.location_id)
    );

    if (applicableLocationIds.length > 1) {
      const locationNameById = new Map(
        pgLocations.map(location => [location.id, location.name])
      );

      report.ambiguous.push({
        type: 'CONSUMPTION_LOCATION_AMBIGUOUS',
        id: item.id,
        userId: data.userId,
        productName,
        date: data.date || null,
        locations: applicableLocationIds.map(
          locationId => locationNameById.get(locationId) || locationId
        )
      });

      continue;
    }

    if (applicableLocationIds.length === 1) {
      pgConsumptions.push({
        id: uuid(),
        user_id: userId,
        product_id: product.id,
        location_id: applicableLocationIds[0],
        consumed_on: consumedDate,
        logged_at: loggedAt,
        quantity,
        notes: normalize(data.notes)
      });

      continue;
    }

    report.unresolved.push({
      type: 'CONSUMPTION_LOCATION_UNRESOLVED',
      id: item.id,
      userId: data.userId,
      productName,
      date: data.date || null,
      reason: matchingShifts.length === 0
        ? 'NO_SHIFT_AND_NO_APPLICABLE_USER_LOCATION'
        : 'NO_USABLE_SHIFT_AND_NO_APPLICABLE_USER_LOCATION'
    });
  }

  write('consumptions.json', pgConsumptions);

  report.counts.consumptions = pgConsumptions.length;

  console.log(`  Preview consumptions: ${pgConsumptions.length}`);

  // ------------------------------------------------------------
  // CLEANING LISTS
  // ------------------------------------------------------------

  console.log('\n[9] CLEANING LISTS');

  const cleaningListSources = new Set();

  for (const task of cleaningTasks) {
    const listId = normalize(task.data?.listId);

    if (listId) cleaningListSources.add(listId);
  }

  for (const completion of cleaningCompletions) {
    const listId = normalize(completion.data?.listId);

    if (listId) cleaningListSources.add(listId);
  }

  const cleaningListIdBySource = new Map();
  const pgCleaningLists = [];

  for (const sourceId of [...cleaningListSources].sort()) {
    const parsed = parseCleaningListSource(sourceId, locationIdMap);

    if (!parsed) {
      report.unresolved.push({
        type: 'CLEANING_LIST_UNRESOLVED',
        listId: sourceId,
        reason: 'CANNOT_PARSE_LOCATION_AND_KEY'
      });

      continue;
    }

    const id = uuid();

    cleaningListIdBySource.set(sourceId, id);

    pgCleaningLists.push({
      id,
      location_id: parsed.locationId,
      key: parsed.key
    });
  }

  write('cleaning_lists.json', pgCleaningLists);

  report.counts.cleaning_lists = pgCleaningLists.length;

  console.log(`  Preview cleaning_lists: ${pgCleaningLists.length}`);

  // ------------------------------------------------------------
  // CLEANING TASKS
  // ------------------------------------------------------------

  console.log('\n[10] CLEANING TASKS');

  const pgCleaningTasks = [];
  const cleaningTaskIdBySource = new Map();

  for (const task of cleaningTasks) {
    const data = task.data || {};
    const sourceListId = normalize(data.listId);
    const listId = sourceListId
      ? cleaningListIdBySource.get(sourceListId)
      : null;
    const title = normalize(data.title);

    if (!listId) {
      report.unresolved.push({
        type: 'CLEANING_TASK_LIST_NOT_FOUND',
        id: task.id,
        listId: sourceListId
      });

      continue;
    }

    if (!title) {
      report.unresolved.push({
        type: 'CLEANING_TASK_TITLE_UNRESOLVED',
        id: task.id
      });

      continue;
    }

    const pgId = uuid();

    cleaningTaskIdBySource.set(task.id, pgId);

    pgCleaningTasks.push({
      id: pgId,
      list_id: listId,
      title,
      sort_order: data.order == null ? 0 : data.order,
      is_active: data.active !== false
    });
  }

  write('cleaning_tasks.json', pgCleaningTasks);

  report.counts.cleaning_tasks = pgCleaningTasks.length;

  console.log(`  Preview cleaning_tasks: ${pgCleaningTasks.length}`);

  // ------------------------------------------------------------
  // CLEANING COMPLETIONS
  // ------------------------------------------------------------

  console.log('\n[11] CLEANING COMPLETIONS');

  const pgCleaningCompletions = [];

  for (const completion of cleaningCompletions) {
    const data = completion.data || {};
    const taskId = cleaningTaskIdBySource.get(data.taskId);

    if (!taskId) {
      report.unresolved.push({
        type: 'CLEANING_COMPLETION_TASK_NOT_FOUND',
        id: completion.id,
        taskId: data.taskId || null
      });

      continue;
    }

    const userId = userIdMap.get(data.employeeId);

    if (!userId) {
      report.unresolved.push({
        type: 'CLEANING_COMPLETION_USER_NOT_FOUND',
        id: completion.id,
        employeeId: data.employeeId || null
      });

      continue;
    }

    const weekId = normalize(data.weekId);

    if (!weekId || !/^[0-9]{4}-W[0-9]{2}$/.test(weekId)) {
      report.unresolved.push({
        type: 'CLEANING_COMPLETION_WEEK_ID_UNRESOLVED',
        id: completion.id,
        weekId
      });

      continue;
    }

    const completed = data.completed === true;
    const completedAt = parseDate(data.completedAt);

    if (completed && !completedAt) {
      report.unresolved.push({
        type: 'CLEANING_COMPLETION_COMPLETED_AT_UNRESOLVED',
        id: completion.id
      });

      continue;
    }

    pgCleaningCompletions.push({
      id: uuid(),
      task_id: taskId,
      user_id: userId,
      week_id: weekId,
      completed,
      completed_at: completed ? completedAt : null
    });
  }

  write('cleaning_completions.json', pgCleaningCompletions);

  report.counts.cleaning_completions = pgCleaningCompletions.length;

  console.log(`  Preview cleaning_completions: ${pgCleaningCompletions.length}`);

  // ------------------------------------------------------------
  // SCHEDULING CONFIG
  // ------------------------------------------------------------

  console.log('\n[12] SCHEDULING CONFIG');

  const pgSchedulingConfig = [];

  for (const item of schedulingConfig) {
    const data = item.data || {};
    const year = data.year;
    const month = data.month;

    if (
      !Number.isInteger(year) ||
      year < 2000 ||
      year > 2100 ||
      !Number.isInteger(month) ||
      month < 1 ||
      month > 12
    ) {
      report.unresolved.push({
        type: 'SCHEDULING_CONFIG_PERIOD_UNRESOLVED',
        id: item.id,
        year: year ?? null,
        month: month ?? null
      });

      continue;
    }

    const locationName = normalize(data.location);
    let locationId = null;

    if (locationName) {
      locationId = locationIdMap.get(slug(locationName)) || null;

      if (!locationId) {
        report.unresolved.push({
          type: 'SCHEDULING_CONFIG_LOCATION_NOT_FOUND',
          id: item.id,
          location: locationName
        });

        continue;
      }
    }

    const row = {
      id: uuid(),
      year,
      month,
      location_id: locationId,
      scheduling_enabled: data.schedulingEnabled === true,
      locked_month: data.lockedMonth === true,
      enabled_by: userIdMap.get(data.enabledBy) || null,
      enabled_at: parseDate(data.enabledAt)
    };

    if (data.maxHoursPerDay != null) {
      row.max_hours_per_day = data.maxHoursPerDay;
    }

    if (data.maxEmployeesPerShift != null) {
      row.max_employees_per_shift = data.maxEmployeesPerShift;
    }

    pgSchedulingConfig.push(row);
  }

  write('scheduling_config.json', pgSchedulingConfig);

  report.counts.scheduling_config = pgSchedulingConfig.length;

  console.log(`  Preview scheduling_config: ${pgSchedulingConfig.length}`);

  // ------------------------------------------------------------
  // REPORT
  // ------------------------------------------------------------

  write('migration-report.json', report);

  console.log('');
  console.log('======================================');
  console.log('MIGRATION PREVIEW COMPLETE');
  console.log('======================================');

  console.log('');
  console.log('Preview output:');
  console.log(OUTPUT_DIR);

  console.log('');
  console.log('Counts:');
  console.log(JSON.stringify(report.counts, null, 2));

  console.log('');
  console.log(`UNRESOLVED: ${report.unresolved.length}`);
  console.log(`AMBIGUOUS:  ${report.ambiguous.length}`);
  console.log(`WARNINGS:   ${report.warnings.length}`);

  console.log('');
  console.log('Unresolved:');
  console.log(JSON.stringify(report.unresolved, null, 2));

  console.log('');
  console.log('Ambiguous:');
  console.log(JSON.stringify(report.ambiguous, null, 2));

  console.log('');
  console.log('Warnings:');
  console.log(JSON.stringify(report.warnings, null, 2));

  console.log('');
  console.log('NO POSTGRESQL WRITES WERE PERFORMED.');
}

main();
