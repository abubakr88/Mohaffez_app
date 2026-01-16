const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

const db = admin.firestore();

// Send notification when session is booked
exports.onSessionBooked = functions.firestore
  .document('sessionRequests/{requestId}')
  .onCreate(async (snap, context) => {
    const request = snap.data();
    const mohaffezId = request.momohaffezId;
    
    // Get Mohaffez FCM token
    const mohaffezDoc = await db.collection('users').doc(mohaffezId).get();
    const fcmToken = mohaffezDoc.data()?.fcmToken;
    
    if (!fcmToken) {
      console.log('No FCM token for mohaffez:', mohaffezId);
      return null;
    }
    
    // Send push notification
    const message = {
      notification: {
        title: 'طلب جلسة جديد',
        body: `لديك طلب جلسة جديد من ${request.studentName}`,
      },
      data: {
        type: 'session_request',
        requestId: context.params.requestId,
      },
      token: fcmToken,
    };
    
    try {
      await admin.messaging().send(message);
      console.log('Notification sent successfully');
    } catch (error) {
      console.error('Error sending notification:', error);
    }
    
    return null;
  });

// Send notification when request is accepted/rejected
exports.onRequestStatusChange = functions.firestore
  .document('sessionRequests/{requestId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if status changed
    if (before.status === after.status) return null;
    
    const studentId = after.studentId;
    const status = after.status;
    
    // Get Student FCM token
    const studentDoc = await db.collection('users').doc(studentId).get();
    const fcmToken = studentDoc.data()?.fcmToken;
    
    if (!fcmToken) {
      console.log('No FCM token for student:', studentId);
      return null;
    }
    
    let title, body;
    if (status === 'accepted') {
      title = 'تم قبول الطلب';
      body = `تم قبول طلبك من قبل ${after.mohaffezName}`;
    } else if (status === 'rejected') {
      title = 'تم رفض الطلب';
      body = `تم رفض طلبك من قبل ${after.mohaffezName}`;
    } else {
      return null;
    }
    
    const message = {
      notification: { title, body },
      data: {
        type: 'session_status',
        requestId: context.params.requestId,
        status: status,
      },
      token: fcmToken,
    };
    
    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
    
    return null;
  });

// Send notification for new assignment
exports.onAssignmentCreated = functions.firestore
  .document('hafizSessions/{sessionId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if assignment was added
    const hasNewAssignment = 
      (before.hifzAssignment !== after.hifzAssignment && after.hifzAssignment) ||
      (before.murajaAssignment !== after.murajaAssignment && after.murajaAssignment);
    
    if (!hasNewAssignment) return null;
    
    const studentId = after.studentId;
    
    // Get Student FCM token
    const studentDoc = await db.collection('users').doc(studentId).get();
    const fcmToken = studentDoc.data()?.fcmToken;
    
    if (!fcmToken) return null;
    
    const message = {
      notification: {
        title: 'واجب جديد',
        body: `تم إضافة واجب جديد من ${after.mohaffezName}`,
      },
      data: {
        type: 'assignment',
        sessionId: context.params.sessionId,
      },
      token: fcmToken,
    };
    
    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
    
    return null;
  });

// Send notification for credential status change
exports.onCredentialStatusChange = functions.firestore
  .document('users/{userId}/credentials/{credentialId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    if (before.status === after.status) return null;
    
    const userId = context.params.userId;
    const status = after.status;
    
    // Get user FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    const fcmToken = userDoc.data()?.fcmToken;
    
    if (!fcmToken) return null;
    
    let title, body;
    if (status === 'approved') {
      title = 'تم قبول الشهادة';
      body = `تم قبول شهادة ${after.title}`;
    } else if (status === 'rejected') {
      title = 'تم رفض الشهادة';
      body = `تم رفض شهادة ${after.title}`;
    } else if (status === 'under_review') {
      title = 'شهادة قيد المراجعة';
      body = `شهادة ${after.title} قيد المراجعة`;
    } else {
      return null;
    }
    
    const message = {
      notification: { title, body },
      data: {
        type: 'credential',
        credentialId: context.params.credentialId,
        status: status,
      },
      token: fcmToken,
    };
    
    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
    
    return null;
  });

// Send notification for new follower
exports.onNewFollower = functions.firestore
  .document('follows/{followId}')
  .onCreate(async (snap, context) => {
    const follow = snap.data();
    const mohaffezId = follow.mohaffezId;
    const studentId = follow.studentId;
    
    // Get student name
    const studentDoc = await db.collection('users').doc(studentId).get();
    const studentName = studentDoc.data()?.name || 'طالب';
    
    // Get Mohaffez FCM token
    const mohaffezDoc = await db.collection('users').doc(mohaffezId).get();
    const fcmToken = mohaffezDoc.data()?.fcmToken;
    
    if (!fcmToken) return null;
    
    const message = {
      notification: {
        title: 'متابع جديد',
        body: `${studentName} بدأ بمتابعتك`,
      },
      data: {
        type: 'follow',
        studentId: studentId,
      },
      token: fcmToken,
    };
    
    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
    
    return null;
  });
