import test from "node:test";
import assert from "node:assert/strict";
import crypto from "node:crypto";
import { verifyTelegramInitData, isTelegramUserAdmin } from "../telegramAdminAuth.js";

const TEST_BOT_TOKEN = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz";

function generateTestInitData(userObj, botToken = TEST_BOT_TOKEN) {
  const authDate = Math.floor(Date.now() / 1000);
  const userJson = JSON.stringify(userObj);
  
  const params = new URLSearchParams();
  params.set("auth_date", authDate.toString());
  params.set("query_id", "AAG_test_query_id");
  params.set("user", userJson);

  const sortedKeys = Array.from(params.keys()).sort();
  const dataCheckString = sortedKeys
    .map((key) => `${key}=${params.get(key)}`)
    .join("\n");

  const secretKey = crypto
    .createHmac("sha256", "WebAppData")
    .update(botToken)
    .digest();

  const hash = crypto
    .createHmac("sha256", secretKey)
    .update(dataCheckString)
    .digest("hex");

  params.set("hash", hash);
  return params.toString();
}

test("verifyTelegramInitData validates authentic Telegram initData correctly", () => {
  const user = { id: 987654321, first_name: "Jasur", username: "jasur_admin" };
  const initData = generateTestInitData(user);

  const result = verifyTelegramInitData(initData, TEST_BOT_TOKEN);
  assert.equal(result.valid, true);
  assert.equal(result.user.id, 987654321);
  assert.equal(result.user.first_name, "Jasur");
});

test("verifyTelegramInitData rejects tampered/fake hash", () => {
  const user = { id: 987654321, first_name: "Hacker" };
  let initData = generateTestInitData(user);
  
  // Tamper with query string
  initData = initData.replace("Jasur", "Hacker") + "123";

  const result = verifyTelegramInitData(initData, TEST_BOT_TOKEN);
  assert.equal(result.valid, false);
  assert.match(result.error, /Imzo/i);
});

test("verifyTelegramInitData rejects missing initData or token", () => {
  assert.equal(verifyTelegramInitData("", TEST_BOT_TOKEN).valid, false);
  assert.equal(verifyTelegramInitData("query_id=123", "").valid, false);
});

test("isTelegramUserAdmin checks env vars and Firestore", async () => {
  process.env.ADMIN_TELEGRAM_IDS = "987654321,11223344";

  // Mock Firestore db
  const mockDb = {
    collection: (collName) => ({
      doc: (docId) => ({
        get: async () => ({
          exists: docId === "555666777",
          data: () => ({ isActive: true }),
        }),
      }),
      where: () => ({
        limit: () => ({
          get: async () => ({ empty: true, docs: [] }),
        }),
      }),
    }),
  };

  // Admin in env var
  assert.equal(await isTelegramUserAdmin(mockDb, 987654321), true);
  assert.equal(await isTelegramUserAdmin(mockDb, "11223344"), true);

  // Admin in Firestore doc ID
  assert.equal(await isTelegramUserAdmin(mockDb, "555666777"), true);

  // Non-admin user
  assert.equal(await isTelegramUserAdmin(mockDb, 999999999), false);
});
