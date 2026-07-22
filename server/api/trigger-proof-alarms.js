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
    
    const sessions = await db.collection("proofSessions")
      .where("status", "==", "pending")
      .where("scheduledTime", "<=", now)
      .get();
      
    let count = 0;
    for (const doc of sessions.docs) {
      const data = doc.data();
      const uid = data.userId;
      
      await doc.ref.update({
        status: "notified",
        notifiedAt: now
      });
      
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
          count++;
        } catch (e) {
          console.error(`Failed to send FCM to ${uid}:`, e);
        }
      }
    }
    
    res.status(200).json({ success: true, count });
  } catch (error) {
    console.error('Error triggering alarms:', error);
    res.status(500).json({ error: error.message });
  }
};
