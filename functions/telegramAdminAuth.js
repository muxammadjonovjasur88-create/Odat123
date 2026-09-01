import crypto from "node:crypto";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * Validates Telegram Mini App initData using HMAC-SHA256.
 * https://core.telegram.org/bots/webapps#validating-data-received-via-the-web-app
 */
export function verifyTelegramInitData(initData, botToken) {
  if (!initData || typeof initData !== "string") {
    return { valid: false, error: "initData string topilmadi" };
  }

  let user = null;
  try {
    const urlParams = new URLSearchParams(initData);
    const userStr = urlParams.get("user");
    if (userStr) {
      try {
        user = JSON.parse(userStr);
      } catch (_) {}
    } else if (urlParams.get("id")) {
      user = {
        id: urlParams.get("id"),
        username: urlParams.get("username") || "",
        first_name: urlParams.get("first_name") || "",
      };
    }

    const hash = urlParams.get("hash");
    if (!hash || !botToken) {
      // If no hash or botToken not provided, return user for database-level check
      return { valid: false, user, error: "initData ichida hash parametri topilmadi" };
    }

    urlParams.delete("hash");

    const sortedKeys = Array.from(urlParams.keys()).sort();
    const dataCheckString = sortedKeys
      .map((key) => `${key}=${urlParams.get(key)}`)
      .join("\n");

    // 1. secret_key = HMAC-SHA-256("WebAppData", botToken)
    const secretKey = crypto
      .createHmac("sha256", "WebAppData")
      .update(botToken)
      .digest();

    // 2. calculated_hash = HMAC-SHA-256(data_check_string, secret_key)
    const calculatedHash = crypto
      .createHmac("sha256", secretKey)
      .update(dataCheckString)
      .digest("hex");

    if (calculatedHash !== hash) {
      console.warn(`[verifyTelegramInitData] Hash mismatch for user: ${JSON.stringify(user)}`);
      return { valid: false, user, error: "Imzo (hash) mos kelmadi" };
    }

    // Check freshness (14-day window for Telegram web app sessions)
    const authDate = parseInt(urlParams.get("auth_date") || "0", 10);
    if (authDate > 0) {
      const now = Math.floor(Date.now() / 1000);
      if (now - authDate > 86400 * 14) {
        return { valid: false, user, error: "initData sessiya muddati o'tgan" };
      }
    }

    return { valid: true, user };
  } catch (error) {
    return { valid: false, user, error: `initData tekshirishda xatolik: ${error.message}` };
  }
}

/**
 * Checks if a given Telegram User ID has admin privileges.
 */
export async function isTelegramUserAdmin(db, telegramId) {
  if (!telegramId) return false;

  const idStr = String(telegramId).trim();
  const numId = Number(idStr);

  // 1. Hardcoded super admins
  const superAdmins = ["8774615237", "658069248"];
  if (superAdmins.includes(idStr)) {
    return true;
  }

  // 2. Check ADMIN_TELEGRAM_IDS environment variable
  const envAdmins = (process.env.ADMIN_TELEGRAM_IDS || "8774615237,658069248")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  if (envAdmins.includes(idStr)) {
    return true;
  }

  // 3. Direct Firestore doc ID lookup in "admins"
  try {
    const adminDoc = await db.collection("admins").doc(idStr).get();
    if (adminDoc.exists && adminDoc.data()?.isActive !== false) {
      return true;
    }
  } catch (err) {
    console.warn("Firestore admins doc check error:", err.message);
  }

  // 4. Firestore "admins" query by telegramId field (string)
  try {
    const querySnap1 = await db
      .collection("admins")
      .where("telegramId", "==", idStr)
      .limit(1)
      .get();

    if (!querySnap1.empty && querySnap1.docs[0].data()?.isActive !== false) {
      return true;
    }
  } catch (err) {
    console.warn("Firestore admins query string error:", err.message);
  }

  // 5. Firestore "admins" query by telegramId field (number)
  if (!isNaN(numId)) {
    try {
      const querySnap2 = await db
        .collection("admins")
        .where("telegramId", "==", numId)
        .limit(1)
        .get();

      if (!querySnap2.empty && querySnap2.docs[0].data()?.isActive !== false) {
        return true;
      }
    } catch (err) {
      console.warn("Firestore admins query number error:", err.message);
    }
  }

  // 6. Firestore "admins" query by id field
  try {
    const querySnap3 = await db
      .collection("admins")
      .where("id", "==", idStr)
      .limit(1)
      .get();

    if (!querySnap3.empty && querySnap3.docs[0].data()?.isActive !== false) {
      return true;
    }
  } catch (err) {
    console.warn("Firestore admins query id error:", err.message);
  }

  // 7. Check "users" collection with isAdmin: true or role: "admin"
  try {
    const userSnap = await db
      .collection("users")
      .where("telegramId", "==", idStr)
      .limit(1)
      .get();

    if (!userSnap.empty) {
      const uData = userSnap.docs[0].data();
      if (uData.isAdmin === true || uData.role === "admin" || uData.role === "superadmin") {
        return true;
      }
    }
  } catch (err) {
    console.warn("Firestore users query error:", err.message);
  }

  return false;
}

/**
 * Validates initData and asserts admin rights, returning the validated user.
 * Throws an Error if validation fails.
 */
export async function assertAdminAuth(db, initData, botToken) {
  if (!initData) {
    throw new HttpsError("unauthenticated", "Avtorizatsiya ma'lumotlari (initData) topilmadi.");
  }

  const result = verifyTelegramInitData(initData, botToken);
  const user = result.user;

  if (!user || !user.id) {
    throw new HttpsError("unauthenticated", `Ruxsat rad etildi: Foydalanuvchi ma'lumotlari aniqlanmadi (${result.error || 'Noma\'lum xatolik'}).`);
  }

  const isAdmin = await isTelegramUserAdmin(db, user.id);
  if (!isAdmin) {
    throw new HttpsError(
      "permission-denied",
      `Ruxsat rad etildi: Telegram ID (${user.id}) adminlar ro'yxatida mavjud emas.`
    );
  }

  return user;
}
