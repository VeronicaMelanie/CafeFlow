import 'dotenv/config';
import { applicationDefault, getApps, initializeApp } from 'firebase-admin/app';
import { getAuth, type Auth } from 'firebase-admin/auth';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID ?? 'cafeflow-5tg';

function createFirebaseApp() {
  if (getApps().length > 0) {
    return getApps()[0]!;
  }

  // Prefer ADC / GOOGLE_APPLICATION_CREDENTIALS when present.
  // ID token verification also works with projectId + Google public certs.
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    return initializeApp({
      credential: applicationDefault(),
      projectId: PROJECT_ID,
    });
  }

  return initializeApp({
    projectId: PROJECT_ID,
  });
}

const firebaseApp = createFirebaseApp();

export function getFirebaseAuth(): Auth {
  return getAuth(firebaseApp);
}

export function getFirebaseProjectId(): string {
  return PROJECT_ID;
}
