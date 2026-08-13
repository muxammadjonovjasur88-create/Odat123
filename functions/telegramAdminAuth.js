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

  if (!botToken) {
    return { valid: false, error: "Telegram bot token sozlanmagan" };
  }

  try {
    const urlParams = new URLSearchParams(initData);
    const hash = urlParams.get("hash");
    if (!hash) {
      return { valid: false, error: "initData ichida hash parametri topilmadi" };
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
      return { valid: false, error: "Imzo (hash) mos kelmadi — soxtalashtirilgan bo'lishi mumkin" };
    }

    // Check freshness (optional, 14-day window for Telegram web app sessions)
    const authDate = parseInt(urlParams.get("auth_date") || "0", 10);
    if (authDate > 0) {
      const now = Math.floor(Date.now() / 1000);
      if (now - authDate > 86400 * 14) {
        return { valid: false, error: "initData sessiya muddati o'tgan" };
      }
    }

    const userStr = urlParams.get("user");
    let user = null;
    if (userStr) {
      try {
        user = JSON.parse(userStr);
      } catch (err) {
        // ignore parse error
      }
    }

    if (!user || !user.id) {
      return { valid: false, error: "Foydalanuvchi ma'lumotlari parse qilinmadi" };
    }

    return { valid: true, user };
  } catch (error) {
    return { valid: false, error: `initData tekshirishda xatolik: ${error.message}` };
  }
}

/**
 * Checks if a given Telegram User ID has admin privileges.
 */
export async function isTelegramUserAdmin(db, telegramId) {
  if (!telegramId) return false;

  const idStr = String(telegramId);

  // 1. Check ADMIN_TELEGRAM_IDS environment variable
  const envAdmins = (process.env.ADMIN_TELEGRAM_IDS || "8774615237")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);

  if (envAdmins.includes(idStr)) {
    return true;
  }

  // 2. Check Firestore "admins" collection
  // Document ID can be the telegramId string
  const adminDoc = await db.collection("admins").doc(idStr).get();
  if (adminDoc.exists && adminDoc.data()?.isActive !== false) {
    return true;
  }

  // Or document contains telegramId field
  const querySnap = await db
    .collection("admins")
    .where("telegramId", "==", idStr)
    .limit(1)
    .get();

  if (!querySnap.empty && querySnap.docs[0].data()?.isActive !== false) {
    return true;
  }

  return false;
}

/**
 * Validates initData and asserts admin rights, returning the validated user.
 * Throws an Error if validation fails.
 */
export async function assertAdminAuth(db, initData, botToken) {
  const result = verifyTelegramInitData(initData, botToken);
  if (!result.valid) {
    throw new HttpsError("permission-denied", `Ruxsat rad etildi: ${result.error}`);
  }

  const isAdmin = await isTelegramUserAdmin(db, result.user.id);
  if (!isAdmin) {
    throw new HttpsError("permission-denied", `Ruxsat rad etildi: Telegram ID (${result.user.id}) adminlar ro'yxatida yo'q.`);
  }

  return result.user;
}
