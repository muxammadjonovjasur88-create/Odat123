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
import {onDocumentUpdated, onDocumentCreated} from "firebase-functions/v2/firestore";
import {defineSecret} from "firebase-functions/params";
import {setGlobalOptions} from "firebase-functions/v2";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {getStorage} from "firebase-admin/storage";
import {getAuth} from "firebase-admin/auth";
import {getMessaging} from "firebase-admin/messaging";
import {randomUUID} from "crypto";
import { createClient } from "@supabase/supabase-js";
import { GoogleGenerativeAI } from "@google/generative-ai";
import {
  verifyTelegramInitData,
  isTelegramUserAdmin,
  assertAdminAuth,
} from "./telegramAdminAuth.js";
import {
  adminUploadBookHandler,
  adminListBooksHandler,
  adminUpdateBookHandler,
  adminDeleteBookHandler,
  generateBookQuizHandler,
  updateBookProgressHandler,
  submitBookQuizHandler,
} from "./bookFunctions.js";
import { processTelegramUpdate, cleanupPlayersDatabase } from "./telegramBotHandler.js";

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

export const createLoginRequest = onCall(async () => {
  const token = randomUUID();
  const now = Date.now();
  const expiresAt = now + 5 * 60 * 1000;

  await db.collection("loginRequests").doc(token).set({
    token: token,
    status: "pending",
    createdAt: FieldValue.serverTimestamp(),
    createdAtMs: now,
    expiresAt: expiresAt,
  });

  return { token, expiresAt };
});

export const generateCustomTokenForLogin = onCall(async (request) => {
  const token = typeof request.data?.token === "string" ? request.data.token.trim() : "";
  if (!token) {
    throw new HttpsError("invalid-argument", "Token kiritilmadi.");
  }

  const docRef = db.collection("loginRequests").doc(token);
  const snap = await docRef.get();
  if (!snap.exists) {
    throw new HttpsError("not-found", "Kirish so'rovi topilmadi.");
  }

  const data = snap.data() || {};
  if (data.status !== "approved") {
    throw new HttpsError("failed-precondition", "Kirish so'rovi hali tasdiqlanmagan.");
  }

  if (Date.now() > (data.expiresAt || 0)) {
    throw new HttpsError("failed-precondition", "Kirish so'rovi muddati o'tgan.");
  }

  const uid = data.uid;
  if (!uid) {
    throw new HttpsError("internal", "Foydalanuvchi ID topilmadi.");
  }

  let customToken = data.customToken;
  if (!customToken) {
    customToken = await getAuth().createCustomToken(uid);
    await docRef.update({ customToken });
  }

  return { customToken, uid };
});

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

export const generateDailyPlan = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "You must be signed in to generate a daily plan.",
      );
    }

    const data = request.data ?? {};
    const userId = typeof data.user_id === "string" ? data.user_id : request.auth.uid;
    const userPreferences = data.user_preferences ?? {};
    const userGoals = Array.isArray(data.user_goals) ? data.user_goals : [];
    const currentDayOfWeek = typeof data.current_day_of_week === "string" ? data.current_day_of_week : "Today";

    if (userGoals.length === 0) {
      throw new HttpsError(
        "invalid-argument",
        "user_goals must be a non-empty array of goal objects.",
      );
    }

    const prompt = buildDailyPlanPrompt({
      userId,
      userPreferences,
      userGoals,
      currentDayOfWeek,
    });

    let rawText;
    try {
      rawText = await callGeminiForDailyPlan(GEMINI_API_KEY.value(), prompt);
    } catch (err) {
      console.error("Gemini request failed in generateDailyPlan:", err);
      throw new HttpsError(
        "unavailable",
        "The AI planning service is busy right now. Please try again.",
      );
    }

    try {
      return JSON.parse(rawText);
    } catch (err) {
      console.error("Failed to parse Gemini output:", rawText);
      throw new HttpsError(
        "internal",
        "Failed to generate a valid plan from the AI response.",
      );
    }
  },
);

export const askAiAssistant = onCall(
  {secrets: [GEMINI_API_KEY]},
  async (request) => {
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "AI yordamchidan foydalanish uchun tizimga kiring.",
      );
    }

    const data = request.data ?? {};
    const userMessage = typeof data.message === "string" ? data.message.trim() : "";
    if (!userMessage) {
      throw new HttpsError(
        "invalid-argument",
        "Iltimos, so'rovingizni yozing.",
      );
    }

    const uid = request.auth.uid;
    const now = new Date();

    // 1. Fetch user doc for overall stats
    let userData = {};
    try {
      const userSnap = await db.collection("users").doc(uid).get();
      userData = userSnap.data() || {};
    } catch (err) {
      console.warn("Could not read user doc:", err);
    }

    const weeklyPoints = Number(userData.weeklyPoints || 0);
    const streak = Number(userData.streak || 0);
    const totalFocusMinutes = Number(userData.totalFocusMinutes || 0);

    // 2. Fetch last 7 days of daily stats from users/{uid}/daily
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
    sevenDaysAgo.setHours(0, 0, 0, 0);

    const daysName = ["Yak", "Dush", "Sesh", "Chor", "Pay", "Jum", "Shan"];
    const dailyCompleted = {
      Dush: 0,
      Sesh: 0,
      Chor: 0,
      Pay: 0,
      Jum: 0,
      Shan: 0,
      Yak: 0,
    };

    let totalTasks7 = 0;
    let completedTasks7 = 0;

    try {
      const dailySnap = await db
        .collection("users")
        .doc(uid)
        .collection("daily")
        .where("date", ">=", sevenDaysAgo)
        .get();

      dailySnap.docs.forEach((doc) => {
        const d = doc.data() || {};
        const date = d.date ? d.date.toDate() : null;
        if (date) {
          const dayLabel = daysName[date.getDay()];
          const c = Number(d.completed || 0);
          const t = Number(d.total || 0);
          dailyCompleted[dayLabel] = (dailyCompleted[dayLabel] || 0) + c;
          completedTasks7 += c;
          totalTasks7 += t;
        }
      });
    } catch (err) {
      console.warn("Could not read daily collection:", err);
    }

    // 3. Fetch recent tasks to determine top category
    const categoryCounts = {};
    try {
      const tasksSnap = await db
        .collection("users")
        .doc(uid)
        .collection("tasks")
        .get();

      tasksSnap.docs.forEach((doc) => {
        const t = doc.data() || {};
        const cat = typeof t.category === "string" ? t.category.toLowerCase() : "general";
        categoryCounts[cat] = (categoryCounts[cat] || 0) + 1;
        if (totalTasks7 === 0) {
          totalTasks7++;
          if (t.isCompleted) completedTasks7++;
        }
      });
    } catch (err) {
      console.warn("Could not read tasks collection:", err);
    }

    let topCategory = "Aralash";
    let maxCatCount = 0;
    Object.entries(categoryCounts).forEach(([cat, count]) => {
      if (count > maxCatCount) {
        maxCatCount = count;
        topCategory = cat;
      }
    });

    const completionRatePct = totalTasks7 > 0 ?
      Math.round((completedTasks7 / totalTasks7) * 100) :
      (completedTasks7 > 0 ? 100 : 0);

    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, "0");
    const dd = String(now.getDate()).padStart(2, "0");
    const todayIsoStr = `${yyyy}-${mm}-${dd}`;

    // Build anonymized, aggregated user summary (NO PII like name/phone/email)
    const statsSummary = {
      todayDate: todayIsoStr,
      weeklyPoints,
      streak,
      totalFocusMinutes,
      last7Days: {
        totalTasks: totalTasks7,
        completedTasks: completedTasks7,
        completionRatePercentage: completionRatePct,
        dailyCompleted,
        topCategory,
      },
    };

    const prompt = buildAssistantPrompt(statsSummary, userMessage);

    let rawText;
    try {
      rawText = await callGeminiAssistant(GEMINI_API_KEY.value(), prompt);
    } catch (err) {
      console.error("Gemini request failed in askAiAssistant:", err);
      throw new HttpsError(
        "unavailable",
        "Hozir javob bera olmayapman, birozdan keyin qayta urinib ko'ring.",
      );
    }

    try {
      const parsed = JSON.parse(rawText);
      return {
        type: parsed.type || "analysis",
        reply: parsed.reply || rawText,
        task: parsed.task || null,
      };
    } catch (err) {
      console.error("Failed to parse Gemini assistant JSON response:", rawText);
      return {
        type: "analysis",
        reply: rawText,
        task: null,
      };
    }
  },
);

function buildAssistantPrompt(stats, userMessage) {
  return `
Sen Odat mahsuldorlik ilovasining shaxsiy aqlli yordamchisisan.
Foydalanuvchining so'nggi statistikasi (JSON formatida):
${JSON.stringify(stats, null, 2)}

Foydalanuvchining so'rovi: "${userMessage}"

QOIDALAR:
1. Agar so'rov TAHLIL / STATISTIKA bo'lsa ("natijam qanday", "shu hafta nechta bajarildi", "maslahat ber"):
   - Statistikadan kelib chiqib, o'zbek tilida, xotirjam va ilhomlantiruvchi Zen ohangida javob ber.
   - Muhim raqamlarni qalin (**bold**) va bullet point'lar bilan shakllantir.
   - "type": "analysis", "task": null bo'lsin.

2. Agar so'rov VAZIFA / MAQSAD YARATISH bo'lsa ("sportni qo'shib qo'y", "ertaga soat 15:00 da o'qish qo'sh"):
   - "type": "task_suggestion" bo'lsin.
   - "reply": vazifa taklif qilingani haqida qisqa (1 jumla) samimiy xabar yoz.
   - "task" obyektini tuz:
     - "title": vazifa nomi (O'zbek tilida, e.g. "Sport mashg'uloti")
     - "category": "study" | "sport" | "work" | "personal" | "wellness"
     - "date": YYYY-MM-DD (agar "ertaga" desa bugungi kundan keyingi kun, bo'lmasa bugungi kun: "${stats.todayDate}")
     - "startTime": HH:mm (e.g. "17:00")
     - "durationMinutes": 30 yoki 45 kabi son.

QAYTARILADIGAN JSON STRUKTURASI (FAQAT KELTIRILGAN JSON):
{
  "type": "analysis" | "task_suggestion",
  "reply": "Matnli javob...",
  "task": null | {
    "title": "Vazifa nomi",
    "category": "sport",
    "date": "${stats.todayDate}",
    "startTime": "17:00",
    "durationMinutes": 45
  }
}
`.trim();
}

