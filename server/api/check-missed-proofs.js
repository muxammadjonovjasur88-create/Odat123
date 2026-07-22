const { db } = require('../utils/firebase');
const { sendTelegramMessage } = require('../utils/telegram');

function checkAuth(req, res) {
  const secret = req.headers['x-cron-secret'] || req.query['cron_secret'];
  if (secret !== process.env.CRON_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return false;
  }
  return true;
}

async function notifyFriends(userId, taskId) {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  if (!token) return;

  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) return;
  const userData = userDoc.data();
  const userName = userData?.name ?? "Foydalanuvchi";
  
  const sharedWith = Array.isArray(userData?.sharedWith) ? userData.sharedWith : [];
  if (sharedWith.length === 0) return;

  let taskTitle = "Vazifa";
  if (taskId) {
    const taskSnap = await db.collectionGroup("tasks").where("__name__", ">=", taskId).limit(1).get();
    if (!taskSnap.empty) {
      taskTitle = taskSnap.docs[0].data()?.title ?? "Vazifa";
    }
  }

  const message = `😅 ${userName} bugungi "${taskTitle}" isbotini o'tkazib yubordi.`;

  for (const friendUid of sharedWith) {
    const friendDoc = await db.collection("users").doc(friendUid).get();
    const chatId = friendDoc.data()?.telegramChatId;
    if (chatId) {
      try {
        await sendTelegramMessage(token, chatId, message);
      } catch (e) {
        console.error(`Telegram xabar yuborilmadi (${friendUid}):`, e);
      }
    }
  }
}

module.exports = async function handler(req, res) {
  if (!checkAuth(req, res)) return;

  try {
    const now = new Date();
    // 2 minutes ago
    const deadline = new Date(now.getTime() - 2 * 60 * 1000);
    
    const sessions = await db.collection("proofSessions")
      .where("status", "==", "notified")
      .where("notifiedAt", "<", deadline)
      .get();
      
    let count = 0;
    for (const doc of sessions.docs) {
      await doc.ref.update({ status: "missed" });
      const data = doc.data();
      await notifyFriends(data.userId, data.taskId);
      count++;
    }
    
    res.status(200).json({ success: true, count });
  } catch (error) {
    console.error('Error checking missed proofs:', error);
    res.status(500).json({ error: error.message });
  }
};
