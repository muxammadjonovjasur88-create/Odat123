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

// ---------------------------------------------------------------------------
// BOSQICH A — linkTelegramChatId

export const linkTelegramChatId = onRequest(
  {secrets: [TELEGRAM_BOT_TOKEN]},
  async (req, res) => {
    // FORCE DEPLOY v2026.08.11-admin-fix
    // Faqat POST qabul qilamiz
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    const update = req.body;
    console.log("Telegram webhook received update:", JSON.stringify(update));
    const message = update?.message;
    if (!message) {
      res.status(200).send("ok"); // Telegram boshqa event turlarini ham yuboradi
      return;
    }

    const text = (message.text ?? "").trim();
    const chatId = String(message.chat?.id ?? "");
    const fromId = String(message.from?.id ?? chatId);
    console.log(`Telegram message fromId=${fromId}, chatId=${chatId}, text="${text}"`);

    // /admin buyrug'ini tekshiramiz
    if (text === "/admin" || text.startsWith("/admin")) {
      console.log(`Processing /admin command for user ${fromId}...`);
      const isAdmin = await isTelegramUserAdmin(db, fromId);
      if (!isAdmin) {
        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN.value(),
          chatId,
          "❌ Bu buyruq faqat administratorlar uchun.",
        );
        res.status(200).send("ok");
        return;
      }

      const webAppUrl = process.env.ADMIN_WEBAPP_URL || "https://flowa-4fca9.web.app";
      await sendTelegramMessageWithWebAppButtons(
        TELEGRAM_BOT_TOKEN.value(),
        chatId,
        "🛍️ <b>Odat Admin Paneliga xush kelibsiz!</b>\n\n" +
        "Quyidagi tugmalar orqali Do'kon mahsulotlari, buyurtmalar va kutubxona kitoblarini boshqarishingiz mumkin.",
        [
          [
            {
              text: "🏪 Admin Panelni ochish",
              web_app: { url: webAppUrl },
            },
          ],
          [
            {
              text: "📚 Kitob qo'shish",
              web_app: { url: `${webAppUrl}?tab=books&action=add` },
            },
          ],
        ],
      );
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
          TELEGRAM_BOT_TOKEN.value(),
          chatId,
          "❌ <b>Kirish so'rovi topilmadi.</b>\n\nIltimos, Odat ilovasiga qaytib, qayta urinib ko'ring. 🌿",
        );
        res.status(200).send("ok");
        return;
      }

      const reqData = reqDoc.data() || {};
      if (reqData.status !== "pending") {
        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN.value(),
          chatId,
          "❌ <b>Bu kirish so'rovi allaqachon ishlatilgan yoki bekor qilingan.</b> 🌿",
        );
        res.status(200).send("ok");
        return;
      }

      if (Date.now() > (reqData.expiresAt || 0)) {
        await reqRef.update({ status: "expired" });
        await sendTelegramMessage(
          TELEGRAM_BOT_TOKEN.value(),
          chatId,
          "⏰ <b>Kirish so'rovi vaqti tugagan (5 daqiqa).</b>\n\nIlovadan yangi so'rov yuboring. 🌿",
        );
        res.status(200).send("ok");
        return;
      }

      // User lookup: check if Telegram ID is linked in users collection
      let targetUid = null;
      let isNewUser = false;

      const userByIdSnap = await db.collection("users").where("telegramId", "==", fromId).limit(1).get();
      if (!userByIdSnap.empty) {
        targetUid = userByIdSnap.docs[0].id;
      } else {
        const userByChatSnap = await db.collection("users").where("telegramChatId", "==", chatId).limit(1).get();
        if (!userByChatSnap.empty) {
          targetUid = userByChatSnap.docs[0].id;
        }
      }

      if (targetUid) {
        // Existing user profile — link latest IDs
        await db.collection("users").doc(targetUid).set({
          telegramId: fromId,
          telegramChatId: chatId,
        }, { merge: true });
      } else {
        // New user creation
        isNewUser = true;
        const firstName = message.from?.first_name || "Foydalanuvchi";
        const lastName = message.from?.last_name || "";
        const fullName = `${firstName} ${lastName}`.trim() || "Foydalanuvchi";

        try {
          const userRecord = await getAuth().createUser({
            displayName: fullName,
          });
          targetUid = userRecord.uid;
        } catch (e) {
          targetUid = `tg_${fromId}`;
        }

        const now = new Date();
        const yyyy = now.getFullYear();
        const startOfYear = new Date(yyyy, 0, 1);
        const weekNum = Math.ceil((((now.getTime() - startOfYear.getTime()) / 86400000) + startOfYear.getDay() + 1) / 7);
        const weekId = `${yyyy}-W${String(weekNum).padStart(2, "0")}`;

        await db.collection("users").doc(targetUid).set({
          name: fullName,
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

      // Generate Firebase Auth Custom Token
      const customToken = await getAuth().createCustomToken(targetUid);

      // Approve loginRequest doc so client real-time stream reacts instantly
      await reqRef.update({
        status: "approved",
        uid: targetUid,
        customToken: customToken,
        telegramId: fromId,
        chatId: chatId,
        isNewUser: isNewUser,
        approvedAt: FieldValue.serverTimestamp(),
      });

      const successMsg = isNewUser ?
        "✅ <b>Ro'yxatdan o'tildi va kirish tasdiqlandi!</b>\n\nOdat ilovasiga xush kelibsiz. Tizimga avtomatik kirilmoqda... 🌿" :
        "✅ <b>Kirish tasdiqlandi!</b>\n\nOdat ilovasiga xush kelibsiz. Tizimga avtomatik kirilmoqda... 🌿";

      await sendTelegramMessage(TELEGRAM_BOT_TOKEN.value(), chatId, successMsg);
      res.status(200).send("ok");
      return;
    }

    const isLoginCommand = text === "/login" || text.startsWith("/login") || text === "/code" || text === "/start";
    const parts = text.split(" ");
    const uid = parts[1]?.trim() ?? "";

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
        TELEGRAM_BOT_TOKEN.value(),
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
        TELEGRAM_BOT_TOKEN.value(),
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
    throw new HttpsError("invalid-argument", "Shop item ID kiritilmadi.");
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
      throw new HttpsError("not-found", "Mahsulot topilmadi.");
    }

    const itemData = itemDoc.data();
    if (!itemData.isActive) {
      throw new HttpsError("failed-precondition", "Ushbu mahsulot hozirda nofaol.");
    }

    if (itemData.type !== "gift") {
      throw new HttpsError("invalid-argument", "Tanlangan mahsulot sovg'a emas.");
    }

    if (itemData.stock !== null && itemData.stock !== undefined && itemData.stock <= 0) {
      throw new HttpsError("failed-precondition", "Ushbu sovg'a zaxirada tugagan.");
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
        `Buyurtma berish uchun ochkolaringiz yetarli emas. Talab qilinadi: ${pointsCost}, sizda: ${currentPoints}`,
      );
    }

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

    // giftOrders ga yangi buyurtma qo'shamiz
    const orderRef = db.collection("giftOrders").doc();
    const formattedPhone = cleanPhone.startsWith("+")
      ? cleanPhone
      : (cleanPhone.startsWith("998") ? `+${cleanPhone}` : `+998${cleanPhone}`);

    transaction.set(orderRef, {
      userId: uid,
      shopItemId: shopItemId,
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

    return {
      success: true,
      user: {
        id: adminUser.id,
        first_name: adminUser.first_name,
        username: adminUser.username,
      },
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

// 6. adminUploadShopImage
export const adminUploadShopImage = onCall(
  {secrets: [TELEGRAM_BOT_TOKEN, SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET]},
  async (request) => {
    const initData = request.data?.initData;
    const base64Image = request.data?.base64Image;
    const fileName = request.data?.fileName || `shop_${Date.now()}.jpg`;
    const contentType = request.data?.contentType || "image/jpeg";
    const botToken = TELEGRAM_BOT_TOKEN.value();
    const adminUser = await assertAdminAuth(db, initData, botToken);

    if (!base64Image) {
      throw new HttpsError("invalid-argument", "Rasm base64 formati taqdim etilishi shart.");
    }

    // Restriction check: image MIME type
    if (!["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
      throw new HttpsError("invalid-argument", "Faqat JPG, PNG yoki WEBP rasmlari yuklanishi mumkin.");
    }

    // Clean base64 string
    const cleanBase64 = base64Image.replace(/^data:image\/\w+;base64,/, "");
    const buffer = Buffer.from(cleanBase64, "base64");

    // Restriction check: Max 5MB
    if (buffer.length > 5 * 1024 * 1024) {
      throw new HttpsError("invalid-argument", "Rasm hajmi 5MB dan oshmasligi kerak.");
    }

    let supabaseUrl = "";
    try { supabaseUrl = SUPABASE_URL_SECRET.value(); } catch (e) {}
    if (!supabaseUrl) supabaseUrl = process.env.SUPABASE_URL || "https://xeymuoezdxhjivilqgtu.supabase.co";

    let supabaseKey = "";
    try { supabaseKey = SUPABASE_SERVICE_ROLE_KEY_SECRET.value(); } catch (e) {}
    if (!supabaseKey) supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || "";

    let imageUrl = null;
    if (supabaseKey) {
      try {
        const supabase = createClient(supabaseUrl, supabaseKey);
        const filePath = `shop/${Date.now()}_${fileName}`;

        const { data, error } = await supabase.storage
          .from("shop-items")
          .upload(filePath, buffer, {
            contentType: contentType,
            upsert: true,
          });

        if (!error) {
          const { data: publicData } = supabase.storage
            .from("shop-items")
            .getPublicUrl(filePath);
          if (publicData?.publicUrl) {
            imageUrl = publicData.publicUrl;
          }
        } else {
          console.warn("Supabase shop image upload error:", error.message);
        }
      } catch (err) {
        console.warn("Supabase shop image upload network error:", err.message);
      }
    }

    // Fallback if Supabase is missing/failed:
    if (!imageUrl) {
      const dataUri = `data:${contentType};base64,${cleanBase64}`;
      if (cleanBase64.length < 300000) {
        imageUrl = dataUri;
      } else {
        const imageId = `shop_img_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
        await db.collection("shopImages").doc(imageId).set({
          data: cleanBase64,
          contentType: contentType,
          createdAt: FieldValue.serverTimestamp(),
        });
        imageUrl = `https://us-central1-flowa-4fca9.cloudfunctions.net/getShopImage?id=${imageId}`;
      }
    }

    await db.collection("auditLogs").add({
      action: "upload_shop_image",
      adminTelegramId: String(adminUser.id),
      imageUrl: imageUrl,
      timestamp: FieldValue.serverTimestamp(),
    });

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
  { secrets: [TELEGRAM_BOT_TOKEN, SUPABASE_URL_SECRET, SUPABASE_SERVICE_ROLE_KEY_SECRET] },
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

export const getBookPdf = onRequest({ cors: true }, async (req, res) => {
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
    const pdfBuffer = Buffer.from(fullBase64, "base64");

    res.setHeader("Content-Type", "application/pdf");
    res.setHeader("Content-Disposition", `inline; filename="${encodeURIComponent(bookData.title || "book")}.pdf"`);
    res.setHeader("Cache-Control", "public, max-age=86400");
    res.status(200).send(pdfBuffer);
  } catch (err) {
    console.error("Error in getBookPdf:", err);
    res.status(500).send("Error serving PDF file.");
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



