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
      
      if (data.timeWindowStart) {
        const parts = data.timeWindowStart.split(":");
        startHour = parseInt(parts[0]) || 9;
        startMin = parseInt(parts[1]) || 0;
      }
      if (data.timeWindowEnd) {
        const parts = data.timeWindowEnd.split(":");
        endHour = parseInt(parts[0]) || 21;
        endMin = parseInt(parts[1]) || 0;
      }
      
      const startTotalMins = startHour * 60 + startMin;
      const endTotalMins = endHour * 60 + endMin;
      const durationMins = Math.max(1, endTotalMins - startTotalMins);
      
      const randomMins = startTotalMins + Math.floor(Math.random() * durationMins);
      
      const scheduledTime = new Date(now);
      scheduledTime.setUTCHours(Math.floor(randomMins / 60));
      scheduledTime.setUTCMinutes(randomMins % 60);
      scheduledTime.setUTCSeconds(0);
      scheduledTime.setUTCMilliseconds(0);
      
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
