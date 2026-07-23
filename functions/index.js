/**
 * DEPRECATED — Vercel'ga ko'chirildi, server/ papkasiga qarang.
 * Flowa Cloud Functions.
 *
 * `generatePlan` is a callable function that turns a free-text goal into a
 * calm, structured daily schedule using the Gemini API. The Gemini API key
 * lives ONLY here, injected at runtime from a Secret Manager secret — it is
 * never shipped in the mobile app.
 */
import {onCall, HttpsError, onRequest} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {setGlobalOptions} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getMessaging} from "firebase-admin/messaging";
import {createClient} from "@supabase/supabase-js";

setGlobalOptions({region: "us-central1", maxInstances: 10});

initializeApp();
const db = getFirestore();

// Set this with:  firebase functions:secrets:set GEMINI_API_KEY
const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
// Set these with:  firebase functions:secrets:set SUPABASE_URL
//                  firebase functions:secrets:set SUPABASE_SERVICE_ROLE_KEY
const SUPABASE_URL_SECRET = defineSecret("SUPABASE_URL");
const SUPABASE_SERVICE_ROLE_KEY_SECRET = defineSecret("SUPABASE_SERVICE_ROLE_KEY");

const MODEL = "gemini-2.0-flash";
const ALLOWED_CATEGORIES = ["study", "sport", "work", "personal", "wellness"];
const HHMM = /^([01]\d|2[0-3]):([0-5]\d)$/;
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

export const generatePlan = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    // --- Auth ---
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to generate a plan.",
      );
    }

    // --- Validate input ---
    const data = request.data ?? {};
    const goalText = typeof data.goalText === "string" ?
      data.goalText.trim() :
      "";
    if (goalText.length < 3) {
      throw new HttpsError(
        "invalid-argument",
        "Please describe your goals in a little more detail.",
      );
    }

    const dailyFreeHours = clampNumber(data.dailyFreeHours, 1, 16, 6);
    const focusType = typeof data.focusType === "string" ?
      data.focusType :
      "Study";
    const days = clampNumber(data.days, 1, 30, 1);
    const startDate = ISO_DATE.test(data.startDate) ? data.startDate : todayIso();
    const busyTimes = sanitizeBusyTimes(data.busyTimes);

    // --- Build prompt ---
    const prompt = buildPrompt({
      goalText,
      dailyFreeHours,
      focusType,
      startDate,
      days,
      busyTimes,
    });

    // --- Call Gemini ---
    let rawText;
    try {
      rawText = await callGemini(GEMINI_API_KEY.value(), prompt);
    } catch (err) {
      console.error("Gemini request failed:", err);
      throw new HttpsError(
        "unavailable",
        "The planning service is busy right now. Please try again.",
      );
    }

    // --- Parse + strictly validate ---
    const plan = validatePlan(rawText, startDate, days);
    if (plan.length === 0) {
      throw new HttpsError(
        "internal",
        "Could not craft a plan from that. Try rephrasing your goal.",
      );
    }
    return {tasks: plan};
  },
);

/**
 * Resets every user's weekly points at the start of each week (Monday 00:00).
 * Points accumulate during the week and reset here, per the Flowa spec.
 */
export const resetWeeklyPoints = onSchedule(
  {schedule: "every monday 00:00", timeZone: "Etc/UTC"},
  async () => {
    const users = await db.collection("users").get();
    let batch = db.batch();
    let pending = 0;

    for (const doc of users.docs) {
      batch.update(doc.ref, {weeklyPoints: 0});
      pending++;
      if (pending === 400) {
        await batch.commit();
        batch = db.batch();
        pending = 0;
      }
    }
    if (pending > 0) await batch.commit();

    console.log(`Reset weeklyPoints for ${users.size} users.`);
  },
);

