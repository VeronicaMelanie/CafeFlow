const fs = require('fs');
const path = require('path');

const AUDIT_DIR = path.join(__dirname, '..', 'audit');
const FIRESTORE_DIR = path.join(AUDIT_DIR, 'firestore');

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function loadCollection(name) {
  return readJson(path.join(FIRESTORE_DIR, `${name}.json`));
}

function normalize(value) {
  if (value === null || value === undefined) return null;
  return String(value).trim();
}

function unique(values) {
  return [...new Set(values.filter(Boolean))].sort();
}

function printSection(title) {
  console.log('');
  console.log('='.repeat(70));
  console.log(title);
  console.log('='.repeat(70));
}

function countBy(items, getter) {
  const counts = {};

  for (const item of items) {
    const value = getter(item);
    if (!value) continue;
    counts[value] = (counts[value] || 0) + 1;
  }

  return counts;
}

function printCounts(counts) {
  for (const [key, value] of Object.entries(counts).sort()) {
    console.log(`  ${key}: ${value}`);
  }
}

function main() {
  console.log('======================================');
  console.log('CafeFlow FIREBASE MIGRATION AUDIT');
  console.log('READ-ONLY - LOCAL EXPORT ONLY');
  console.log('======================================');

  const authUsers = readJson(path.join(AUDIT_DIR, 'auth-users.json'));

  const users = loadCollection('users');
  const availability = loadCollection('availability');
  const cleaningCompletions = loadCollection('cleaning_completions');
  const cleaningTasks = loadCollection('cleaning_tasks');
  const consumptions = loadCollection('consumptions');
  const schedulingConfig = loadCollection('scheduling_config');
  const shifts = loadCollection('shifts');
  const vacations = loadCollection('vacations');

  // ------------------------------------------------------------
  // 1. COUNTS
  // ------------------------------------------------------------

  printSection('1. COUNTS');

  console.log(`Auth users:              ${authUsers.length}`);
  console.log(`Firestore users:         ${users.length}`);
  console.log(`Availability:            ${availability.length}`);
  console.log(`Shifts:                  ${shifts.length}`);
  console.log(`Vacations:               ${vacations.length}`);
  console.log(`Consumptions:            ${consumptions.length}`);
  console.log(`Cleaning tasks:          ${cleaningTasks.length}`);
  console.log(`Cleaning completions:    ${cleaningCompletions.length}`);
  console.log(`Scheduling config:       ${schedulingConfig.length}`);

  // ------------------------------------------------------------
  // 2. AUTH <-> FIRESTORE USER MAPPING
  // ------------------------------------------------------------

  printSection('2. AUTH <-> FIRESTORE USERS');

  const authUidSet = new Set(authUsers.map(u => u.uid));
  const firestoreUidSet = new Set(users.map(u => u.id));

  const authWithoutFirestore = authUsers.filter(
    u => !firestoreUidSet.has(u.uid)
  );

  const firestoreWithoutAuth = users.filter(
    u => !authUidSet.has(u.id)
  );

  console.log(`Matched users: ${authUsers.filter(u => firestoreUidSet.has(u.uid)).length}`);

  console.log(`Auth users WITHOUT Firestore profile: ${authWithoutFirestore.length}`);

  for (const user of authWithoutFirestore) {
    console.log(`  ${user.uid} | ${user.email || '(no email)'}`);
  }

  console.log(`Firestore users WITHOUT Auth account: ${firestoreWithoutAuth.length}`);

  for (const user of firestoreWithoutAuth) {
    const data = user.data || {};
    console.log(`  ${user.id} | ${data.email || '(no email)'} | ${data.name || '(no name)'}`);
  }

  // ------------------------------------------------------------
  // 3. ROLES
  // ------------------------------------------------------------

  printSection('3. USER ROLES');

  const roles = countBy(
    users,
    u => normalize(u.data?.role)
  );

  printCounts(roles);

  // ------------------------------------------------------------
  // 4. LOCATIONS
  // ------------------------------------------------------------

  printSection('4. LOCATIONS FOUND IN FIRESTORE');

  const locations = new Set();

  for (const user of users) {
    locations.add(normalize(user.data?.primaryLocation));
    locations.add(normalize(user.data?.secondaryLocation));
  }

  for (const shift of shifts) {
    locations.add(normalize(shift.data?.location));
  }

  for (const task of cleaningTasks) {
    locations.add(normalize(task.data?.location));
  }

  for (const completion of cleaningCompletions) {
    locations.add(normalize(completion.data?.location));
  }

  const locationList = unique([...locations]);

  console.log(`Distinct locations: ${locationList.length}`);

  for (const location of locationList) {
    console.log(`  ${location}`);
  }

  // ------------------------------------------------------------
  // 5. PRODUCTS
  // ------------------------------------------------------------

  printSection('5. PRODUCTS FOUND IN CONSUMPTIONS');

  const productNames = consumptions
    .map(c => normalize(c.data?.productName))
    .filter(Boolean);

  const products = unique(productNames);

  console.log(`Distinct product names: ${products.length}`);

  const productCounts = countBy(
    consumptions,
    c => normalize(c.data?.productName)
  );

  for (const product of products) {
    console.log(`  ${product} -> ${productCounts[product]} consumption(s)`);
  }

  // ------------------------------------------------------------
  // 6. CONSUMPTIONS
  // ------------------------------------------------------------

  printSection('6. CONSUMPTIONS');

  console.log(`Total consumptions: ${consumptions.length}`);

  let consumptionMissingUser = 0;
  let consumptionWithUser = 0;
  let consumptionMissingProduct = 0;
  let consumptionMissingDate = 0;

  for (const consumption of consumptions) {
    const data = consumption.data || {};

    if (data.userId && authUidSet.has(data.userId)) {
      consumptionWithUser++;
    } else {
      consumptionMissingUser++;
      console.log(
        `  MISSING USER: ${consumption.id} -> ${data.userId || '(none)'}`
      );
    }

    if (!normalize(data.productName)) {
      consumptionMissingProduct++;
      console.log(`  MISSING PRODUCT: ${consumption.id}`);
    }

    if (!data.date) {
      consumptionMissingDate++;
      console.log(`  MISSING DATE: ${consumption.id}`);
    }
  }

  console.log(`Consumptions with valid Auth user: ${consumptionWithUser}`);
  console.log(`Consumptions with missing/invalid user: ${consumptionMissingUser}`);
  console.log(`Consumptions missing product: ${consumptionMissingProduct}`);
  console.log(`Consumptions missing date: ${consumptionMissingDate}`);

  // ------------------------------------------------------------
  // 7. WORK TYPE / CONTRACT TYPE
  // ------------------------------------------------------------

  printSection('7. WORK TYPE / CONTRACT TYPE');

  const workTypes = countBy(
    users,
    u => normalize(u.data?.workType)
  );

  const contractTypes = countBy(
    users,
    u => normalize(u.data?.contractType)
  );

  console.log('workType:');
  printCounts(workTypes);

  console.log('');
  console.log('contractType:');
  printCounts(contractTypes);

  const usersWithoutContractType = users.filter(
    u => !normalize(u.data?.contractType)
  );

  console.log('');
  console.log(`Users without contractType: ${usersWithoutContractType.length}`);

  for (const user of usersWithoutContractType) {
    const data = user.data || {};

    console.log(
      `  ${user.id} | ${data.name || '(no name)'} | workType=${data.workType || '(none)'}`
    );
  }

  // ------------------------------------------------------------
  // 8. FCM TOKENS
  // ------------------------------------------------------------

  printSection('8. FCM TOKENS');

  const usersWithFcm = users.filter(
    u => normalize(u.data?.fcmToken)
  );

  console.log(`Users with FCM token: ${usersWithFcm.length}`);
  console.log(`Users without FCM token: ${users.length - usersWithFcm.length}`);

  // IMPORTANT:
  // Do NOT print actual FCM tokens.

  // ------------------------------------------------------------
  // 9. SHIFTS
  // ------------------------------------------------------------

  printSection('9. SHIFTS');

  console.log(`Total shifts: ${shifts.length}`);

  const shiftStatuses = countBy(
    shifts,
    s => normalize(s.data?.status)
  );

  const shiftTypes = countBy(
    shifts,
    s => normalize(s.data?.type)
  );

  console.log('Statuses:');
  printCounts(shiftStatuses);

  console.log('');
  console.log('Types:');
  printCounts(shiftTypes);

  const shiftsMissingUser = shifts.filter(
    s => !s.data?.userId || !authUidSet.has(s.data.userId)
  );

  const shiftsMissingLocation = shifts.filter(
    s => !normalize(s.data?.location)
  );

  console.log('');
  console.log(`Shifts with invalid/missing user: ${shiftsMissingUser.length}`);
  console.log(`Shifts with missing location: ${shiftsMissingLocation.length}`);

  // ------------------------------------------------------------
  // 10. AVAILABILITY
  // ------------------------------------------------------------

  printSection('10. AVAILABILITY');

  const availabilityTypes = countBy(
    availability,
    a => normalize(a.data?.shiftType)
  );

  console.log('Shift types:');
  printCounts(availabilityTypes);

  const availabilityMissingUser = availability.filter(
    a => !a.data?.userId || !authUidSet.has(a.data.userId)
  );

  const availabilityMissingDate = availability.filter(
    a => !a.data?.date
  );

  console.log('');
  console.log(`Invalid/missing user: ${availabilityMissingUser.length}`);
  console.log(`Missing date: ${availabilityMissingDate.length}`);

  // ------------------------------------------------------------
  // 11. VACATIONS
  // ------------------------------------------------------------

  printSection('11. VACATIONS');

  const vacationStatuses = countBy(
    vacations,
    v => normalize(v.data?.status)
  );

  console.log('Statuses:');
  printCounts(vacationStatuses);

  const vacationsMissingUser = vacations.filter(
    v => !v.data?.userId || !authUidSet.has(v.data.userId)
  );

  console.log('');
  console.log(`Vacations with invalid/missing user: ${vacationsMissingUser.length}`);

  // ------------------------------------------------------------
  // 12. CLEANING
  // ------------------------------------------------------------

  printSection('12. CLEANING');

  const cleaningLocations = unique(
    cleaningTasks.map(t => normalize(t.data?.location))
  );

  console.log(`Cleaning locations: ${cleaningLocations.length}`);

  for (const location of cleaningLocations) {
    console.log(`  ${location}`);
  }

  const cleaningLists = unique(
    cleaningTasks.map(t => normalize(t.data?.listId))
  );

  console.log('');
  console.log(`Cleaning lists: ${cleaningLists.length}`);

  for (const list of cleaningLists) {
    console.log(`  ${list}`);
  }

  const completionMissingTask = cleaningCompletions.filter(
    c => !cleaningTasks.some(t => t.id === c.data?.taskId)
  );

  console.log('');
  console.log(
    `Cleaning completions with missing task: ${completionMissingTask.length}`
  );

  // ------------------------------------------------------------
  // 13. SCHEDULING CONFIG
  // ------------------------------------------------------------

  printSection('13. SCHEDULING CONFIG');

  for (const config of schedulingConfig) {
    const data = config.data || {};

    console.log(
      `  ${config.id} | ${data.year}-${String(data.month).padStart(2, '0')} | ` +
      `enabled=${data.schedulingEnabled} | locked=${data.lockedMonth}`
    );
  }

  // ------------------------------------------------------------
  // 14. SUMMARY
  // ------------------------------------------------------------

  printSection('14. MIGRATION SUMMARY');

  console.log('DATA CURRENTLY SAFE TO MAP AUTOMATICALLY:');
  console.log(`  Users/Auth mapping: ${authWithoutFirestore.length === 0 ? 'YES' : 'NO - review needed'}`);
  console.log(`  Locations: ${locationList.length > 0 ? 'YES - derive catalog' : 'NO'}`);
  console.log(`  Products: ${products.length > 0 ? 'YES - review canonical names' : 'NO'}`);
  console.log(`  Shifts: ${shifts.length > 0 ? 'YES' : 'NO'}`);
  console.log(`  Availability: ${availability.length > 0 ? 'YES' : 'NO'}`);
  console.log(`  Vacations: ${vacations.length > 0 ? 'YES' : 'NO'}`);
  console.log(`  Cleaning: ${cleaningTasks.length > 0 ? 'YES' : 'NO'}`);
  console.log(`  Scheduling config: ${schedulingConfig.length > 0 ? 'YES' : 'NO'}`);

  console.log('');
  console.log('IMPORTANT MANUAL DECISIONS:');

  if (usersWithoutContractType.length > 0) {
    console.log('  [REVIEW] Users without contractType');
  }

  if (products.length > 0) {
    console.log('  [REVIEW] Product canonicalization');
  }

  if (consumptions.length > 0) {
    console.log('  [REVIEW] Consumption location resolution');
  }

  console.log('');
  console.log('AUDIT COMPLETE.');
}

main();