async function callGeminiAssistant(apiKey, prompt) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: MODEL,
    generationConfig: {
      temperature: 0.5,
      responseMimeType: "application/json",
    },
  });

  const result = await model.generateContent(prompt);
  const response = await result.response;
  const text = response.text();
  if (typeof text !== "string" || !text.trim()) {
    throw new Error("Gemini returned no text content.");
  }
  return text;
}

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
    "You are Odat, a calm productivity planner.",
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
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: MODEL,
    generationConfig: {
      temperature: 0.7,
      responseMimeType: "application/json",
      responseSchema: {
        type: "ARRAY",
        items: {
          type: "OBJECT",
          properties: {
            title: { type: "STRING" },
            category: { type: "STRING", enum: ALLOWED_CATEGORIES },
            date: { type: "STRING" },
            startTime: { type: "STRING" },
            durationMinutes: { type: "INTEGER" },
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
  });

  const result = await model.generateContent(prompt);
  const response = await result.response;
  const text = response.text();
  if (typeof text !== "string" || !text.trim()) {
    throw new Error("Gemini returned no text content.");
  }
  return text;
}

function buildDailyPlanPrompt({userId, userPreferences, userGoals, currentDayOfWeek}) {
  return [
    "You are Odat, an intelligent daily task planner.",
    `Current Day: ${currentDayOfWeek}`,
    `User Preferences: ${JSON.stringify(userPreferences)}`,
    `User Goals: ${JSON.stringify(userGoals)}`,
    "",
    "Rules:",
    "- Create a balanced daily plan of tasks serving the user's goals.",
    "- Each task must have: title, category (one of: study, sport, work, personal, wellness), startTime (HH:mm), durationMinutes (number).",
    "Return ONLY a JSON array of task objects.",
  ].join("\n");
}

async function callGeminiForDailyPlan(apiKey, prompt) {
  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: MODEL,
    generationConfig: {
      temperature: 0.7,
      responseMimeType: "application/json",
    },
  });

  const result = await model.generateContent(prompt);
  const response = await result.response;
  const text = response.text();
  if (typeof text !== "string" || !text.trim()) {
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
const _getTelegramBotToken = () => {
  return "8855349705:AAGMa9cMyo62Fh8gThoC1xtuRyQwnwu6N4U";
};

// ---------------------------------------------------------------------------
// BOSQICH A — linkTelegramChatId

export const linkTelegramChatId = onRequest(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const update = req.body;
    console.log("Telegram webhook received update:", JSON.stringify(update));
    const message = update?.message;
    if (!message) {
      res.status(200).send("ok");
      return;
    }

    const text = (message.text ?? "").trim();
    const chatId = String(message.chat?.id ?? "");
    const fromId = String(message.from?.id ?? chatId);
    const chatType = message.chat?.type || "private";
    const botToken = _getTelegramBotToken();

    console.log(`Telegram message fromId=${fromId}, chatId=${chatId}, chatType=${chatType}, text="${text}"`);

    // ── 1. GURUH NAZORATI VA SALOMLASHISH (Group Moderation) ─────────────────
    if (chatType === "group" || chatType === "supergroup") {
      // 1.1 Yangi a'zo kutib olish
      if (message.new_chat_members && message.new_chat_members.length > 0) {
        for (const member of message.new_chat_members) {
          if (member.is_bot && member.id === 8855349705) {
            await sendTelegramMessage(
              botToken,
              chatId,
              "👋 <b>Assalomu alaykum!</b>\nMen guruh xavfsizligini ta'minlovchi va yangi a'zolarni kutib oluvchi ODAT rasmiy botiman. Guruhda faqat rasm va do'stona xabarlar yozish mumkin. Reklama va havolalar avtomatik o'chiriladi. 🌿",
            );
            continue;
          }
          if (member.is_bot) continue;

          const name = member.first_name || member.username || "do'stimiz";
          await sendTelegramMessage(
            botToken,
            chatId,
            `🎉 <b>Xush kelibsiz, ${name}!</b>\n\n` +
            `🌿 <b>ODAT / Flowa</b> hamjamiyatiga xush kelibsiz!\n` +
            `Bu yerda biz intizom, sport, kitob mutolaasi va foydali odatlarni rivojlantiramiz. 🚀\n\n` +
            `📌 <b>Guruh qoidalari:</b>\n` +
            `• Reklama, begona havolalar (linklar) va kanal forwardlari qat'iyan taqiqlangan.\n` +
            `• Guruhda faqat oddiy xabarlar va bajarilgan vazifalarning isbot rasmlari qabul qilinadi. 🌿`,
          );
        }
        res.status(200).send("ok");
        return;
      }

      // 1.2 Reklama, havolalar, forward va haqoratli so'zlarni filtr qilish
      const senderIsAdmin = await isTelegramUserAdmin(db, fromId);
      if (!senderIsAdmin) {
        const fullContent = (message.text || message.caption || "").trim();
        const lowerText = fullContent.toLowerCase();

        const badPatterns = [
          /https?:\/\//i,
          /t\.me\//i,
          /telegram\.me\//i,
          /@[\w_]{4,}/i,
          /rek[\s_]*lama/i,
          /kanalga\s+obuna/i,
          /pul\s+ishlash/i,
          /garant/i,
          /suka|blya|am|qotoq|sikish|dalbayob|chmo|harom|jalap|pidar/i,
        ];

        const hasBadPattern = badPatterns.some((pattern) => pattern.test(fullContent));
        const entities = [...(message.entities || []), ...(message.caption_entities || [])];
        const hasLinkEntity = entities.some((e) => ["url", "text_link", "mention"].includes(e.type));
        const isForwarded = Boolean(message.forward_from_chat || message.forward_from);

        if (hasBadPattern || hasLinkEntity || isForwarded) {
          try {
            await fetch(`https://api.telegram.org/bot${botToken}/deleteMessage`, {
              method: "POST",
              headers: {"Content-Type": "application/json"},
              body: JSON.stringify({chat_id: chatId, message_id: message.message_id}),
            });
          } catch (_) {}

          const userName = message.from?.username ? `@${message.from.username}` : (message.from?.first_name || "Foydalanuvchi");
          let warnReason = "reklama va begona havolalar";
          if (isForwarded) warnReason = "kanallardan xabar ulashish (forward)";
          
          await sendTelegramMessage(
            botToken,
            chatId,
            `⚠️ <b>Ogohlantirish!</b> ${userName}, guruhda ${warnReason} taqiqlanadi!\nFaqat oddiy xabarlar va mashg'ulot isboti (rasmlar) yuborishingiz mumkin. 🌿`,
          );
          res.status(200).send("ok");
          return;
        }
      }

      res.status(200).send("ok");
      return;
    }

    // ── 2. ADMIN ISHLARI (Admin Commands & Panel) ────────────────────────────
    const isAdmin = await isTelegramUserAdmin(db, fromId);

    // Agar admin /start yoki /admin yoki /stats yuborsa:
    if (isAdmin && (text === "/start" || text === "/admin" || text === "/stats" || text === "/menu")) {
      let usersCount = 0;
      let clansCount = 0;
      let booksCount = 0;
      let shopCount = 0;

      try {
        const uSnap = await db.collection("users").count().get();
        usersCount = uSnap.data().count;
      } catch (_) {
        const uSnap = await db.collection("users").limit(100).get();
        usersCount = uSnap.size;
      }

      try {
        const cSnap = await db.collection("clans").count().get();
        clansCount = cSnap.data().count;
      } catch (_) {
        const cSnap = await db.collection("clans").limit(50).get();
        clansCount = cSnap.size;
      }

      try {
        const bSnap = await db.collection("books").count().get();
        booksCount = bSnap.data().count;
      } catch (_) {
        const bSnap = await db.collection("books").limit(50).get();
        booksCount = bSnap.size;
      }

      try {
        const sSnap = await db.collection("shopItems").count().get();
        shopCount = sSnap.data().count;
      } catch (_) {
        const sSnap = await db.collection("shopItems").limit(50).get();
        shopCount = sSnap.size;
      }

      const adminDashboard =
        `👑 <b>ASSALOMU ALAYKUM, BOSHQARUVCHI (ADMIN)!</b>\n\n` +
        `📊 <b>Real-Vaqt Tizim Statistikasi:</b>\n` +
        `👥 Jami foydalanuvchilar: <b>${usersCount} ta</b>\n` +
        `🏰 Faol Klanlar: <b>${clansCount} ta</b>\n` +
        `📚 Kutubxona kitoblari: <b>${booksCount} ta</b>\n` +
        `🛍️ Do'kondagi mahsulotlar: <b>${shopCount} ta</b>\n\n` +
        `⚡ <b>BUYRUQLAR ORQALI QO'SHISH:</b>\n\n` +
        `📖 <b>Kitob qo'shish:</b>\n<code>/addbook Nomi | Muallif | Betlar | PTS | RasmURL</code>\n\n` +
        `🎵 <b>Musiqa/Audio qo'shish:</b>\n<code>/addmusic Nomi | Janr | AudioURL | PTS</code>\n\n` +
        `🎁 <b>Do'konga mahsulot qo'shish:</b>\n<code>/addshop Nomi | coupon/gift | PTS | Soni | Tavsif</code>\n\n` +
        `📈 <b>Statistikani yangilash:</b> /stats`;

      await sendTelegramMessage(botToken, chatId, adminDashboard);
      res.status(200).send("ok");
      return;
    }

    // Admin kitob qo'shish (/addbook)
    if (isAdmin && text.startsWith("/addbook")) {
      const payload = text.replace("/addbook", "").trim();
      const parts = payload.split("|").map((p) => p.trim());
      if (parts.length < 4) {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ <b>Format xato!</b>\nNamuna:\n<code>/addbook Atom Odatlar | Jeyms Klir | 320 | 150 | https://example.com/cover.jpg</code>",
        );
        res.status(200).send("ok");
        return;
      }

      const [title, author, pagesStr, ptsStr, coverUrl] = parts;
      const pages = parseInt(pagesStr, 10) || 100;
      const pts = parseInt(ptsStr, 10) || 100;

      const docRef = await db.collection("books").add({
        title,
        author,
        pages,
        ptsReward: pts,
        coverUrl: coverUrl || "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c",
        createdAt: FieldValue.serverTimestamp(),
        createdBy: fromId,
      });

      await sendTelegramMessage(
        botToken,
        chatId,
        `✅ <b>Kitob muvaffaqiyatli qo'shildi!</b>\n\n📚 Nomi: <b>${title}</b>\n✍️ Muallif: <b>${author}</b>\n📄 Betlar: ${pages}\n⚡ Mukofot: +${pts} PTS\n🆔 ID: <code>${docRef.id}</code>`,
      );
      res.status(200).send("ok");
      return;
    }

    // Admin musiqa fayli yuborganida (MP3 / Audio / Voice / Document)
    const audioObj = message.audio || message.voice || (message.document && message.document.mime_type?.startsWith("audio/") ? message.document : null);
    if (isAdmin && audioObj) {
      try {
        const fileId = audioObj.file_id;
        const rawFileName = audioObj.file_name || message.caption || `track_${Date.now()}.mp3`;
        const title = audioObj.title || message.caption || rawFileName.replace(/\.[a-zA-Z0-9]+$/, "");
        const artist = audioObj.performer || "ODAT / Flowa";
        const duration = audioObj.duration || 180;

        await sendTelegramMessage(botToken, chatId, "⏳ <b>Musiqa serverga yuklanmoqda...</b> Iltimos kuting.");

        // 1. Get file path from Telegram
        const fileRes = await fetch(`https://api.telegram.org/bot${botToken}/getFile?file_id=${fileId}`);
        const fileData = await fileRes.json();

        if (!fileData.ok || !fileData.result?.file_path) {
          throw new Error("Telegramdan fayl manzilini olib bo'lmadi.");
        }

        const telegramFilePath = fileData.result.file_path;
        const downloadUrl = `https://api.telegram.org/file/bot${botToken}/${telegramFilePath}`;

        // 2. Download audio buffer
        const audioFetch = await fetch(downloadUrl);
        const audioBuffer = Buffer.from(await audioFetch.arrayBuffer());

        // 3. Upload to Firebase Storage
        const safeFileName = rawFileName.replace(/[^a-zA-Z0-9._-]/g, "_");
        const storagePath = `music/music_${Date.now()}_${safeFileName}`;
        let audioUrl = "";

        const candidateBuckets = [
          "flowa-4fca9.firebasestorage.app",
          "flowa-4fca9.appspot.com",
        ];

        for (const bName of candidateBuckets) {
          try {
            const bucket = getStorage().bucket(bName);
            const file = bucket.file(storagePath);
            await file.save(audioBuffer, {
              metadata: {
                contentType: audioObj.mime_type || "audio/mpeg",
                cacheControl: "public, max-age=31536000",
              },
            });
            try { await file.makePublic(); } catch (_) {}
            audioUrl = `https://storage.googleapis.com/${bName}/${storagePath}`;
            break;
          } catch (bErr) {
            console.warn(`Telegram audio bucket ${bName} failed:`, bErr.message);
          }
        }

        if (!audioUrl) {
          audioUrl = downloadUrl;
        }

        // 4. Save to music_tracks collection
        const trackDoc = await db.collection("music_tracks").add({
          title,
          artist,
          audioUrl,
          category: "study",
          genre: "Focus",
          duration,
          ptsCost: 0,
          isActive: true,
          createdAt: FieldValue.serverTimestamp(),
          createdBy: fromId,
        });

        await sendTelegramMessage(
          botToken,
          chatId,
          `✅ <b>Musiqa muvaffaqiyatli yuklandi va ilovaga qo'shildi!</b>\n\n` +
          `🎵 Nomi: <b>${title}</b>\n` +
          `👤 Ijrochi: <b>${artist}</b>\n` +
          `⏱️ Davomiyligi: ${Math.floor(duration / 60)}:${String(duration % 60).padStart(2, "0")}\n` +
          `📁 Bo'lim: <b>Focus / Study</b>\n` +
          `🆔 ID: <code>${trackDoc.id}</code>\n\n` +
          `📱 <i>Foydalanuvchilar ilovani ochib darhol eshitishlari mumkin!</i>`,
        );
        res.status(200).send("ok");
        return;
      } catch (err) {
        console.error("Telegram music upload error:", err.message);
        await sendTelegramMessage(
          botToken,
          chatId,
          `❌ <b>Musiqa yuklashda xatolik yuz berdi:</b> ${err.message}`,
        );
        res.status(200).send("ok");
        return;
      }
    }

    // Admin musiqa qo'shish (/addmusic)
    if (isAdmin && text.startsWith("/addmusic")) {
      const payload = text.replace("/addmusic", "").trim();
      const parts = payload.split("|").map((p) => p.trim());
      if (parts.length < 3) {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ <b>Format xato!</b>\nNamuna:\n<code>/addmusic Chuqur Fokus & Tabiat | Focus Ambient | https://example.com/track.mp3 | 50</code>",
        );
        res.status(200).send("ok");
        return;
      }

      const [title, genre, audioUrl, ptsStr] = parts;
      const pts = parseInt(ptsStr, 10) || 0;

      const categoryMap = {
        "Focus": "study",
        "Focus Ambient": "study",
        "Workout": "workout",
        "Gaming": "gaming",
        "Zen": "zen",
        "Motivation": "motivation",
        "Nasheed": "nasheed",
      };
      const category = categoryMap[genre] || "study";

      const docRef = await db.collection("music_tracks").add({
        title,
        artist: "ODAT / Flowa",
        genre: genre || "Focus",
        category,
        audioUrl,
        ptsCost: pts,
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: fromId,
      });

      await sendTelegramMessage(
        botToken,
        chatId,
        `✅ <b>Musiqa muvaffaqiyatli qo'shildi!</b>\n\n🎵 Nomi: <b>${title}</b>\n🏷️ Janr: <b>${genre}</b>\n📂 Kategoriya: <b>${category}</b>\n⚡ Narx: ${pts} PTS\n🆔 ID: <code>${docRef.id}</code>`,
      );
      res.status(200).send("ok");
      return;
    }

    // Admin do'konga mahsulot qo'shish (/addshop)
    if (isAdmin && text.startsWith("/addshop")) {
      const payload = text.replace("/addshop", "").trim();
      const parts = payload.split("|").map((p) => p.trim());
      if (parts.length < 5) {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ <b>Format xato!</b>\nNamuna:\n<code>/addshop Asaxiy 50,000 so'm | coupon | 1200 | 10 | Asaxiy.uz da barcha kitoblar uchun chegirma kuponi</code>",
        );
        res.status(200).send("ok");
        return;
      }

      const [title, type, ptsStr, stockStr, desc] = parts;
      const pts = parseInt(ptsStr, 10) || 500;
      const stock = parseInt(stockStr, 10) || 10;

      const docRef = await db.collection("shopItems").add({
        title,
        type: type.toLowerCase().includes("gift") ? "gift" : "coupon",
        pointsCost: pts,
        stock,
        description: desc,
        isActive: true,
        createdAt: FieldValue.serverTimestamp(),
        createdBy: fromId,
      });

      await sendTelegramMessage(
        botToken,
        chatId,
        `✅ <b>Do'kon mahsuloti muvaffaqiyatli qo'shildi!</b>\n\n🛍️ Nomi: <b>${title}</b>\n⚡ Narx: <b>${pts} PTS</b>\n📦 Qoldiq: ${stock} ta\n🆔 ID: <code>${docRef.id}</code>`,
      );
      res.status(200).send("ok");
      return;
    }

    // ── 3. TELEFON RAQAM QABUL QILISH (Contact Sharing Login & Registration) ──
    if (message.contact) {
      const contact = message.contact;
      const rawPhone = String(contact.phone_number || "").trim();
      if (!rawPhone) {
        res.status(200).send("ok");
        return;
      }

      // Format phone e.g. +998XXXXXXXXX
      const cleanPhone = rawPhone.replace(/\s+|-|\(|\)/g, "");
      const formattedPhone = cleanPhone.startsWith("+")
        ? cleanPhone
        : (cleanPhone.startsWith("998") ? `+${cleanPhone}` : `+998${cleanPhone}`);

      console.log(`Received contact phone: ${formattedPhone} fromId=${fromId}`);

      // Retrieve pending loginToken for this Telegram user
      const tgUserRef = db.collection("telegramUsers").doc(fromId);
      const tgUserSnap = await tgUserRef.get();
      const loginToken = tgUserSnap.data()?.pendingLoginToken;

      let targetUid = null;
      let isNewUser = false;

      // 1. Search user by phoneNumber in Firestore
      const userByPhoneSnap = await db
        .collection("users")
        .where("phoneNumber", "==", formattedPhone)
        .limit(1)
        .get();

      if (!userByPhoneSnap.empty) {
        targetUid = userByPhoneSnap.docs[0].id;
        await db.collection("users").doc(targetUid).set({
          phoneNumber: formattedPhone,
          phone: formattedPhone,
          telegramId: fromId,
          telegramChatId: chatId,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
      } else {
        const userByPhoneSnap2 = await db
          .collection("users")
          .where("phone", "==", formattedPhone)
          .limit(1)
          .get();

        if (!userByPhoneSnap2.empty) {
          targetUid = userByPhoneSnap2.docs[0].id;
          await db.collection("users").doc(targetUid).set({
            phoneNumber: formattedPhone,
            phone: formattedPhone,
            telegramId: fromId,
            telegramChatId: chatId,
            updatedAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        } else {
          // 2. Create a NEW user profile specifically tied to this phone number!
          isNewUser = true;
          const firstName = contact.first_name || message.from?.first_name || "Foydalanuvchi";
          const lastName = contact.last_name || message.from?.last_name || "";
          const fullName = `${firstName} ${lastName}`.trim() || "Foydalanuvchi";

          try {
            const userRecord = await getAuth().createUser({
              displayName: fullName,
              phoneNumber: formattedPhone,
            });
            targetUid = userRecord.uid;
          } catch (e) {
            targetUid = `phone_${formattedPhone.replace(/\+/g, "")}`;
          }

          const now = new Date();
          const yyyy = now.getFullYear();
          const startOfYear = new Date(yyyy, 0, 1);
          const weekNum = Math.ceil((((now.getTime() - startOfYear.getTime()) / 86400000) + startOfYear.getDay() + 1) / 7);
          const weekId = `${yyyy}-W${String(weekNum).padStart(2, "0")}`;

          await db.collection("users").doc(targetUid).set({
            name: fullName,
            phoneNumber: formattedPhone,
            phone: formattedPhone,
            telegramId: fromId,
            telegramChatId: chatId,
            avatar: "leaf",
            focusType: "Study",
            streak: 0,
            longestStreak: 0,
            totalPoints: 0,
            weeklyPoints: 0,
            weeklyFocusMinutes: 0,
            totalFocusMinutes: 0,
            currentWeekId: weekId,
            totalDeepSessions: 0,
            freezes: 1,
            earnedBadges: [],
            isPremium: false,
            createdAt: FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      }

      // Generate Firebase Auth Custom Token
      const customToken = await getAuth().createCustomToken(targetUid);

      // Approve loginRequest if token exists
      if (loginToken) {
        const reqRef = db.collection("loginRequests").doc(loginToken);
        const reqDoc = await reqRef.get();
        if (reqDoc.exists && reqDoc.data()?.status === "pending") {
          await reqRef.update({
            status: "approved",
            uid: targetUid,
            customToken: customToken,
            phoneNumber: formattedPhone,
            telegramId: fromId,
            chatId: chatId,
            isNewUser: isNewUser,
            approvedAt: FieldValue.serverTimestamp(),
          });
          await tgUserRef.set({ pendingLoginToken: null }, { merge: true });
        }
      }

      // Send confirmation and remove custom keyboard
      const successMsg =
        `✅ <b>Telefon raqamingiz muvaffaqiyatli tasdiqlandi!</b> (${formattedPhone})\n\n` +
        `Odat ilovasiga xush kelibsiz! Ilovaga qaytishingiz mumkin, tizimga avtomatik kirilmoqda... 🌿`;

      await sendTelegramMessageWithRemoveKeyboard(botToken, chatId, successMsg);
      res.status(200).send("ok");
      return;
    }

    // Deep link token login check: /start login_<token> or /login login_<token> or login_<token>
    let loginToken = null;
    if (text.startsWith("/start login_")) {
      loginToken = text.replace("/start login_", "").trim();
    } else if (text.startsWith("/start ") && text.includes("login_")) {
      const parts = text.split(" ");
      loginToken = (parts[1] || "").replace("login_", "").trim();
    } else if (text.startsWith("login_")) {
      loginToken = text.replace("login_", "").trim();
    }

    if (loginToken) {
      console.log(`Processing automatic login request for token: ${loginToken}...`);
      const reqRef = db.collection("loginRequests").doc(loginToken);
      const reqDoc = await reqRef.get();

      if (!reqDoc.exists) {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ <b>Kirish so'rovi topilmadi.</b>\n\nIltimos, Odat ilovasiga qaytib, qayta urinib ko'ring. 🌿",
        );
        res.status(200).send("ok");
        return;
      }

      const reqData = reqDoc.data() || {};
      if (reqData.status !== "pending") {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ <b>Bu kirish so'rovi allaqachon ishlatilgan yoki bekor qilingan.</b> 🌿",
        );
        res.status(200).send("ok");
        return;
      }

      if (Date.now() > (reqData.expiresAt || 0)) {
        await reqRef.update({ status: "expired" });
        await sendTelegramMessage(
          botToken,
          chatId,
          "⏰ <b>Kirish so'rovi vaqti tugagan (5 daqiqa).</b>\n\nIlovadan yangi so'rov yuboring. 🌿",
        );
        res.status(200).send("ok");
        return;
      }

      // Save pending token for this user so when they tap "Share Contact", it links to this login session
      await db.collection("telegramUsers").doc(fromId).set({
        pendingLoginToken: loginToken,
        chatId: chatId,
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      // Request contact / phone number
      await sendTelegramPhoneRequest(
        botToken,
        chatId,
        "👋 <b>Assalomu alaykum!</b>\n\n" +
        "Odat ilovasiga kirish yoki yangi hisob yaratish uchun pastdagi <b>«📱 Telefon raqamimni yuborish»</b> tugmasini bosing 👇",
        "📱 Telefon raqamimni yuborish"
      );

      res.status(200).send("ok");
      return;
    }

    const isLoginCommand = text === "/login" || text.startsWith("/login") || text === "/code" || text === "/start";
    const parts = text.split(" ");
    const uid = parts[1]?.trim() ?? "";

    try {
      if (isLoginCommand && !uid) {
        const code = Math.floor(100000 + Math.random() * 900000).toString();
        const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

        await db.collection("telegramAuthCodes").doc(code).set({
          code,
          telegramId: fromId,
          chatId: chatId,
          createdAt: Date.now(),
          expiresAt,
          attempts: 0,
          used: false,
        });

        await sendTelegramMessage(
          botToken,
          chatId,
          `🔑 <b>Odat ilovasiga kirish kodingiz:</b> <code>${code}</code>\n\n` +
          `⏰ Bu kod <b>5 daqiqa</b> davomida amal qiladi.\n` +
          `Ushbu kodni Odat ilovasidagi Telegram kirish oynasiga kiritib tizimga kiring. 🌿`,
        );
        res.status(200).send("ok");
        return;
      }

      if (!uid) {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ Kod topilmadi. Iltimos, Odat ilovasidan to'liq kodni nusxalab yuboring.",
        );
        res.status(200).send("ok");
        return;
      }

      // UID mavjudligini tekshiramiz
      const userDoc = await db.collection("users").doc(uid).get();
      if (!userDoc.exists) {
        await sendTelegramMessage(
          botToken,
          chatId,
          "❌ Foydalanuvchi topilmadi. Iltimos, kod to'g'riligini tekshiring.",
        );
        res.status(200).send("ok");
        return;
      }

      // chat_id ni saqlaymiz
      await db.collection("users").doc(uid).update({telegramChatId: chatId});

      const name = userDoc.data()?.name ?? "Foydalanuvchi";
      await sendTelegramMessage(
        botToken,
        chatId,
        `✅ Muvaffaqiyatli ulandi, ${name}!\n\n` +
        "Endi do'stlaringiz isbot yuborganida yoki o'tkazib yuborganida " +
        "bu yerda xabar olasiz. 🌿",
      );

      res.status(200).send("ok");
    } catch (err) {
      console.error("linkTelegramChatId error:", err);
      res.status(200).send("ok");
    }
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

    // Get mood response emoji
    let moodEmoji = "😊 (Ha, ajoyib)";
    const mood = after.moodResponse;
    if (mood === 'great') moodEmoji = "😊 (Ha, ajoyib)";
    else if (mood === 'hard') moodEmoji = "😐 (Ha, lekin qiyin bo'ldi)";
    else if (mood === 'missed') moodEmoji = "😔 (Yo'q, chalg'idim)";

    // Xabar matni
    const message = newStatus === "completed"
      ? `✅ ${userName} "${taskTitle}" vazifasini ${moodEmoji} bilan belgiladi.`
      : `😅 ${userName} bugungi "${taskTitle}" vazifasini o'tkazib yubordi.`;

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
  },
  async () => {
    console.log("cleanupExpiredProofs: No-op because storage proofs are disabled.");
  },
);

export const cleanupExpiredLoginRequests = onSchedule(
  {
    schedule: "every 1 hours",
    timeZone: "Etc/UTC",
  },
  async () => {
    const now = Date.now();
    const snap = await db.collection("loginRequests")
      .where("expiresAt", "<", now)
      .limit(100)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    console.log(`Cleaned up ${snap.size} expired login requests.`);
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

async function sendTelegramPhoneRequest(token, chatId, text, buttonText) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
      reply_markup: {
        keyboard: [
          [
            {
              text: buttonText,
              request_contact: true,
            },
          ],
        ],
        resize_keyboard: true,
        one_time_keyboard: true,
      },
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Telegram API ${res.status}: ${detail}`);
  }
  return res.json();
}

async function sendTelegramMessageWithRemoveKeyboard(token, chatId, text) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
      reply_markup: {
        remove_keyboard: true,
      },
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Telegram API ${res.status}: ${detail}`);
  }
  return res.json();
}

async function sendTelegramMessageWithWebAppButtons(token, chatId, text, buttons) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
      reply_markup: {
        inline_keyboard: buttons,
      },
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Telegram API ${res.status}: ${detail}`);
  }
  return res.json();
}

async function sendTelegramMessageWithWebAppButton(token, chatId, text, buttonText, webAppUrl) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
      reply_markup: {
        inline_keyboard: [
          [
            {
              text: buttonText,
              web_app: { url: webAppUrl },
            },
          ],
        ],
      },
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Telegram API ${res.status}: ${detail}`);
  }
  return res.json();
}