function buildPrompt({goalText, dailyFreeHours, focusType, startDate, days, busyTimes}) {
  const busyText = busyTimes.length ?
    busyTimes.map((b) => `${b.start}-${b.end}`).join(", ") :
    "none";
  
  const startObj = new Date(startDate);
  const lastObj = new Date(startObj);
  lastObj.setDate(lastObj.getDate() + days - 1);
  const lastIso = lastObj.toISOString().slice(0, 10);
  const multiDay = days > 1;

  const lines = [
    "You are Flowa, a calm productivity planner.",
  ];
  if (multiDay) {
    lines.push(`Turn the user's goal(s) into a realistic, gentle schedule spread across ${days} consecutive days.`);
  } else {
    lines.push("Turn the user's goal(s) into a realistic, gentle schedule for a single day.");
  }
  lines.push("");
  lines.push(`Start date: ${startDate} (ISO yyyy-mm-dd)`);
  if (multiDay) {
    lines.push(`Plan EVERY day from ${startDate} to ${lastIso} (${days} days).`);
  }
  lines.push(`Primary focus type: ${focusType}`);
  lines.push(`Free hours available per day: ${dailyFreeHours}`);
  lines.push(`Busy ranges to avoid on the start day (24h): ${busyText}`);
  lines.push("");
  lines.push(`User's goals: "${goalText}"`);
  lines.push("");
  lines.push("Rules:");
  lines.push('- The input may contain SEVERAL goals (separated by "and", commas, new lines, or sentences). Plan EACH goal SEPARATELY, then merge all tasks into one combined schedule.');
  lines.push('- For each goal: split a quantity over its span into even chunks (e.g. "100 words in 10 days" → ~10 words/day); for a recurring goal (e.g. "run 3 times a week"), schedule that many sessions spread across the week(s); a goal with no span belongs on the start day.');
  lines.push('- Each task title MUST name which goal it serves (e.g. "Vocabulary: 10 words", "Read 25 pages", "Run").');
  if (multiDay) {
    lines.push(`- Spread tasks across the days from ${startDate} to ${lastIso} (each within that goal's own span). Do NOT pile everything onto the first day.`);
    lines.push('- Give each day a sensible number of tasks within the free hours, with short restful breaks.');
    lines.push(`- Every task MUST set "date" to its own day (ISO yyyy-mm-dd) within ${startDate}..${lastIso}.`);
  } else {
    lines.push(`- Keep total scheduled time within the available free hours; all tasks are dated ${startDate}.`);
    lines.push('- Add short restful/wellness breaks between intense tasks.');
  }
  lines.push('- NEVER overlap two tasks at the same time on the same day, and avoid the busy ranges; leave gaps between tasks.');
  lines.push(`- category MUST be one of: ${ALLOWED_CATEGORIES.join(', ')}.`);
  lines.push('- startTime is 24-hour HH:mm. durationMinutes is an integer 10-180.');
  lines.push('- Order tasks by date, then startTime.');
  lines.push('Return ONLY a JSON array of objects with keys:');
  lines.push('title, category, date, startTime, durationMinutes.');

  return lines.join("\n");
}

async function callGemini(apiKey, prompt) {
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${MODEL}:generateContent?key=${apiKey}`;

  const body = {
    contents: [{role: "user", parts: [{text: prompt}]}],
    generationConfig: {
      temperature: 0.7,
      responseMimeType: "application/json",
      responseSchema: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            title: {type: "STRING"},
            category: {type: "STRING", enum: ALLOWED_CATEGORIES},
            date: {type: "STRING"},
            startTime: {type: "STRING"},
            durationMinutes: {type: "INTEGER"},
          },
          required: [
            "title",
            "category",
            "date",
            "startTime",
            "durationMinutes",
          ],
        },
      },
    },
  };

  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Gemini ${res.status}: ${detail}`);
  }

  const json = await res.json();
  const text = json?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (typeof text !== "string") {
    throw new Error("Gemini returned no text content.");
  }
  return text;
}

/** Parses Gemini's text and returns only well-formed task objects. */
function validatePlan(rawText, startDate, days) {
  let parsed;
  try {
    parsed = JSON.parse(rawText);
  } catch (_) {
    throw new HttpsError(
      "internal",
      "The planner returned an unexpected response. Please try again.",
    );
  }
  if (!Array.isArray(parsed)) return [];

  const clean = [];
  for (const item of parsed) {
    if (!item || typeof item !== "object") continue;

    const title = typeof item.title === "string" ? item.title.trim() : "";
    const category = ALLOWED_CATEGORIES.includes(item.category) ?
      item.category :
      "study";
    const startTime = typeof item.startTime === "string" ?
      item.startTime.trim() :
      "";
    const durationMinutes = Math.round(Number(item.durationMinutes));
    const itemDate = typeof item.date === "string" && ISO_DATE.test(item.date) ? 
      item.date : 
      startDate;

    if (title.length === 0) continue;
    if (!HHMM.test(startTime)) continue;
    if (!Number.isFinite(durationMinutes)) continue;

    clean.push({
      title: title.slice(0, 120),
      category,
      date: itemDate,
      startTime,
      durationMinutes: clamp(durationMinutes, 10, 180),
    });
  }

  clean.sort((a, b) => {
    if (a.date < b.date) return -1;
    if (a.date > b.date) return 1;
    return a.startTime.localeCompare(b.startTime);
  });
  
  const maxTasks = days <= 1 ? 8 : clamp(days * 6, 8, 80);
  return clean.slice(0, maxTasks);
}

function sanitizeBusyTimes(value) {
  if (!Array.isArray(value)) return [];
  return value
    .filter(
      (b) =>
        b &&
        typeof b.start === "string" &&
        typeof b.end === "string" &&
        HHMM.test(b.start) &&
        HHMM.test(b.end),
    )
    .slice(0, 20);
}

