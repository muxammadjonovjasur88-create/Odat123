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

function toDate(value) {
  if (!value) return null;
  if (typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'string') return new Date(value);
  if (value instanceof Date) return value;
  if (typeof value._seconds === 'number') return new Date(value._seconds * 1000);
  return null;
}

function formatDateYmd(date) {
  return date.toISOString().slice(0, 10);
}

function extractInsightText(result) {
  if (!result) return null;
  if (typeof result.output_text === 'string' && result.output_text.trim()) {
    return result.output_text.trim();
  }
  if (Array.isArray(result.output)) {
    return result.output
      .map((item) => {
        if (typeof item === 'string') return item;
        if (Array.isArray(item.content)) {
          return item.content.map((c) => c.text || '').join('');
        }
        return item.text || '';
      })
      .join('\n')
      .trim();
  }
  if (typeof result.text === 'string') {
    return result.text.trim();
  }
  return null;
}

function getMoodEmojiLabel(moodResponse) {
  if (!moodResponse) return '😐';
  const normalized = String(moodResponse).toLowerCase();
  if (normalized === 'great' || normalized === 'happy' || normalized === '😊') return '😊';
  if (normalized === 'hard' || normalized === 'neutral' || normalized === '😐') return '😐';
  if (normalized === 'missed' || normalized === 'sad' || normalized === '😔') return '😔';
  return '😐';
}

function buildGeminiPrompt({ completedCount, missedCount, moodCounts, currentStreak, longestStreak, activeWindow }) {
  const lines = [
    'Sen foydalanuvchining shaxsiy samaradorlik yordamchisisan. Quyidagi haftalik ma\'lumotlar asosida, o\'zbek tilida, do\'stona va motivatsion ohangda, 3-4 gapdan iborat qisqa tahlil yoz. Aniq bitta amaliy maslahat bilan yakunla. Raqamlarni tabiiy tarzda ishlat, quruq statistika sifatida emas.',
    '',
    'Ma\'lumotlar:',
    `- Bajarilgan vazifalar soni: ${completedCount}`,
    `- O'tkazib yuborilgan vazifalar soni: ${missedCount}`,
    `- Kayfiyat javoblari: [😊: ${moodCounts['😊'] || 0} marta, 😐: ${moodCounts['😐'] || 0} marta, 😔: ${moodCounts['😔'] || 0} marta]`,
    `- Joriy streak: ${currentStreak} kun`,
    `- Eng ko'p faol bo'lgan vaqt oralig'i: ${activeWindow || 'Aniqlanmadi'}`,
    '',
    "Javobni FAQAT tahlil matni sifatida ber, boshqa hech narsa qo'shma.",
  ];

  return lines.join('\n');
}