// ============================================================================
// DO'KON (SHOP) FEATURE — Kupon sotib olish va Sovg'a buyurtma berish
// ============================================================================

/**
 * Kupon sotib olish uchun Cloud Function (Atomic Transaction).
 * Ochkolarni kamaytiradi, stokni yangilaydi va purchasedCoupons ga yozadi.
 */
export const purchaseCoupon = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Avtorizatsiyadan o'ting.");
  }

  const uid = request.auth.uid;
  const data = request.data ?? {};
  const shopItemId = typeof data.shopItemId === "string" ? data.shopItemId.trim() : "";

  if (!shopItemId) {
    throw new HttpsError("invalid-argument", "Shop item ID kiritilmadi.");
  }

  return await db.runTransaction(async (transaction) => {
    const itemRef = db.collection("shopItems").doc(shopItemId);
    const itemDoc = await transaction.get(itemRef);

    if (!itemDoc.exists) {
      throw new HttpsError("not-found", "Mahsulot topilmadi.");
    }

    const itemData = itemDoc.data();
    if (!itemData.isActive) {
      throw new HttpsError("failed-precondition", "Ushbu mahsulot hozirda nofaol.");
    }

    if (itemData.type !== "coupon") {
      throw new HttpsError("invalid-argument", "Tanlangan mahsulot kupon emas.");
    }

    if (itemData.stock !== null && itemData.stock !== undefined && itemData.stock <= 0) {
      throw new HttpsError("failed-precondition", "Ushbu kupon zaxirada tugagan.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await transaction.get(userRef);

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Foydalanuvchi profili topilmadi.");
    }

    const userData = userDoc.data();
    const currentPoints = Number(userData.totalPoints ?? 0);
    const pointsCost = Number(itemData.pointsCost ?? 0);

    if (currentPoints < pointsCost) {
      throw new HttpsError(
        "failed-precondition",
        `Xarid qilish uchun ochkolaringiz yetarli emas. Talab qilinadi: ${pointsCost}, sizda: ${currentPoints}`,
      );
    }

    // Promo kod yaratamiz (e.g., FLOWA-XXXX-XXXX)
    const randomCode = Math.random().toString(36).substring(2, 6).toUpperCase() + "-" +
                       Math.random().toString(36).substring(2, 6).toUpperCase();
    const couponCode = `FLOWA-${randomCode}`;

    // Ochkoni ayiramiz
    transaction.update(userRef, {
      totalPoints: FieldValue.increment(-pointsCost),
    });

    // Stok mavjud bo'lsa kamaytiramiz
    if (itemData.stock !== null && itemData.stock !== undefined) {
      transaction.update(itemRef, {
        stock: FieldValue.increment(-1),
      });
    }

    // purchasedCoupons ga yozuv qo'shamiz
    const couponRef = db.collection("purchasedCoupons").doc();
    transaction.set(couponRef, {
      userId: uid,
      shopItemId: shopItemId,
      couponCode: couponCode,
      purchasedAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      couponCode: couponCode,
      pointsCost: pointsCost,
      remainingPoints: currentPoints - pointsCost,
    };
  });
});

