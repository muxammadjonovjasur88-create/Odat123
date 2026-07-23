const { db } = require('../utils/firebase');

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
    const tasksSnapshot = await db.collectionGroup("tasks").where("proofRequired", "==", true).get();
    
    let count = 0;
    const now = new Date();
    
    for (const doc of tasksSnapshot.docs) {
      const data = doc.data();
      if (data.isCompleted) continue;
      
      const uid = doc.ref.parent.parent?.id;
      if (!uid) continue;

      let startHour = 9, startMin = 0;
      let endHour = 21, endMin = 0;
      
      if (data.timeWindowStart && typeof data.timeWindowStart === 'string') {
        const parts = data.timeWindowStart.split(":");
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        if (!isNaN(h)) startHour = h;
        if (!isNaN(m)) startMin = m;
      }
      if (data.timeWindowEnd && typeof data.timeWindowEnd === 'string') {
        const parts = data.timeWindowEnd.split(":");
        const h = parseInt(parts[0], 10);
        const m = parseInt(parts[1], 10);
        if (!isNaN(h)) endHour = h;
        if (!isNaN(m)) endMin = m;
      }
      
      const startTotalMins = startHour * 60 + startMin;
      const endTotalMins = endHour * 60 + endMin;
      const durationMins = Math.max(1, endTotalMins - startTotalMins);
      
      const randomMins = startTotalMins + Math.floor(Math.random() * durationMins);
      const localHour = Math.floor(randomMins / 60);
      const localMin = randomMins % 60;
      
      // Asia/Tashkent UTC+5 offset (5 hours)
      const TASHKENT_OFFSET_MS = 5 * 60 * 60 * 1000;
      const tashkentNow = new Date(now.getTime() + TASHKENT_OFFSET_MS);
      const year = tashkentNow.getUTCFullYear();
      const month = tashkentNow.getUTCMonth();
      const date = tashkentNow.getUTCDate();
      
      const localAsUtcMs = Date.UTC(year, month, date, localHour, localMin, 0, 0);
      const scheduledTime = new Date(localAsUtcMs - TASHKENT_OFFSET_MS);
      
      const expiresAt = new Date(scheduledTime.getTime() + 24 * 60 * 60 * 1000);
      
      await db.collection("proofSessions").add({
        taskId: doc.id,
        userId: uid,
        scheduledTime: scheduledTime,
        status: "pending",
        expiresAt: expiresAt,
        createdAt: new Date(),
      });
      count++;
    }
    
    res.status(200).json({ success: true, count });
  } catch (error) {
    console.error('Error scheduling proofs:', error);
    res.status(500).json({ error: error.message });
  }
};
