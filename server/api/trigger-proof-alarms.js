const { db, messaging } = require('../utils/firebase');

function checkAuth(req, res) {
  const secret = req.headers['x-cron-secret'] || req.query['cron_secret'];
  if (secret !== process.env.CRON_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}

module.exports = async function handler(req, res) {
  if (!checkAuth(req, res)) return;

  try {
    const now = new Date();
    console.log('DEBUG: now =', now.toISOString());

    const allPending = await db.collection("proofSessions")
      .where("status", "==", "pending")
      .get();
    
    console.log(`DEBUG: Found ${allPending.docs.length} pending sessions total.`);
    const debugDetails = [];

    for (const doc of allPending.docs) {
      const data = doc.data();
      let scheduledDate = null;
      let isTimestamp = false;

      if (data.scheduledTime) {
        if (typeof data.scheduledTime.toDate === 'function') {
          scheduledDate = data.scheduledTime.toDate();
          isTimestamp = true;
        } else if (typeof data.scheduledTime === 'string') {
          scheduledDate = new Date(data.scheduledTime);
        } else if (data.scheduledTime._seconds) {
          scheduledDate = new Date(data.scheduledTime._seconds * 1000);
          isTimestamp = true;
        }
      }

      const isDue = scheduledDate ? scheduledDate <= now : false;
      
      debugDetails.push({
        id: doc.id,
        scheduledTimeRaw: data.scheduledTime,
        scheduledTimeParsed: scheduledDate ? scheduledDate.toISOString() : null,
        isTimestamp,
        isDue,
        userId: data.userId
      });

      console.log(`DEBUG: Session ${doc.id}: raw =`, data.scheduledTime, 'parsed =', scheduledDate?.toISOString(), 'isTimestamp =', isTimestamp, 'isDue =', isDue);
    }
    
    // Query Firestore for sessions where scheduledTime <= now
    const sessions = await db.collection("proofSessions")
      .where("status", "==", "pending")
      .where("scheduledTime", "<=", now)
      .get();
      
    let fcmSentCount = 0;
    let notifiedCount = 0;
    const processedSessions = [];

    for (const doc of sessions.docs) {
      const data = doc.data();
      const uid = data.userId;
      
      await doc.ref.update({
        status: "notified",
        notifiedAt: now
      });
      notifiedCount++;
      
      let fcmSent = false;
      let fcmError = null;

      const userDoc = await db.collection("users").doc(uid).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        try {
          await messaging.send({
            token: fcmToken,
            notification: {
              title: "📸 Hozir vaqt!",
              body: "15 soniya ichida isbot yuboring!"
            },
            data: {
              type: "proof_request",
              sessionId: doc.id
            },
            android: { priority: "high" },
            apns: { payload: { aps: { contentAvailable: true } } }
          });
          fcmSentCount++;
          fcmSent = true;
        } catch (e) {
          console.error(`Failed to send FCM to ${uid}:`, e);
          fcmError = e.message;
        }
      } else {
        console.warn(`User ${uid} has no fcmToken in Firestore!`);
        fcmError = "No FCM token found for user";
      }

      processedSessions.push({
        id: doc.id,
        userId: uid,
        fcmSent,
        fcmError
      });
    }
    
    res.status(200).json({
      success: true,
      count: notifiedCount,
      notifiedCount,
      fcmSentCount,
      pendingTotal: allPending.docs.length,
      matchedInQuery: sessions.docs.length,
      serverNow: now.toISOString(),
      debugPending: debugDetails,
      processedSessions
    });
  } catch (error) {
    console.error('Error triggering alarms:', error);
    res.status(500).json({ error: error.message });
  }
};