function clampNumber(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) return fallback;
  return clamp(n, min, max);
}

function clamp(n, min, max) {
  return Math.min(max, Math.max(min, n));
}

function todayIso() {
  return new Date().toISOString().slice(0, 10);
}

// --- Random Proof System ---

// 1. Schedule daily random proofs
export const scheduleRandomProofs = onSchedule(
  {schedule: "every day 00:00", timeZone: "Etc/UTC"},
  async () => {
    // Query all tasks across all users that require proof
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
      
      // Expire at end of day or 24h later
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
    
    console.log(`Scheduled ${count} proof sessions.`);
  }
);

// 2. Trigger alarms when time arrives
export const triggerProofAlarms = onSchedule(
  {schedule: "every 1 minutes", timeZone: "Etc/UTC"},
  async () => {
    const now = new Date();
    
    const sessions = await db.collection("proofSessions")
      .where("status", "==", "pending")
      .where("scheduledTime", "<=", now)
      .get();
      
    let count = 0;
    for (const doc of sessions.docs) {
      const data = doc.data();
      const uid = data.userId;
      
      // Update status to notified
      await doc.ref.update({
        status: "notified",
        notifiedAt: now
      });
      
      // Send FCM push notification
      const userDoc = await db.collection("users").doc(uid).get();
      const fcmToken = userDoc.data()?.fcmToken;
      
      if (fcmToken) {
        try {
          await getMessaging().send({
            token: fcmToken,
            notification: {
              title: "📸 Hozir vaqt!",
              body: "15 soniya ichida isbot yuboring!"
            },
            data: {
              type: "proof_request",
              sessionId: doc.id
            },
            android: {
              priority: "high",
            },
            apns: {
              payload: {
                aps: {
                  contentAvailable: true,
                }
              }
            }
          });
          count++;
        } catch (e) {
          console.error(`Failed to send FCM to ${uid}:`, e);
        }
      }
    }
    
    console.log(`Triggered ${count} alarms.`);
  }
);

// 3. Check for missed proofs
export const checkMissedProofs = onSchedule(
  {schedule: "every 1 minutes", timeZone: "Etc/UTC"},
  async () => {
    const now = new Date();
    // 2 minutes ago deadline
    const deadline = new Date(now.getTime() - 2 * 60 * 1000);
    
    const sessions = await db.collection("proofSessions")
      .where("status", "==", "notified")
      .where("notifiedAt", "<", deadline)
      .get();
      
    let count = 0;
    for (const doc of sessions.docs) {
      await doc.ref.update({
        status: "missed"
      });
      count++;
    }
    
    console.log(`Marked ${count} sessions as missed.`);
  }
);

// ============================================================================
// QISM 3 — Do'stga ko'rsatish, Telegram, 24 soatlik o'chirish
// ============================================================================

// Set this with:  firebase functions:secrets:set TELEGRAM_BOT_TOKEN
const TELEGRAM_BOT_TOKEN = defineSecret("TELEGRAM_BOT_TOKEN");

// ---------------------------------------------------------------------------
// BOSQICH A — linkTelegramChatId

export const linkTelegramChatId = onRequest(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (req, res) => {
    // Faqat POST qabul qilamiz
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const update = req.body;
    const message = update?.message;
    if (!message) {
      res.status(200).send("ok"); // Telegram boshqa event turlarini ham yuboradi
      return;
    }

    const text = (message.text ?? "").trim();
    const chatId = String(message.chat?.id ?? "");

    // /start <uid> formatini parse qilamiz
    if (!text.startsWith("/start")) {
      // Foydalanuvchiga yo'riqnoma yuboramiz
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN.value(),
        chatId,
        "Salom! 👋 Flowa ilovasidan kod kiriting:\n" +
        "Sozlamalar → Tasodifiy Isbot → Telegram ulanishi",
      );
      res.status(200).send("ok");
      return;
    }

    const parts = text.split(" ");
    const uid = parts[1]?.trim() ?? "";

    if (!uid) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN.value(),
        chatId,
        "❌ Kod topilmadi. Iltimos, Flowa ilovasidan to'liq kodni nusxalab yuboring.",
      );
      res.status(200).send("ok");
      return;
    }

    // UID mavjudligini tekshiramiz
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      await sendTelegramMessage(
        TELEGRAM_BOT_TOKEN.value(),
        chatId,
        "❌ Foydalanuvchi topilmadi. Iltimos, kod to'g'riligini tekshiring.",
      );
      res.status(200).send("ok");
      return;
    }

    // chat_id ni saqlаymiz
    await db.collection("users").doc(uid).update({telegramChatId: chatId});

    const name = userDoc.data()?.name ?? "Foydalanuvchi";
    await sendTelegramMessage(
      TELEGRAM_BOT_TOKEN.value(),
      chatId,
      `✅ Muvaffaqiyatli ulandi, ${name}!\n\n` +
      "Endi do'stlaringiz isbot yuborganida yoki o'tkazib yuborganida " +
      "bu yerda xabar olasiz. 🌿",
    );

    res.status(200).send("ok");
  },
);