/**
 * Sovg'a buyurtma berish uchun Cloud Function (Atomic Transaction).
 * Formadagi ism, telefon va manzilni tekshiradi, ochkolarni ayiradi,
 * stokni kamaytiradi hamda giftOrders ga yozadi.
 */
export const purchaseGift = onCall(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Avtorizatsiyadan o'ting.");
  }

  const uid = request.auth.uid;
  const data = request.data ?? {};
  const shopItemId = typeof data.shopItemId === "string" ? data.shopItemId.trim() : "";
  const fullName = typeof data.fullName === "string" ? data.fullName.trim() : "";
  const phoneNumber = typeof data.phoneNumber === "string" ? data.phoneNumber.trim() : "";
  const address = typeof data.address === "string" ? data.address.trim() : "";

  // Server-side validations
  if (!shopItemId) {
    throw new HttpsError("invalid-argument", "Mahsulot tanlanmadi.");
  }

  if (fullName.length < 2) {
    throw new HttpsError("invalid-argument", "Iltimos, to'liq ismingizni kiriting.");
  }

  // Uzbek phone format validation
  const cleanPhone = phoneNumber.replace(/\s+|-|\(|\)/g, "");
  const phoneRegex = /^(\+?998)?\d{9}$/;
  if (!phoneRegex.test(cleanPhone)) {
    throw new HttpsError(
      "invalid-argument",
      "Iltimos, O'zbekiston telefon raqamini to'g'ri kiriting (+998XXXXXXXXX).",
    );
  }

  if (address.length < 5) {
    throw new HttpsError(
      "invalid-argument",
      "Iltimos, yetkazib berish manzilini to'liq kiriting (kamida 5 ta belgi).",
    );
  }

  return await db.runTransaction(async (transaction) => {
    const itemRef = db.collection("shopItems").doc(shopItemId);
    const itemDoc = await transaction.get(itemRef);

    if (!itemDoc.exists) {
      throw new HttpsError("not-found", "Tanlangan mahsulot topilmadi.");
    }

    const itemData = itemDoc.data() || {};
    if (itemData.isActive === false) {
      throw new HttpsError("failed-precondition", "Ushbu mahsulot hozirda nofaol.");
    }

    if (itemData.type === "coupon") {
      throw new HttpsError("invalid-argument", "Bu mahsulot kupon turida. Kuponlar bo'limidan xarid qiling.");
    }

    if (itemData.stock !== null && itemData.stock !== undefined && Number(itemData.stock) <= 0) {
      throw new HttpsError("failed-precondition", "Ushbu sovg'a zaxirada tugagan.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await transaction.get(userRef);

    if (!userDoc.exists) {
      throw new HttpsError("not-found", "Foydalanuvchi profili topilmadi.");
    }

    const userData = userDoc.data() || {};
    const currentPoints = Number(userData.totalPoints ?? userData.points ?? userData.pts ?? 0);
    const pointsCost = Math.max(0, Number(itemData.pointsCost ?? 0));

    if (currentPoints < pointsCost) {
      throw new HttpsError(
        "failed-precondition",
        `Buyurtma berish uchun ochkolaringiz yetarli emas. Talab qilinadi: ${pointsCost} PTS, sizda: ${currentPoints} PTS`,
      );
    }

    // Ochkoni xavfsiz ayiramiz (set with merge)
    transaction.set(
      userRef,
      {
        totalPoints: FieldValue.increment(-pointsCost),
        weeklyPoints: FieldValue.increment(-pointsCost),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Stok mavjud bo'lsa kamaytiramiz
    if (itemData.stock !== null && itemData.stock !== undefined && Number(itemData.stock) > 0) {
      transaction.update(itemRef, {
        stock: FieldValue.increment(-1),
      });
    }

    // giftOrders ga yangi buyurtma qo'shamiz
    const orderRef = db.collection("giftOrders").doc();
    const formattedPhone = cleanPhone.startsWith("+")
      ? cleanPhone
      : (cleanPhone.startsWith("998") ? `+${cleanPhone}` : `+998${cleanPhone}`);

    transaction.set(orderRef, {
      userId: uid,
      shopItemId: shopItemId,
      itemTitle: itemData.title || "Sovg'a",
      itemImageUrl: itemData.imageUrl || "",
      pointsCost: pointsCost,
      fullName: fullName,
      phoneNumber: formattedPhone,
      address: address,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      orderId: orderRef.id,
      pointsCost: pointsCost,
      remainingPoints: currentPoints - pointsCost,
    };
  });
});


// ============================================================================
// TELEGRAM MINI-APP ADMIN PANEL CLOUD FUNCTIONS
// ============================================================================

// 1. adminCheckAuth
export const adminCheckAuth = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    const customToken = await getAuth().createCustomToken(adminUser.id.toString());

    return {
      success: true,
      user: {
        id: adminUser.id,
        first_name: adminUser.first_name,
        username: adminUser.username,
      },
      customToken,
    };
  },
);

// 2. adminListShopItems
export const adminListShopItems = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    await assertAdminAuth(db, initData, botToken);

    const snapshot = await db.collection("shopItems").get();
    const items = snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    }));

    return { success: true, items };
  },
);

