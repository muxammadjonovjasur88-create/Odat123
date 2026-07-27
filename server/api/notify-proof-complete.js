const { db } = require('../utils/firebase');
const { sendTelegramMessage } = require('../utils/telegram');

async function notifyFriends(userId, taskId, userName, sessionId) {
  const token = process.env.TELEGRAM_BOT_TOKEN;
  if (!token) return;

  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) return;
  const userData = userDoc.data();
  const name = userName || userData?.name || "Foydalanuvchi";
  
  const sharedWith = Array.isArray(userData?.sharedWith) ? userData.sharedWith : [];
  if (sharedWith.length === 0) return;

  let taskTitle = "Vazifa";
  if (userId && taskId) {
    const taskDoc = await db.collection("users").doc(userId).collection("tasks").doc(taskId).get();
    if (taskDoc.exists) {
      taskTitle = taskDoc.data()?.title ?? "Vazifa";
    }
  }

  // Get mood response emoji
  let moodEmoji = "😊 (Ha, ajoyib)";
  if (sessionId) {
    const sessionDoc = await db.collection("proofSessions").doc(sessionId).get();
    if (sessionDoc.exists) {
      const sessionData = sessionDoc.data();
      const mood = sessionData?.moodResponse;
      if (mood === 'great') moodEmoji = "😊 (Ha, ajoyib)";
      else if (mood === 'hard') moodEmoji = "😐 (Ha, lekin qiyin bo'ldi)";
      else if (mood === 'missed') moodEmoji = "😔 (Yo'q, chalg'idim)";
    }
  }

  const message = `✅ ${name} "${taskTitle}" vazifasini ${moodEmoji} bilan belgiladi.`;

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
  // Simple check
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { sessionId, userId, taskId, userName } = req.body || {};
  if (!sessionId || !userId) {
    return res.status(400).json({ error: 'Missing parameters' });
  }

  try {
    await notifyFriends(userId, taskId, userName, sessionId);
    res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error notifying proof complete:', error);
    res.status(500).json({ error: error.message });
  }
};