async function queryGeminiInsight(prompt) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new Error('Missing GEMINI_API_KEY');
  }

  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent?key=${apiKey}`;
  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      contents: [
        {
          parts: [{ text: prompt }],
        },
      ],
    }),
  });

  if (!response.ok) {
    const payload = await response.text();
    console.error('Gemini API error response body:', payload);
    throw new Error(`Gemini API error ${response.status}: ${payload}`);
  }

  const result = await response.json();
  const insightText =
    result?.candidates?.[0]?.content?.parts?.[0]?.text ||
    extractInsightText(result);

  if (!insightText || !insightText.trim()) {
    throw new Error('Gemini API returned no text');
  }

  return insightText.trim();
}

function findActiveWindow(dates) {
  if (!dates.length) return null;
  const hourCounts = {};
  dates.forEach((date) => {
    if (!(date instanceof Date) || Number.isNaN(date.getTime())) return;
    const hour = date.getUTCHours();
    hourCounts[hour] = (hourCounts[hour] || 0) + 1;
  });
  const entries = Object.entries(hourCounts);
  if (!entries.length) return null;
  entries.sort((a, b) => b[1] - a[1]);
  const [bestHour] = entries[0];
  const startHour = Number(bestHour);
  const endHour = (startHour + 1) % 24;
  return `${String(startHour).padStart(2, '0')}:00 - ${String(endHour).padStart(2, '0')}:00`; 
}

module.exports = async function handler(req, res) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  if (!checkAuth(req, res)) return;

  try {
    const now = new Date();
    const weekStart = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const weekStartDate = formatDateYmd(weekStart);

    const usersSnapshot = await db.collection('users').get();
    const results = [];

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data() || {};
      const currentStreak = Number(userData.streak ?? userData.currentStreak ?? 0);
      const longestStreak = Number(userData.longestStreak ?? 0);
      const telegramChatId = userData.telegramChatId;

      const proofSnapshot = await db.collection('proofSessions')
        .where('userId', '==', userId)
        .where('createdAt', '>=', weekStart)
        .where('createdAt', '<=', now)
        .get();

      const moodCounts = { '😊': 0, '😐': 0, '😔': 0 };
      const moodDateTimes = [];

      for (const doc of proofSnapshot.docs) {
        const data = doc.data();
        const emoji = getMoodEmojiLabel(data.moodResponse);
        moodCounts[emoji] = (moodCounts[emoji] || 0) + 1;
        const createdAt = toDate(data.createdAt);
        if (createdAt) moodDateTimes.push(createdAt);
      }

      const tasksSnapshot = await db.collection('users').doc(userId).collection('tasks')
        .where('dueDate', '>=', weekStart)
        .where('dueDate', '<=', now)
        .get();

      let completedCount = 0;
      let missedCount = 0;
      const taskDates = [];
      for (const doc of tasksSnapshot.docs) {
        const data = doc.data();
        const isCompleted = Boolean(data.isCompleted);
        const dueDate = toDate(data.dueDate);
        if (isCompleted) {
          completedCount += 1;
        } else if (dueDate && dueDate <= now) {
          missedCount += 1;
        }
        if (dueDate) taskDates.push(dueDate);
      }

      const blockData = {};
      if (typeof userData.blockAttempts !== 'undefined') {
        blockData.attempts = userData.blockAttempts;
      }
      if (typeof userData.blockingStats !== 'undefined') {
        blockData.stats = userData.blockingStats;
      }

      const activityCount = proofSnapshot.size + completedCount + missedCount;
      console.log(`weekly-insight debug: user=${userId} proofs=${proofSnapshot.size} tasksTotal=${tasksSnapshot.size} completed=${completedCount} missed=${missedCount} activityCount=${activityCount}`);
      if (activityCount === 0) {
        console.log(`weekly-insight skip: user=${userId} skipped because no activity in the last 7 days`);
        continue;
      }

      const activeWindow = findActiveWindow([...moodDateTimes, ...taskDates]);
      const prompt = buildGeminiPrompt({
        completedCount,
        missedCount,
        moodCounts,
        currentStreak,
        longestStreak,
        activeWindow,
      });

      let insightText;
      try {
        insightText = await queryGeminiInsight(prompt);
      } catch (error) {
        console.error(`Gemini error for user ${userId}:`, error);
        continue;
      }

      const insightId = `${userId}_${weekStartDate}`;
      await db.collection('weeklyInsights').doc(insightId).set({
        userId,
        weekStartDate,
        insightText,
        createdAt: new Date(),
      });

      if (telegramChatId) {
        try {
          await sendTelegramMessage(
            process.env.TELEGRAM_BOT_TOKEN,
            telegramChatId,
            `📊 Haftalik hisobotingiz:\n\n${insightText}`,
          );
        } catch (error) {
          console.error(`Telegram send failed for user ${userId}:`, error);
        }
      }

      results.push({ userId, insightId, telegramSent: Boolean(telegramChatId) });
    }

    res.status(200).json({ success: true, count: results.length, results });
  } catch (error) {
    console.error('Error generating weekly insights:', error);
    res.status(500).json({ error: error.message });
  }
};