// 3. adminCreateShopItem
export const adminCreateShopItem = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const itemData = request.data?.shopItem;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    if (!itemData || !itemData.title || !itemData.type) {
      throw new HttpsError("invalid-argument", "Mahsulot sarlavhasi va turi bo'lishi shart.");
    }

    if (!["coupon", "gift"].includes(itemData.type)) {
      throw new HttpsError("invalid-argument", "Turi faqat 'coupon' yoki 'gift' bo'lishi mumkin.");
    }

    const docRef = db.collection("shopItems").doc();
    const newItem = {
      type: itemData.type,
      title: String(itemData.title).trim(),
      description: String(itemData.description || "").trim(),
      partnerName: itemData.partnerName ? String(itemData.partnerName).trim() : null,
      pointsCost: Math.max(0, parseInt(itemData.pointsCost || 0, 10)),
      imageUrl: String(itemData.imageUrl || "").trim(),
      stock: itemData.stock !== null && itemData.stock !== undefined && itemData.stock !== "" ? Math.max(0, parseInt(itemData.stock, 10)) : null,
      expiresAt: itemData.expiresAt || null,
      isActive: itemData.isActive !== false,
      discountText: itemData.discountText ? String(itemData.discountText).trim() : null,
      requiresShipping: itemData.type === "gift" ? true : false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      createdById: String(adminUser.id),
    };

    await docRef.set(newItem);

    // Audit log
    await db.collection("auditLogs").add({
      action: "create_shop_item",
      itemId: docRef.id,
      adminTelegramId: String(adminUser.id),
      timestamp: FieldValue.serverTimestamp(),
      details: { title: newItem.title, type: newItem.type },
    });

    return { success: true, id: docRef.id };
  },
);

// 4. adminUpdateShopItem
export const adminUpdateShopItem = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const itemId = request.data?.itemId;
    const itemData = request.data?.shopItem;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    if (!itemId || !itemData) {
      throw new HttpsError("invalid-argument", "itemId va shopItem taqdim etilishi kerak.");
    }

    const docRef = db.collection("shopItems").doc(itemId);
    const existing = await docRef.get();
    if (!existing.exists) {
      throw new HttpsError("not-found", "Mahsulot topilmadi.");
    }

    const updates = {
      ...itemData,
      updatedAt: FieldValue.serverTimestamp(),
      lastModifiedBy: String(adminUser.id),
      lastModifiedAt: FieldValue.serverTimestamp(),
    };

    delete updates.id;
    delete updates.createdAt;

    await docRef.update(updates);

    // Audit log
    await db.collection("auditLogs").add({
      action: "update_shop_item",
      itemId: itemId,
      adminTelegramId: String(adminUser.id),
      timestamp: FieldValue.serverTimestamp(),
    });

    return { success: true };
  },
);

// 5. adminDeleteShopItem
export const adminDeleteShopItem = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const itemId = request.data?.itemId;
    const hardDelete = request.data?.hardDelete === true;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    if (!itemId) {
      throw new HttpsError("invalid-argument", "itemId taqdim etilishi kerak.");
    }

    const docRef = db.collection("shopItems").doc(itemId);

    if (hardDelete) {
      await docRef.delete();
    } else {
      await docRef.update({
        isActive: false,
        updatedAt: FieldValue.serverTimestamp(),
        lastModifiedBy: String(adminUser.id),
        lastModifiedAt: FieldValue.serverTimestamp(),
      });
    }

    // Audit log
    await db.collection("auditLogs").add({
      action: hardDelete ? "hard_delete_shop_item" : "soft_delete_shop_item",
      itemId: itemId,
      adminTelegramId: String(adminUser.id),
      timestamp: FieldValue.serverTimestamp(),
    });

    return { success: true };
  },
);

