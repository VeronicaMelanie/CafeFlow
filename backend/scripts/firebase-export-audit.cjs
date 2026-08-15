const fs = require('fs');
const path = require('path');

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

const serviceAccount = require('../secrets/cafeflow-5tg-firebase-adminsdk-fbsvc-6093a88064.json');

initializeApp({
  credential: cert(serviceAccount),
});

const auth = getAuth();
const db = getFirestore();

const COLLECTIONS = [
  'availability',
  'cleaning_completions',
  'cleaning_tasks',
  'consumptions',
  'scheduling_config',
  'shifts',
  'users',
  'vacations',
];

const OUTPUT_DIR = path.join(__dirname, '..', 'audit');
const FIRESTORE_DIR = path.join(OUTPUT_DIR, 'firestore');

function serialize(value) {
  if (value === null || value === undefined) return value;

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === 'object' && value.toDate instanceof Function) {
    return value.toDate().toISOString();
  }

  if (Array.isArray(value)) {
    return value.map(serialize);
  }

  if (typeof value === 'object') {
    const result = {};
    for (const [key, val] of Object.entries(value)) {
      result[key] = serialize(val);
    }
    return result;
  }

  return value;
}

async function exportAuthUsers() {
  console.log('Exporting Firebase Auth users...');

  const users = [];
  let pageToken;

  do {
    const result = await auth.listUsers(1000, pageToken);

    for (const user of result.users) {
      users.push({
        uid: user.uid,
        email: user.email ?? null,
        displayName: user.displayName ?? null,
        phoneNumber: user.phoneNumber ?? null,
        disabled: user.disabled,
        emailVerified: user.emailVerified,
        providerData: user.providerData.map((p) => ({
          providerId: p.providerId,
          uid: p.uid,
          email: p.email ?? null,
          displayName: p.displayName ?? null,
        })),
        metadata: {
          creationTime: user.metadata.creationTime ?? null,
          lastSignInTime: user.metadata.lastSignInTime ?? null,
          lastRefreshTime: user.metadata.lastRefreshTime ?? null,
        },
      });
    }

    pageToken = result.pageToken;
  } while (pageToken);

  const output = path.join(OUTPUT_DIR, 'auth-users.json');

  fs.writeFileSync(
    output,
    JSON.stringify(users, null, 2),
    'utf8'
  );

  console.log(`Auth users exported: ${users.length}`);
}

async function exportCollection(collectionName) {
  console.log(`Exporting Firestore collection: ${collectionName}...`);

  const snapshot = await db.collection(collectionName).get();

  const documents = snapshot.docs.map((doc) => ({
    id: doc.id,
    data: serialize(doc.data()),
  }));

  const output = path.join(
    FIRESTORE_DIR,
    `${collectionName}.json`
  );

  fs.writeFileSync(
    output,
    JSON.stringify(documents, null, 2),
    'utf8'
  );

  console.log(`  ${documents.length} documents`);
}

async function main() {
  fs.mkdirSync(FIRESTORE_DIR, { recursive: true });

  console.log('======================================');
  console.log('CafeFlow Firebase READ-ONLY EXPORT');
  console.log('======================================');
  console.log('');

  await exportAuthUsers();

  for (const collection of COLLECTIONS) {
    await exportCollection(collection);
  }

  console.log('');
  console.log('======================================');
  console.log('EXPORT COMPLETE');
  console.log('======================================');
  console.log(`Output: ${OUTPUT_DIR}`);
}

main().catch((error) => {
  console.error('');
  console.error('EXPORT FAILED');
  console.error(error);
  process.exit(1);
});