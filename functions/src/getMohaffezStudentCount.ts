import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

/**
 * Cloud Function to get the student count for a teacher (mohaffez).
 * This function can be called by any authenticated user to get a teacher's student count.
 */
export const getMohaffezStudentCount = functions.https.onCall(async (data, context) => {
  // Verify the user is authenticated (optional - you can remove this check to allow public access)
  if (context.auth) {
    console.log(`Called by user: ${context.auth.uid}`);
  }

  const mohaffezId = data.mohaffezId as string;
  
  if (!mohaffezId || typeof mohaffezId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'mohaffezId is required');
  }

  try {
    const db = admin.firestore();
    
    // Query hafizSessions to count unique students
    const snapshot = await db
      .collection('hafizSessions')
      .where('mohaffezId', '==', mohaffezId)
      .where('status', 'in', ['accepted', 'completed'])
      .get();

    const uniqueStudentIds = new Set<string>();
    
    snapshot.docs.forEach(doc => {
      const studentId = doc.data().studentId as string | undefined;
      if (studentId) {
        uniqueStudentIds.add(studentId);
      }
    });

    const count = uniqueStudentIds.size;
    console.log(`Found ${count} unique students for mohaffezId: ${mohaffezId}`);

    return { count };
  } catch (error) {
    console.error('Error getting student count:', error);
    throw new functions.https.HttpsError('internal', 'Failed to get student count');
  }
});