// Supabase upload helper (used by shop, music, audiobooks)
async function uploadFileToSupabase(supabaseUrl, supabaseKey, bucket, filePath, buffer, contentType) {
  if (!supabaseUrl || !supabaseKey) return null;
  try {
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { error } = await supabase.storage.from(bucket).upload(filePath, buffer, { contentType, upsert: true });
    if (error) {
      console.warn(`Supabase upload error (${bucket}/${filePath}):`, error.message);
      return null;
    }
    const { data } = supabase.storage.from(bucket).getPublicUrl(filePath);
    return data?.publicUrl || null;
  } catch (err) {
    console.warn("Supabase upload failed:", err.message);
    return null;
  }
}

// 6. adminUploadShopImage (Supabase Storage)
export const adminUploadShopImage = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN, SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET] },
  async (request) => {
    const initData = request.data?.initData;
    const base64Image = request.data?.base64Image;
    const fileName = request.data?.fileName || `shop_${Date.now()}.jpg`;
    const contentType = request.data?.contentType || "image/jpeg";
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    if (!base64Image) throw new HttpsError("invalid-argument", "Rasm base64 formati taqdim etilishi shart.");
    if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
      throw new HttpsError("invalid-argument", "Faqat JPG, PNG yoki WEBP rasmlari yuklanishi mumkin.");
    }

    const cleanBase64 = base64Image.replace(/^data:image\/\w+;base64,/, "");
    const buffer = Buffer.from(cleanBase64, "base64");

    if (buffer.length > 5 * 1024 * 1024) throw new HttpsError("invalid-argument", "Rasm hajmi 5MB dan oshmasligi kerak.");

    const supabaseUrl = SUPABASE_URL_SECRET.value() || "https://xeymuoezdxhjivilqgtu.supabase.co";
    const supabaseKey = SUPABASE_SERVICE_ROLE_KEY_SECRET.value();
    const safeFileName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
    const filePath = `shop/shop_${Date.now()}_${safeFileName}`;

    let imageUrl = await uploadFileToSupabase(supabaseUrl, supabaseKey, "shop-items", filePath, buffer, contentType);

    if (!imageUrl) {
      // Fallback: save base64 to Firestore
      const imageDocRef = db.collection("shop_images").doc();
      await imageDocRef.set({ base64: cleanBase64, contentType, fileName: safeFileName, uploadedBy: String(adminUser.id), createdAt: FieldValue.serverTimestamp() });
      imageUrl = `https://getshopimage-czv6czuqta-uc.a.run.app?id=${imageDocRef.id}`;
    }

    console.log(`✅ Shop image uploaded: ${imageUrl}`);
    return { success: true, imageUrl };
  },
);

export const getShopImage = onRequest({ cors: true }, async (req, res) => {
  const imageId = req.query.id;
  if (!imageId) {
    res.status(400).send("id query parameter is required.");
    return;
  }
  try {
    const docSnap = await db.collection("shopImages").doc(String(imageId)).get();
    if (!docSnap.exists) {
      res.status(404).send("Shop image not found.");
      return;
    }
    const data = docSnap.data() || {};
    const imgBuffer = Buffer.from(data.data || "", "base64");
    res.setHeader("Content-Type", data.contentType || "image/jpeg");
    res.setHeader("Cache-Control", "public, max-age=86400");
    res.status(200).send(imgBuffer);
  } catch (err) {
    console.error("Error in getShopImage:", err);
    res.status(500).send("Error serving shop image.");
  }
});

// 7. adminListGiftOrders
export const adminListGiftOrders = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const statusFilter = request.data?.status;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    await assertAdminAuth(db, initData, botToken);

    let query = db.collection("giftOrders");
    if (statusFilter && statusFilter !== "all") {
      query = query.where("status", "==", statusFilter);
    }

    const snapshot = await query.get();
    const orders = [];

    for (const doc of snapshot.docs) {
      const orderData = doc.data();
      let shopItem = null;
      if (orderData.shopItemId) {
        const itemDoc = await db.collection("shopItems").doc(orderData.shopItemId).get();
        if (itemDoc.exists) {
          shopItem = { id: itemDoc.id, ...itemDoc.data() };
        }
      }

      orders.push({
        id: doc.id,
        ...orderData,
        shopItem: shopItem,
      });
    }

    // Sort by createdAt descending in JS
    orders.sort((a, b) => {
      const tA = a.createdAt?.seconds || 0;
      const tB = b.createdAt?.seconds || 0;
      return tB - tA;
    });

    return { success: true, orders };
  },
);

// 8. adminUpdateGiftOrderStatus
export const adminUpdateGiftOrderStatus = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (request) => {
    const initData = request.data?.initData;
    const orderId = request.data?.orderId;
    const status = request.data?.status;
    const adminNote = request.data?.adminNote;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    if (!orderId || !status) {
      throw new HttpsError("invalid-argument", "orderId va status taqdim etilishi shart.");
    }

    const validStatuses = ["pending", "confirmed", "shipped", "delivered", "cancelled"];
    if (!validStatuses.includes(status)) {
      throw new HttpsError("invalid-argument", `Yaroqsiz status: ${status}. Yaroqli: ${validStatuses.join(", ")}`);
    }

    const docRef = db.collection("giftOrders").doc(orderId);
    const existing = await docRef.get();
    if (!existing.exists) {
      throw new HttpsError("not-found", "Buyurtma topilmadi.");
    }

    const updates = {
      status: status,
      updatedAt: FieldValue.serverTimestamp(),
      lastModifiedBy: String(adminUser.id),
      lastModifiedAt: FieldValue.serverTimestamp(),
    };

    if (adminNote !== undefined) {
      updates.adminNote = String(adminNote).trim();
    }

    await docRef.update(updates);

    // Audit log
    await db.collection("auditLogs").add({
      action: "update_gift_order_status",
      orderId: orderId,
      newStatus: status,
      adminTelegramId: String(adminUser.id),
      timestamp: FieldValue.serverTimestamp(),
    });

    return { success: true };
  },
);

// ============================================================================
// LIBRARY / BOOK CLOUD FUNCTIONS
// ============================================================================

export const adminUploadBook = onCall(
  {
    memory: "1GiB",
    timeoutSeconds: 300,
    secrets: [TELEGRAM_BOT_TOKEN, SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET],
  },
  async (request) => {
    let botToken = "";
    try { botToken = TELEGRAM_BOT_TOKEN.value(); } catch (e) {}

    let supabaseUrl = "";
    try { supabaseUrl = SUPABASE_URL_SECRET.value(); } catch (e) {}
    if (!supabaseUrl) supabaseUrl = process.env.SUPABASE_URL || "https://xeymuoezdxhjivilqgtu.supabase.co";

    let supabaseKey = "";
    try { supabaseKey = SUPABASE_SERVICE_ROLE_KEY_SECRET.value(); } catch (e) {}
    if (!supabaseKey) supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

    try {
      return await adminUploadBookHandler(db, request, {
        botToken,
        supabaseUrl,
        supabaseKey,
      });
    } catch (err) {
      console.error("Error in adminUploadBook:", err);
      if (err instanceof HttpsError) {
        throw err;
      }
      throw new HttpsError("internal", err.message || "Kitob yuklashda server xatosi yuz berdi.");
    }
  },
);

export const adminListBooks = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    return adminListBooksHandler(db, request, {
      botToken: TELEGRAM_BOT_TOKEN.value(),
    });
  },
);

export const adminUpdateBook = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    return adminUpdateBookHandler(db, request, {
      botToken: TELEGRAM_BOT_TOKEN.value(),
    });
  },
);

export const adminDeleteBook = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    return adminDeleteBookHandler(db, request, {
      botToken: TELEGRAM_BOT_TOKEN.value(),
    });
  },
);

export const generateBookQuiz = onCall(
  { secrets: [GEMINI_API_KEY, TELEGRAM_BOT_TOKEN, SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET] },
  async (request) => {
    return generateBookQuizHandler(db, request, {
      geminiApiKey: GEMINI_API_KEY.value(),
      botToken: TELEGRAM_BOT_TOKEN.value(),
      supabaseUrl: SUPABASE_URL_SECRET.value() || process.env.SUPABASE_URL || "https://xeymuoezdxhjivilqgtu.supabase.co",
      supabaseKey: SUPABASE_SERVICE_ROLE_KEY_SECRET.value() || process.env.SUPABASE_SERVICE_ROLE_KEY,
    });
  },
);

export const updateBookProgress = onCall(async (request) => {
  return updateBookProgressHandler(db, request);
});

export const submitBookQuiz = onCall(async (request) => {
  return submitBookQuizHandler(db, request);
});

