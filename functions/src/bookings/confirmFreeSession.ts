import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { db, FieldValue } from '../utils/admin';

export const confirmFreeSession = functions.https.onCall(async (data, context) => {
  console.log('✅ confirmFreeSession – UPDATED VERSION_15_2_2025');   // <-- add this line

  // 1. Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'المستخدم غير مصادق عليه');
  }

  const studentId = context.auth.uid;

  // 2. Validate input
  const {
    mohaffezId,
    mohaffezName,
    studentName,
    sessionType,
    preferredTimeSlot,
    slotDate,
    slotStart,
    slotEnd,
    imamAddressText,
    imamAddressLat,
    imamAddressLng,
    mohaffezPhone,
    promoCode,
  } = data;

  if (!mohaffezId || !mohaffezName || !studentName || !sessionType || 
      !preferredTimeSlot || !slotDate || !slotStart || !slotEnd || !promoCode) {
    throw new functions.https.HttpsError('invalid-argument', 'بيانات غير مكتملة');
  }

  // 3. Verify promo code
  const promoSnapshot = await db
    .collection('promocodes')
    .where('code', '==', promoCode)
    .limit(1)
    .get();

  if (promoSnapshot.empty) {
    throw new functions.https.HttpsError('not-found', 'كود الخصم غير صحيح');
  }

  const promoDoc = promoSnapshot.docs[0];
  const promoData = promoDoc.data();

  // Validate promo code
  if (!promoData.isActive) {
    throw new functions.https.HttpsError('failed-precondition', 'كود الخصم غير نشط');
  }

  if (promoData.discountPercent !== 100) {
    throw new functions.https.HttpsError('failed-precondition', 'هذا الكود ليس للجلسات المجانية');
  }

  if (promoData.expiryDate && promoData.expiryDate.toDate() < new Date()) {
    throw new functions.https.HttpsError('failed-precondition', 'كود الخصم منتهي الصلاحية');
  }

  if (promoData.usageLimit && promoData.usedCount >= promoData.usageLimit) {
    throw new functions.https.HttpsError('failed-precondition', 'تم استخدام هذا الكود بالكامل');
  }

  // 4. Use transaction to ensure atomicity
  return db.runTransaction(async (transaction) => {
    // ---- READ FIRST: availability document ----
    const slotDateObj = new Date(slotDate);
    const dayOfWeek = slotDateObj.getDay() === 0 ? 7 : slotDateObj.getDay();
    
    const availabilityQuery = db
      .collection('users')
      .doc(mohaffezId)
      .collection('availability')
      .where('dayOfWeek', '==', dayOfWeek)
      .limit(1);

    const availabilitySnapshot = await transaction.get(availabilityQuery);
    const availabilityDoc = availabilitySnapshot.docs[0];

    // ---- NOW PERFORM ALL WRITES ----
    const requestRef = db.collection('sessionRequests').doc();
    const sessionRef = db.collection('hafizSessions').doc();

    const slotDateTimestamp = admin.firestore.Timestamp.fromDate(new Date(slotDate));
    const slotStartTimestamp = admin.firestore.Timestamp.fromDate(new Date(slotStart));
    const slotEndTimestamp = admin.firestore.Timestamp.fromDate(new Date(slotEnd));

    // Create session request
    transaction.set(requestRef, {
      studentId,
      mohaffezId,
      studentName,
      mohaffezName,
      sessionType,
      preferredTimeSlot,
      slotDate: slotDateTimestamp,
      slotStart: slotStartTimestamp,
      slotEnd: slotEndTimestamp,
      imamAddressText: imamAddressText || null,
      imamAddressLat: imamAddressLat || null,
      imamAddressLng: imamAddressLng || null,
      mohaffezPhone: mohaffezPhone || null,
      status: 'accepted',
      isPaid: true,
      paymentAmount: 0.0,
      promoCode,
      promoDiscount: 100,
      requiresPaymentOnAcceptance: false,
      selectedPaymentMethod: 'free_session',
      sessionId: sessionRef.id,
      createdAt: FieldValue.serverTimestamp(),
      acceptedAt: FieldValue.serverTimestamp(),
      paidAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    // Create session
    transaction.set(sessionRef, {
      requestId: requestRef.id,
      mohaffezId,
      studentId,
      mohaffezName,
      studentName,
      sessionType,
      location: imamAddressText || '',
      mohaffezPhone: mohaffezPhone || null,
      imamAddressLat: imamAddressLat || null,
      imamAddressLng: imamAddressLng || null,
      preferredTimeSlot,
      sessionDate: slotDateTimestamp,
      slotStart: slotStartTimestamp,
      slotEnd: slotEndTimestamp,
      status: 'accepted',
      isPaid: true,
      sessionPrice: 0.0,
      promoCode,
      createdAt: FieldValue.serverTimestamp(),
      juzCount: 1,
      sessionRating: 10,
    });

    // Increment promo code usage
    transaction.update(promoDoc.ref, {
      usedCount: FieldValue.increment(1),
      lastUsedAt: FieldValue.serverTimestamp(),
      lastUsedBy: studentId,
    });

    // Update availability slot (if document exists)
    if (!availabilitySnapshot.empty) {
      const availabilityData = availabilityDoc.data();
      const timeSlots = availabilityData.timeSlots || [];

      const normalizedSlot = preferredTimeSlot.replace(/\s/g, '');
      const updatedSlots = timeSlots.map((slot: any) => {
        const slotTime = `${slot.startTime}-${slot.endTime}`.replace(/\s/g, '');
        if (slotTime === normalizedSlot && slot.sessionType === sessionType && slot.enabled) {
          return { ...slot, enabled: false };
        }
        return slot;
      });

      transaction.update(availabilityDoc.ref, {
        timeSlots: updatedSlots,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    functions.logger.info('Free session created successfully', {
      sessionId: sessionRef.id,
      requestId: requestRef.id,
      studentId,
      mohaffezId,
      promoCode,
    });

    return {
      success: true,
      sessionId: sessionRef.id,
      requestId: requestRef.id,
      message: 'تم تأكيد الجلسة المجانية بنجاح',
    };
  });
});