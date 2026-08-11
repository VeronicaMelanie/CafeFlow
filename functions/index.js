const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const ADMIN_NAME_TOKENS = ['malina', 'florin'];

function normalizeName(value) {
  return String(value || '').trim().toLowerCase();
}

function isPredefinedAdmin(displayName) {
  const normalizedName = normalizeName(displayName);
  return ADMIN_NAME_TOKENS.some((token) => normalizedName.includes(token));
}

async function sendToUser(userId, title, body, data = {}) {
  const userDoc = await admin.firestore().collection('users').doc(userId).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) return;

  await admin.messaging().send({
    token,
    notification: { title, body },
    data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
    android: { priority: 'high', notification: { channelId: 'instant_notifications' } },
    apns: { payload: { aps: { sound: 'default' } } },
  });
}

async function sendToAllEmployees(title, body, data = {}) {
  const snap = await admin
    .firestore()
    .collection('users')
    .where('role', '==', 'employee')
    .get();

  const tokens = snap.docs
    .map((d) => d.data().fcmToken)
    .filter(Boolean);

  if (tokens.length === 0) return;

  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
  });
}

exports.syncUserProfile = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const uid = context.auth.uid;
  const authName = context.auth.token.name || '';
  const signInProvider =
    context.auth.token?.firebase?.sign_in_provider || 'unknown';
  const requestedName = typeof data?.name === 'string' ? data.name : '';
  const mergedName = requestedName.trim() || String(authName).trim() || 'Employee';
  const email = context.auth.token.email || '';

  const requestedWorkType = typeof data?.workType === 'string' ? data.workType : '';
  const workType = requestedWorkType === 'Part-time' ? 'Part-time' : 'Full-time';
  const monthlyTargetHours = workType === 'Part-time' ? 80 : 160;
  const shouldBeAdmin = isPredefinedAdmin(mergedName);

  const userRef = admin.firestore().collection('users').doc(uid);
  const role = await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(userRef);

    if (!snap.exists) {
      const newRole = shouldBeAdmin ? 'admin' : 'employee';
      tx.set(userRef, {
        email,
        name: mergedName,
        role: newRole,
        workType,
        monthlyTargetHours,
        primaryLocation: 'Gara',
        secondaryLocation: 'Avantgarden',
        fcmToken: null,
        availability: null,
        // New fields (2026): contract type onboarding + provider tracking.
        contractType: null,
        needsContractType: true,
        authProvider: signInProvider === 'password' ? 'email' : 'google',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return newRole;
    }

    const current = snap.data() || {};
    const updateData = {};

    if (current.name !== mergedName) updateData.name = mergedName;
    if (current.email !== email) updateData.email = email;
    if (current.workType == null) updateData.workType = workType;
    if (current.monthlyTargetHours == null) {
      updateData.monthlyTargetHours = monthlyTargetHours;
    }
    if (current.primaryLocation == null) updateData.primaryLocation = 'Gara';
    if (current.secondaryLocation == null) {
      updateData.secondaryLocation = 'Avantgarden';
    }

    // Backfill new auth fields for existing users without forcing onboarding.
    if (current.authProvider == null) {
      updateData.authProvider = signInProvider === 'password' ? 'email' : 'google';
    }
    if (current.contractType == null && current.needsContractType == null) {
      updateData.contractType =
        current.workType === 'Part-time' ? 'part_time' : 'full_time';
      updateData.needsContractType = false;
    }

    const currentRole = current.role === 'admin' ? 'admin' : 'employee';
    const resolvedRole = (currentRole === 'admin' || shouldBeAdmin)
      ? 'admin'
      : 'employee';
    if (current.role !== resolvedRole) updateData.role = resolvedRole;

    if (Object.keys(updateData).length > 0) {
      tx.update(userRef, updateData);
    }

    return resolvedRole;
  });

  return { role };
});

/** Callable after admin publishes a schedule */
exports.notifySchedulePublished = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Sign in required');
  }

  const adminDoc = await admin
    .firestore()
    .collection('users')
    .doc(context.auth.uid)
    .get();
  if (adminDoc.data()?.role !== 'admin') {
    throw new functions.https.HttpsError('permission-denied', 'Admins only');
  }

  const month = data.month || 'next month';
  await sendToAllEmployees(
    'Schedule published',
    `Your schedule for ${month} is now available in CafeFlow.`,
    { type: 'schedule_published' },
  );

  return { success: true };
});

/** When vacation status changes, notify the employee */
exports.onVacationUpdated = functions.firestore
  .document('vacations/{vacationId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();
    if (before.status === after.status) return;

    const status = after.status;
    if (status !== 'approved' && status !== 'rejected') return;

    const title =
      status === 'approved' ? 'Vacation approved' : 'Vacation declined';
    const body =
      status === 'approved'
        ? 'Your vacation request was approved. Those days count toward your hours.'
        : `Your vacation request was rejected.${after.adminComment ? ' ' + after.adminComment : ''}`;

    await sendToUser(after.userId, title, body, {
      type: 'vacation_status',
      status,
    });
  });

/** Notify employee when their shift document changes */
exports.onShiftUpdated = functions.firestore
  .document('shifts/{shiftId}')
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    const fields = ['startTime', 'endTime', 'location', 'status'];
    const changed = fields.some(
      (f) => JSON.stringify(before[f]) !== JSON.stringify(after[f]),
    );
    if (!changed) return;

    const start = after.startTime.toDate();
    const end = after.endTime.toDate();
    const fmt = (d) =>
      d.toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });

    await sendToUser(
      after.userId,
      'Shift updated',
      `Your shift at ${after.location} was changed to ${fmt(start)}–${fmt(end)}.`,
      { type: 'shift_changed', shiftId: change.after.id },
    );
  });