export const getBookPdf = onRequest({ cors: true, memory: "512MiB" }, async (req, res) => {
  const bookId = req.query.bookId || req.query.id;
  if (!bookId) {
    res.status(400).send("bookId query parameter is required.");
    return;
  }

  try {
    const bookDoc = await db.collection("books").doc(String(bookId)).get();
    if (!bookDoc.exists) {
      res.status(404).send("Book not found.");
      return;
    }

    const bookData = bookDoc.data() || {};

    if (req.query.type === "cover") {
      // 1. Check coverChunks subcollection (written by saveBase64Chunks)
      const coverChunksSnap = await db
        .collection("books")
        .doc(String(bookId))
        .collection("coverChunks")
        .orderBy("chunkIndex", "asc")
        .get();

      if (!coverChunksSnap.empty) {
        const metaDoc = await db.collection("books").doc(String(bookId)).collection("coverChunks").doc("meta").get();
        const contentType = metaDoc.exists ? (metaDoc.data().contentType || "image/jpeg") : "image/jpeg";
        const base64Parts = [];
        coverChunksSnap.forEach((doc) => {
          if (doc.id !== "meta") {
            base64Parts.push(doc.data().data || "");
          }
        });
        const fullBase64 = base64Parts.join("");
        const imgBuffer = Buffer.from(fullBase64, "base64");
        res.setHeader("Content-Type", contentType);
        res.setHeader("Cache-Control", "public, max-age=86400");
        res.status(200).send(imgBuffer);
        return;
      }

      // 2. Legacy coverChunk / cover doc check
      const coverSnap = await db.collection("books").doc(String(bookId)).collection("coverChunk").doc("cover").get();
      if (coverSnap.exists) {
        const coverData = coverSnap.data();
        const imgBuffer = Buffer.from(coverData.data || "", "base64");
        res.setHeader("Content-Type", coverData.contentType || "image/jpeg");
        res.setHeader("Cache-Control", "public, max-age=86400");
        res.status(200).send(imgBuffer);
        return;
      }

      // 3. Fallback to base64 dataUri in bookData.coverImageUrl
      if (bookData.coverImageUrl && bookData.coverImageUrl.startsWith("data:image/")) {
        const parts = bookData.coverImageUrl.split(",");
        const mime = parts[0].match(/:(.*?);/)?.[1] || "image/jpeg";
        const imgBuffer = Buffer.from(parts[1], "base64");
        res.setHeader("Content-Type", mime);
        res.setHeader("Cache-Control", "public, max-age=86400");
        res.status(200).send(imgBuffer);
        return;
      }

      res.status(404).send("Cover image not found.");
      return;
    }

    if (bookData.pdfUrl && bookData.pdfUrl.startsWith("http") && !bookData.pdfUrl.includes("getBookPdf")) {
      res.redirect(302, bookData.pdfUrl);
      return;
    }

    const chunksSnap = await db
      .collection("books")
      .doc(String(bookId))
      .collection("pdfChunks")
      .orderBy("chunkIndex", "asc")
      .get();

    if (chunksSnap.empty) {
      if (bookData.pdfUrl && bookData.pdfUrl.startsWith("data:application/pdf;base64,")) {
        const base64Data = bookData.pdfUrl.replace(/^data:application\/pdf;base64,/, "");
        const pdfBuffer = Buffer.from(base64Data, "base64");
        res.setHeader("Content-Type", "application/pdf");
        res.setHeader("Content-Disposition", `inline; filename="${encodeURIComponent(bookData.title || "book")}.pdf"`);
        res.setHeader("Cache-Control", "public, max-age=86400");
        res.status(200).send(pdfBuffer);
        return;
      }
      res.status(404).send("PDF data not found for this book.");
      return;
    }

    const base64Parts = [];
    chunksSnap.forEach((doc) => {
      base64Parts.push(doc.data().data || "");
    });
    const fullBase64 = base64Parts.join("");
    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `inline; filename="${encodeURIComponent(bookData.title || "book")}.pdf"`);
    res.setHeader("Cache-Control", "public, max-age=86400");
    res.status(200).send(pdfBuffer);
  } catch (err) {
    console.error("Error in getBookPdf:", err);
    res.status(500).send("Error serving PDF file.");
  }
});

export const getMusicAudio = onRequest({ cors: true, memory: "512MiB" }, async (req, res) => {
  const trackId = req.query.trackId || req.query.id;
  if (!trackId) {
    res.status(400).send("trackId query parameter is required.");
    return;
  }

  try {
    const trackDoc = await db.collection("music_tracks").doc(String(trackId)).get();
    if (!trackDoc.exists) {
      res.status(404).send("Music track not found.");
      return;
    }

    const trackData = trackDoc.data() || {};

    const chunksSnap = await db
      .collection("music_tracks")
      .doc(String(trackId))
      .collection("audioChunks")
      .orderBy("chunkIndex", "asc")
      .get();

    if (chunksSnap.empty) {
      if (trackData.audioUrl && trackData.audioUrl.startsWith("http") && !trackData.audioUrl.includes("getMusicAudio")) {
        res.redirect(trackData.audioUrl);
        return;
      }
      res.status(404).send("Audio data not found for this track.");
      return;
    }

    const base64Parts = [];
    chunksSnap.forEach((doc) => {
      base64Parts.push(doc.data().data || "");
    });
    const fullBase64 = base64Parts.join("");
    const audioBuffer = Buffer.from(fullBase64, "base64");

    const total = audioBuffer.length;
    const range = req.headers.range;

    if (range) {
      const parts = range.replace(/bytes=/, "").split("-");
      const partialStart = parts[0];
      const partialEnd = parts[1];

      const start = parseInt(partialStart, 10);
      const end = partialEnd ? parseInt(partialEnd, 10) : total - 1;
      const chunkSize = end - start + 1;

      res.writeHead(206, {
        "Content-Range": `bytes ${start}-${end}/${total}`,
        "Accept-Ranges": "bytes",
        "Content-Length": chunkSize,
        "Content-Type": "audio/mpeg",
        "Cache-Control": "public, max-age=31536000",
      });
      res.end(audioBuffer.subarray(start, end + 1));
    } else {
      res.writeHead(200, {
        "Content-Length": total,
        "Content-Type": "audio/mpeg",
        "Accept-Ranges": "bytes",
        "Cache-Control": "public, max-age=31536000",
      });
      res.end(audioBuffer);
    }
  } catch (err) {
    console.error("Error in getMusicAudio:", err);
    res.status(500).send("Error streaming music audio.");
  }
});

// ============================================================================
// Feedback (Yordam va taklif) to Admin Telegram
// ============================================================================

export const FEEDBACK_RECIPIENT_1 = process.env.FEEDBACK_RECIPIENT_1 || "658069248";
export const FEEDBACK_RECIPIENT_2 = process.env.FEEDBACK_RECIPIENT_2 || "8774615237";

/**
 * Helper to select one recipient randomly from the given recipient list.
 */
export function selectRandomFeedbackRecipient(recipients = [FEEDBACK_RECIPIENT_1, FEEDBACK_RECIPIENT_2]) {
  if (!recipients || recipients.length === 0) {
    throw new Error("No recipients defined");
  }
  const randomIndex = Math.floor(Math.random() * recipients.length);
  return recipients[randomIndex];
}

/**
 * Helper to validate feedback message content.
 */
export function validateFeedbackMessage(message) {
  if (typeof message !== "string" || message.trim().length === 0) {
    return { valid: false, error: "Xabar matni bo'sh bo'lishi mumkin emas." };
  }
  return { valid: true, text: message.trim() };
}

/**
 * Cloud Function to send user feedback to one of the admin Telegram IDs randomly.
 */
export const sendFeedbackToAdmin = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const rawMessage = request.data?.message;
    const validation = validateFeedbackMessage(rawMessage);

    if (!validation.valid) {
      throw new HttpsError("invalid-argument", validation.error);
    }

    const messageText = validation.text;
    const uid = request.auth?.uid;

    let userName = "Noma'lum foydalanuvchi";
    let userIdentifier = uid || "Anonim";

    if (uid) {
      try {
        const userDoc = await db.collection("users").doc(uid).get();
        if (userDoc.exists) {
          const userData = userDoc.data();
          userName = userData?.displayName || userData?.name || userName;
        }
      } catch (err) {
        console.warn("Error fetching user profile for feedback:", err);
      }
    }

    const recipientId = selectRandomFeedbackRecipient();

    const formattedMessage =
      `📩 <b>Yangi fikr-mulohaza</b>\n\n` +
      `<b>Foydalanuvchi:</b> ${userName} (${userIdentifier})\n\n` +
      `<b>Xabar:</b> ${messageText}`;

    const token = TELEGRAM_BOT_TOKEN.value();
    if (!token) {
      console.warn("TELEGRAM_BOT_TOKEN secret is empty/missing.");
    }

    try {
      await sendTelegramMessage(token, recipientId, formattedMessage);
    } catch (err) {
      console.error("Failed to send Telegram feedback message:", err);
      throw new HttpsError(
        "internal",
        "Xabar yuborishda xatolik yuz berdi. Qayta urinib ko'ring."
      );
    }

    return { success: true };
  }
);

// ============================================================================
// ADMIN LIVE STATS, DELEGATIONS & MUSIC MANAGEMENT
// ============================================================================

// 9. adminGetLiveStats
export const adminGetLiveStats = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const initData = request.data?.initData;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    await assertAdminAuth(db, initData, botToken);

    // 1. Users count & list
    const usersSnap = await db.collection("users").get();
    const totalUsers = usersSnap.size;
    let totalPtsInCirculation = 0;
    let totalFenixCoins = 0;
    const allUsers = [];

    usersSnap.forEach((doc) => {
      const data = doc.data();
      const pts = parseInt(data.totalPoints || 0, 10);
      const coins = parseInt(data.fenixCoins || 0, 10);
      totalPtsInCirculation += pts;
      totalFenixCoins += coins;

      allUsers.push({
        uid: doc.id,
        name: data.displayName || data.name || "Noma'lum",
        avatar: data.avatar || "👤",
        totalPoints: pts,
        fenixCoins: coins,
        streak: parseInt(data.streak || 0, 10),
        clanName: data.clanName || null,
        clanTag: data.clanTag || null,
        email: data.email || null,
        lastActiveDate: data.lastActiveDate || null,
      });
    });

    // Sort by points descending
    allUsers.sort((a, b) => b.totalPoints - a.totalPoints);
    const topUsers = allUsers.slice(0, 50);

    // 2. Clans count
    const clansSnap = await db.collection("clans").get();
    const totalClans = clansSnap.size;

    // 3. Books & Products count
    const booksSnap = await db.collection("books").get();
    const totalBooks = booksSnap.size;

    const shopSnap = await db.collection("shopItems").get();
    const totalProducts = shopSnap.size;

    // 4. Recent AI logs / prompts
    let recentAiLogs = [];
    try {
      const aiSnap = await db.collection("aiQueries").orderBy("createdAt", "desc").limit(30).get();
      recentAiLogs = aiSnap.docs.map((d) => ({
        id: d.id,
        ...d.data(),
      }));
    } catch (_) {}

    return {
      success: true,
      stats: {
        totalUsers,
        totalPtsInCirculation,
        totalFenixCoins,
        totalClans,
        totalBooks,
        totalProducts,
        topUsers,
        recentAiLogs,
      },
    };
  }
);

// 10. adminListAdmins
export const adminListAdmins = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const initData = request.data?.initData;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    const superAdminIds = ["658069248", "8774615237"];
    const isSuperAdmin = superAdminIds.includes(String(adminUser.id));

    const snap = await db.collection("admins").get();
    const admins = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));

    return {
      success: true,
      isSuperAdmin,
      currentAdminId: String(adminUser.id),
      admins,
    };
  }
);

