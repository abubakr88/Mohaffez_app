import * as functions from 'firebase-functions';

import { db } from '../utils/admin';

/**
 * input: {}
 * output: { inMaintenance: false }
 */
export const checkMaintenanceMode = functions.https.onCall(async (_, context) => {
  const uid = context.auth?.uid;
  const doc = await db.collection('systemConfig').doc('global').get();
  const data = doc.data() ?? {};

  const maintenanceMode = data.maintenanceMode === true;
  const allowed = Array.isArray(data.maintenanceAllowedUids)
    ? (data.maintenanceAllowedUids as string[])
    : [];

  if (maintenanceMode && (!uid || !allowed.includes(uid))) {
    throw new functions.https.HttpsError('unavailable', 'maintenance');
  }

  return { inMaintenance: false };
});