// ---------------------------------------------------------------------------
// BOSQICH C — sendProofTelegramNotice

export const sendProofTelegramNotice = onDocumentUpdated(
  {document: "proofSessions/{sessionId}", secrets: [TELEGRAM_BOT_TOKEN]},
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    if (!before || !after) return;

    const prevStatus = before.status;
    const newStatus = after.status;

    // Faqat completed yoki missed ga o'tganda ishlasin
    if (
      prevStatus === newStatus ||
      (newStatus !== "completed" && newStatus !== "missed")
    ) {
      return;
    }

    const userId = after.userId;
    if (!userId) return;

    // Foydalanuvchi profilini olamiz
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) return;
    const userData = userDoc.data();
    const userName = userData?.name ?? "Foydalanuvchi";

    // Task nomini olamiz (taskTitle session'da saqlangan bo'lishi mumkin)
    let taskTitle = after.taskTitle ?? "";
    if (!taskTitle && after.taskId) {
      // taskId dan topishga urinib ko'ramiz
      const taskSnap = await db
        .collectionGroup("tasks")
        .where("__name__", ">=", after.taskId)
        .limit(1)
        .get();
      taskTitle = taskSnap.docs[0]?.data()?.title ?? "Vazifa";
    }
    if (!taskTitle) taskTitle = "Vazifa";

    // sharedWith ro'yxatidagi do'stlar
    const sharedWith = Array.isArray(userData?.sharedWith)
      ? userData.sharedWith
      : [];
    if (sharedWith.length === 0) return;

    // Xabar matni
    const message = newStatus === "completed"
      ? `✅ ${userName} "${taskTitle}" bo'yicha bugungi isbotni yubordi. Ko'rish uchun ilovani oching.`
      : `😅 ${userName} bugungi "${taskTitle}" isbotini o'tkazib yubordi.`;

    // Har bir do'stga xabar yuboramiz
    const token = TELEGRAM_BOT_TOKEN.value();
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

    console.log(`Telegram notice sent for session ${event.params.sessionId} → ${newStatus}`);
  },
);

// ---------------------------------------------------------------------------
// BOSQICH D — cleanupExpiredProofs

export const cleanupExpiredProofs = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "Etc/UTC",
    secrets: [SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET],
  },
  async () => {
    const now = new Date();
    const cutoff = new Date(now.getTime() - 24 * 60 * 60 * 1000);

    // 24 soatdan eski completed yoki missed sessiyalar (faqat rasm URL si borlar)
    const expiredSessions = await db.collection("proofSessions")
      .where("createdAt", "<", cutoff)
      .where("status", "in", ["completed", "missed"])
      .get();

    // Supabase Storage client (service role key bilan)
    const supabase = createClient(
      SUPABASE_URL_SECRET.value(),
      SUPABASE_SERVICE_ROLE_KEY_SECRET.value(),
    );

    let cleaned = 0;

    for (const doc of expiredSessions.docs) {
      const data = doc.data();

      // Agar allaqachon tozalangan bo'lsa (URL yo'q), o'tkazib yuboramiz
      if (!data.rearPhotoUrl && !data.frontPhotoUrl) continue;

      const sessionId = doc.id;
      const filesToDelete = [
        `${sessionId}/rear.jpg`,
        `${sessionId}/front.jpg`,
      ];

      // Supabase Storage dan o'chiramiz
      const {error: storageError} = await supabase.storage
        .from("proofs")
        .remove(filesToDelete);

      if (storageError) {
        console.error(`Storage o'chirish xatosi (${sessionId}):`, storageError.message);
      }

      // Firestore'dan faqat URL maydonlarini olib tashlaymiz
      // (status va sanani saqlaymiz — streak/stats uchun)
      await doc.ref.update({
        rearPhotoUrl: FieldValue.delete(),
        frontPhotoUrl: FieldValue.delete(),
        photosDeletedAt: now,
      });

      cleaned++;
    }

    console.log(`cleanupExpiredProofs: ${cleaned} sessiya tozalandi.`);
  },
);

// ---------------------------------------------------------------------------
// Yordamchi — Telegram xabar yuborish
// ---------------------------------------------------------------------------
async function sendTelegramMessage(token, chatId, text) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Telegram API ${res.status}: ${detail}`);
  }
  return res.json();
}