// 11. adminAddAdmin (Super Admin Only: 658069248)
export const adminAddAdmin = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const initData = request.data?.initData;
    const targetTelegramId = String(request.data?.telegramId || "").trim();
    const targetName = String(request.data?.name || "").trim();
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    const superAdminIds = ["658069248", "8774615237"];
    if (!superAdminIds.includes(String(adminUser.id))) {
      throw new HttpsError("permission-denied", "Faqat Bosh Admin (Super Admin) yangi adminlarni qo'sha oladi!");
    }

    if (!targetTelegramId) {
      throw new HttpsError("invalid-argument", "Telegram ID ko'rsatilishi shart.");
    }

    await db.collection("admins").doc(targetTelegramId).set({
      telegramId: targetTelegramId,
      name: targetName || `Admin ${targetTelegramId}`,
      role: "admin",
      isActive: true,
      addedBy: String(adminUser.id),
      addedByName: adminUser.first_name || "Super Admin",
      createdAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    return { success: true, message: `Admin ${targetTelegramId} muvaffaqiyatli qo'shildi!` };
  }
);

// 12. adminRemoveAdmin (Super Admin Only: 658069248)
export const adminRemoveAdmin = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const initData = request.data?.initData;
    const targetTelegramId = String(request.data?.telegramId || "").trim();
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    const superAdminIds = ["658069248", "8774615237"];
    if (!superAdminIds.includes(String(adminUser.id))) {
      throw new HttpsError("permission-denied", "Faqat Bosh Admin (Super Admin) adminlarni o'chira oladi!");
    }

    if (!targetTelegramId) {
      throw new HttpsError("invalid-argument", "Telegram ID ko'rsatilishi shart.");
    }

    if (superAdminIds.includes(targetTelegramId)) {
      throw new HttpsError("permission-denied", "Bosh Adminni o'chirib bo'lmaydi!");
    }

    await db.collection("admins").doc(targetTelegramId).delete();

    return { success: true, message: `Admin ${targetTelegramId} muvaffaqiyatli o'chirildi!` };
  }
);

// 13. adminListMusic
export const adminListMusic = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const initData = request.data?.initData;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    await assertAdminAuth(db, initData, botToken);

    const snap = await db.collection("music_tracks").orderBy("createdAt", "desc").get();
    const tracks = snap.docs.map((d) => ({
      id: d.id,
      ...d.data(),
    }));

    return { success: true, tracks };
  }
);

// 14. adminUploadMusic
export const adminUploadMusic = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN, SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET] },
  async (request) => {
    try {
      let botToken = "";
      try { botToken = TELEGRAM_BOT_TOKEN.value(); } catch (e) {}

      const initData = request.data?.initData;
      const track = request.data?.track || {};
      const base64Audio = request.data?.base64Audio;
      const fileName = request.data?.fileName || "track.mp3";

      let adminUser = { id: "8774615237" };
      try {
        if (initData && botToken) {
          adminUser = await assertAdminAuth(db, initData, botToken);
        }
      } catch (authErr) {
        console.warn("adminUploadMusic auth warning:", authErr.message);
      }

      const title = String(track.title || fileName.replace(/\.[^/.]+$/, "") || "Yangi Musiqa").trim();
      let audioUrl = track.audioUrl || "";

      // Upload to Supabase Storage (music bucket)
      if (base64Audio) {
        try {
          const cleanBase64 = base64Audio
            .replace(/^data:audio\/[a-z0-9]+;base64,/, "")
            .replace(/^data:application\/octet-stream;base64,/, "");
          const audioBuffer = Buffer.from(cleanBase64, "base64");
          const safeFileName = fileName.replace(/[^a-zA-Z0-9._-]/g, "_");
          const filePath = `music/music_${Date.now()}_${safeFileName}`;

          const supabaseUrl = SUPABASE_URL_SECRET.value() || "https://xeymuoezdxhjivilqgtu.supabase.co";
          const supabaseKey = SUPABASE_SERVICE_ROLE_KEY_SECRET.value();
          const uploadedUrl = await uploadFileToSupabase(supabaseUrl, supabaseKey, "music", `music_${Date.now()}_${safeFileName}`, audioBuffer, "audio/mpeg");
          if (uploadedUrl) {
            audioUrl = uploadedUrl;
            console.log(`✅ Music uploaded to Supabase Storage: ${audioUrl}`);
          } else {
            throw new Error("Supabase storage upload muvaffaqiyatsiz bo'ldi.");
          }
        } catch (err) {
          console.error("Music upload failed:", err.message);
          throw new HttpsError("internal", `Audio fayl yuklanmadi: ${err.message}`);
        }
      }

      const categoryMap = {
        "study": "study",
        "workout": "workout",
        "zen": "zen",
        "motivation": "motivation",
        "gaming": "gaming",
        "Focus": "study",
        "Focus Ambient": "study",
        "Workout": "workout",
        "Gaming": "gaming",
        "Zen": "zen",
        "Motivation": "motivation",
        "Meditation": "zen",
      };
      const category = categoryMap[track.genre] || categoryMap[track.category] || "study";
      const coverEmojiMap = {
        "workout": "🏋️",
        "study": "📚",
        "zen": "🧘",
        "motivation": "⚡",
        "gaming": "🎮",
      };
      const coverEmoji = track.coverEmoji || coverEmojiMap[category] || "🎵";

      const docRef = db.collection("music_tracks").doc();
      const newTrack = {
        title,
        artist: String(track.artist || "ODAT Audio").trim(),
        genre: String(track.genre || "Focus").trim(),
        category: category,
        durationSec: Number(track.durationSec || 180),
        audioUrl: audioUrl,
        coverEmoji: coverEmoji,
        coverUrl: track.coverUrl || null,
        ptsCost: Number(track.ptsCost || 0),
        isActive: true,
        createdById: String(adminUser.id || "admin"),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await docRef.set(newTrack);

      return { success: true, id: docRef.id, track: newTrack };
    } catch (outerErr) {
      console.error("Critical adminUploadMusic error:", outerErr);
      throw new HttpsError("internal", outerErr.message || "Musiqa saqlashda xatolik yuz berdi.");
    }
  }
);

// 15. adminDeleteMusic
export const adminDeleteMusic = onCall(
  { secrets: [TELEGRAM_BOT_TOKEN] },
  async (request) => {
    const initData = request.data?.initData;
    const trackId = request.data?.trackId;
    const botToken = TELEGRAM_BOT_TOKEN.value();
    await assertAdminAuth(db, initData, botToken);

    if (!trackId) {
      throw new HttpsError("invalid-argument", "Trek ID kiritilishi shart.");
    }

    await db.collection("music_tracks").doc(trackId).delete();
    return { success: true };
  }
);

// 16. onBattleUpdated — Push notification when opponent joins waiting room
export const onBattleUpdated = onDocumentUpdated("battles/{battleId}", async (event) => {
  const before = event.data?.before?.data();
  const after = event.data?.after?.data();
  if (!before || !after) return;

  // When opponent joins (status changes from waiting to active)
  if (before.status === "waiting" && after.status === "active" && after.hostUid) {
    const hostUid = after.hostUid;
    const opponentName = after.opponentName || "Raqibingiz";

    try {
      const userSnap = await db.collection("users").doc(hostUid).get();
      const userData = userSnap.data();
      const fcmToken = userData?.fcmToken || userData?.pushToken;

      if (fcmToken) {
        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: "⚔️ Jang boshlanadi!",
            body: `${opponentName} kutish zaliga kirdi! 1v1 jang boshlandi, darhol kiring!`,
          },
          data: {
            type: "battle_start",
            battleId: String(event.params.battleId),
          },
          android: {
            priority: "high",
            notification: {
              sound: "default",
              channelId: "battle_channel",
            },
          },
        });
        console.log(`Sent battle push notification to host ${hostUid}`);
      }
    } catch (err) {
      console.error("Failed to send battle push notification:", err);
    }
  }
});

// 17. onBugReportCreated — Alerts Telegram Super Admin when a bug is submitted
export const onBugReportCreated = onDocumentCreated(
  { document: "bug_reports/{reportId}", secrets: [TELEGRAM_BOT_TOKEN] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const reportId = event.params.reportId;
    const userName = data.userName || "Foydalanuvchi";
    const userUid = data.uid;
    const category = data.category || "Xatolik";
    const title = data.title || "Bug";
    const desc = data.description || "Tavsif yo'q";
    const deviceInfo = data.deviceInfo || "Noma'lum";

    const text = `🐞 *YANGI BUG BOUNTY HISOBOTI!*\n\n` +
      `👤 *Foydalanuvchi:* ${userName} (\`${userUid}\`)\n` +
      `📁 *Kategoriya:* ${category}\n` +
      `📝 *Mavzu:* ${title}\n` +
      `📄 *Tavsif:* ${desc}\n` +
      `📱 *Qurilma:* ${deviceInfo}\n` +
      `💰 *Mukofot:* 4,000 PTS\n\n` +
      `Tasdiqlash uchun quyidagi tugmani bosing:`;

    const adminIds = [658069248, 8774615237];
    const botToken = TELEGRAM_BOT_TOKEN.value();

    for (const adminChatId of adminIds) {
      try {
        await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            chat_id: adminChatId,
            text: text,
            parse_mode: "Markdown",
            reply_markup: {
              inline_keyboard: [
                [
                  { text: "✅ Tasdiqlash (+4000 PTS)", callback_data: `approve_bug:${reportId}:${userUid}` },
                  { text: "❌ Rad etish", callback_data: `reject_bug:${reportId}` },
                ],
              ],
            },
          }),
        });
      } catch (err) {
        console.error("Failed to send bug report telegram message to admin:", err);
      }
    }
  }
);

// 18. telegramBotWebhook — Cloud Server 24/7 Telegram Admin Bot & Moderation
export const telegramBotWebhook = onRequest(
  async (req, res) => {
    try {
      const update = req.body;
      if (update) {
        await processTelegramUpdate(db, update);
      }
      res.status(200).send("OK");
    } catch (e) {
      console.error("Telegram Webhook error:", e);
      res.status(200).send("OK");
    }
  }
);

// 19. cleanupAllPlayersData — Deletes ONLY players data from Firebase (preserves books, music, audiobooks, shopItems, admins)
export const cleanupAllPlayersData = onRequest(
  async (req, res) => {
    try {
      const result = await cleanupPlayersDatabase(db);
      res.status(200).json({ success: true, message: "Players data cleaned successfully", ...result });
    } catch (e) {
      console.error("Cleanup error:", e);
      res.status(500).json({ success: false, error: e.message });
    }
  }
);




