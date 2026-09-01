/**
 * ODAT / Flowa Telegram Bot & Admin Panel Runner
 * Bot: @odat_fenix_bot
 * 
 * Ushbu skript botni to'g'ridan-to'g'ri (real vaqtda) ishga tushiradi.
 * Admin (ID: 8774615237) uchun to'liq boshqaruv va TAHRIRLASH (EDIT):
 * - 🎁 Do'konga sovg'alar qo'shish, o'chirish va TAHRIRLASH (PTS narxi, Rasmi, Nomi, Tavsifi, Soni)
 * - 📚 Kitoblar (PDF) qo'shish/o'chirish/tahrirlash -> Firestore `books`
 * - 🎵 Musiqalar (MP3) qo'shish/o'chirish/tahrirlash -> Firestore `music_tracks`
 * - 🎧 Audio kitoblar qo'shish/o'chirish/tahrirlash -> Firestore `audiobooks`
 * 
 * Ishga tushirish: node server/bot-runner.js
 */

const TOKEN = process.env.TELEGRAM_BOT_TOKEN || "8855349705:AAGMa9cMyo62Fh8gThoC1xtuRyQwnwu6N4U";
const TELEGRAM_API = `https://api.telegram.org/bot${TOKEN}`;
const TELEGRAM_FILE_API = `https://api.telegram.org/file/bot${TOKEN}`;

const FIREBASE_PROJECT_ID = "flowa-4fca9";
const FIREBASE_API_KEY = "AIzaSyBEhqM5KjIqSWFJx_sUbozulv4h6CN-jtg";
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/databases/(default)/documents`;

// Adminlar ro'yxati (Asosiy Super Adminlar va Delegated adminlar kesh)
const ADMIN_IDS = ["8774615237", "658069248"];
const cachedAdmins = new Set(ADMIN_IDS.map(id => String(id)));
let lastAdminCacheSync = 0;

async function isUserAdmin(userId) {
  if (!userId) return false;
  const idStr = String(userId).trim();
  if (cachedAdmins.has(idStr)) return true;

  // Har 30 soniyada Firestore `admins` kolleksiyasidan barcha faol adminlarni yuklash
  if (Date.now() - lastAdminCacheSync > 30000) {
    try {
      const res = await firestoreListDocs("admins", 100);
      if (res.success && res.docs) {
        ADMIN_IDS.forEach(id => cachedAdmins.add(String(id)));
        res.docs.forEach(doc => {
          if (doc.id) cachedAdmins.add(String(doc.id).trim());
          if (doc.telegramId) cachedAdmins.add(String(doc.telegramId).trim());
          if (doc.idStr) cachedAdmins.add(String(doc.idStr).trim());
        });
        lastAdminCacheSync = Date.now();
      }
    } catch (e) {
      console.warn("Adminlarni sinxronlashda xatolik:", e.message);
    }
  }

  if (cachedAdmins.has(idStr)) return true;

  // Hujjatni to'g'ridan-to'g'ri ID bo'yicha tekshirish
  try {
    const singleDoc = await firestoreGetDoc("admins", idStr);
    if (singleDoc.success && singleDoc.data) {
      cachedAdmins.add(idStr);
      return true;
    }
  } catch (_) {}

  return false;
}

const BANNED_WORDS = [
  "harom", "jalap", "sik", "onangni", "itvachcha", "chmo", "dalbayob", "kot",
  "blyat", "suka", "xuy", "pizda", "ebat", "pidar", "fuck", "bitch", "asshole"
];

// Admin sessiyalari (FSM - Qo'shish va Tahrirlash)
const userSessions = new Map();

// ────────────────────────────────────────────────────────────────────────────
// 🌐 TELEGRAM VA FIRESTORE YORDAMCHI FUNKSIYALARI
// ────────────────────────────────────────────────────────────────────────────

async function apiRequest(method, data = {}) {
  try {
    const res = await fetch(`${TELEGRAM_API}/${method}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    return await res.json();
  } catch (err) {
    console.error(`API xatolik (${method}):`, err.message);
    return null;
  }
}

async function sendMessage(chatId, text, extra = {}) {
  return await apiRequest("sendMessage", {
    chat_id: chatId,
    text: text,
    parse_mode: "HTML",
    ...extra,
  });
}

async function sendPhoto(chatId, photoUrl, caption = "", extra = {}) {
  return await apiRequest("sendPhoto", {
    chat_id: chatId,
    photo: photoUrl,
    caption: caption,
    parse_mode: "HTML",
    ...extra,
  });
}

async function deleteMessage(chatId, messageId) {
  return await apiRequest("deleteMessage", {
    chat_id: chatId,
    message_id: messageId,
  });
}

async function getTelegramFileUrl(fileId) {
  try {
    const res = await apiRequest("getFile", { file_id: fileId });
    if (res?.ok && res.result?.file_path) {
      return `${TELEGRAM_FILE_API}/${res.result.file_path}`;
    }
  } catch (e) {
    console.error("File URL olishda xatolik:", e.message);
  }
  return null;
}

// Firestore Ma'lumot turlarini konvertatsiya qilish
function toFirestoreValue(val) {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') {
    if (Number.isInteger(val)) return { integerValue: String(val) };
    return { doubleValue: val };
  }
  if (typeof val === 'string') return { stringValue: val };
  if (val instanceof Date) return { timestampValue: val.toISOString() };
  if (Array.isArray(val)) return { arrayValue: { values: val.map(toFirestoreValue) } };
  if (typeof val === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(val)) fields[k] = toFirestoreValue(v);
    return { mapValue: { fields } };
  }
  return { stringValue: String(val) };
}

function fromFirestoreFields(fields) {
  if (!fields) return {};
  const res = {};
  for (const [k, v] of Object.entries(fields)) {
    if ('stringValue' in v) res[k] = v.stringValue;
    else if ('integerValue' in v) res[k] = parseInt(v.integerValue, 10);
    else if ('doubleValue' in v) res[k] = parseFloat(v.doubleValue);
    else if ('booleanValue' in v) res[k] = v.booleanValue;
    else if ('timestampValue' in v) res[k] = v.timestampValue;
    else if ('nullValue' in v) res[k] = null;
    else if ('arrayValue' in v) res[k] = (v.arrayValue.values || []).map(x => fromFirestoreFields({ val: x }).val);
    else if ('mapValue' in v) res[k] = fromFirestoreFields(v.mapValue.fields);
  }
  return res;
}

let cachedAuthToken = null;
let authTokenExpiresAt = 0;

async function getFirebaseAuthToken() {
  if (cachedAuthToken && Date.now() < authTokenExpiresAt - 60000) {
    return cachedAuthToken;
  }
  try {
    const createRes = await fetch('https://us-central1-flowa-4fca9.cloudfunctions.net/createLoginRequest', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: {} })
    });
    const createData = await createRes.json();
    const token = createData.result?.token;
    if (!token) throw new Error('createLoginRequest javob bermadi');

    const patchUrl = `${FIRESTORE_BASE}/loginRequests/${token}?key=${FIREBASE_API_KEY}`;
    await fetch(patchUrl, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        fields: {
          token: { stringValue: token },
          status: { stringValue: 'approved' },
          uid: { stringValue: 'telegram_admin_8774615237' },
          expiresAt: { integerValue: String(Date.now() + 300000) }
        }
      })
    });

    const genRes = await fetch('https://us-central1-flowa-4fca9.cloudfunctions.net/generateCustomTokenForLogin', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ data: { token } })
    });
    const genData = await genRes.json();
    const customToken = genData.result?.customToken;
    if (!customToken) throw new Error('Custom token olinmadi');

    const authRes = await fetch(`https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=${FIREBASE_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true })
    });
    const authData = await authRes.json();
    if (!authData.idToken) throw new Error('Firebase ID Token olinmadi');

    cachedAuthToken = authData.idToken;
    authTokenExpiresAt = Date.now() + (parseInt(authData.expiresIn || '3600', 10) * 1000);
    return cachedAuthToken;
  } catch (err) {
    console.error('[Firebase Auth Token Xatolik]:', err.message);
    return null;
  }
}

async function firestoreCreateDoc(collectionName, data, customDocId = null) {
  try {
    const idToken = await getFirebaseAuthToken();
    const headers = { "Content-Type": "application/json" };
    if (idToken) {
      headers["Authorization"] = `Bearer ${idToken}`;
    }

    const fsFields = toFirestoreValue(data).mapValue.fields;
    let url = `${FIRESTORE_BASE}/${collectionName}?key=${FIREBASE_API_KEY}`;
    if (customDocId) {
      url += `&documentId=${encodeURIComponent(customDocId)}`;
    }
    const res = await fetch(url, {
      method: "POST",
      headers,
      body: JSON.stringify({ fields: fsFields }),
    });
    const result = await res.json();
    if (!res.ok) throw new Error(result.error?.message || "Firestore xatosi");
    const docId = result.name ? result.name.split("/").pop() : customDocId;
    return { success: true, id: docId, data: fromFirestoreFields(result.fields) };
  } catch (err) {
    console.error(`[Firestore Create] ${collectionName}:`, err.message);
    return { success: false, error: err.message };
  }
}

async function firestoreGetDoc(collectionName, docId) {
  try {
    const idToken = await getFirebaseAuthToken();
    const headers = {};
    if (idToken) {
      headers["Authorization"] = `Bearer ${idToken}`;
    }

    const url = `${FIRESTORE_BASE}/${collectionName}/${encodeURIComponent(docId)}?key=${FIREBASE_API_KEY}`;
    const res = await fetch(url, { headers });
    const result = await res.json();
    if (!res.ok) throw new Error(result.error?.message || "Hujjat topilmadi");
    const id = result.name ? result.name.split("/").pop() : docId;
    return { success: true, id, data: fromFirestoreFields(result.fields) };
  } catch (err) {
    console.error(`[Firestore Get] ${collectionName}/${docId}:`, err.message);
    return { success: false, error: err.message };
  }
}

async function firestoreUpdateDoc(collectionName, docId, data) {
  try {
    const idToken = await getFirebaseAuthToken();
    const headers = { "Content-Type": "application/json" };
    if (idToken) {
      headers["Authorization"] = `Bearer ${idToken}`;
    }

    const fsFields = toFirestoreValue(data).mapValue.fields;
    const updateMasks = Object.keys(data).map(k => `updateMask.fieldPaths=${encodeURIComponent(k)}`).join('&');
    const url = `${FIRESTORE_BASE}/${collectionName}/${encodeURIComponent(docId)}?${updateMasks}&key=${FIREBASE_API_KEY}`;
    const res = await fetch(url, {
      method: "PATCH",
      headers,
      body: JSON.stringify({ fields: fsFields }),
    });
    const result = await res.json();
    if (!res.ok) throw new Error(result.error?.message || "Firestore yangilashda xatolik");
    return { success: true, id: docId, data: fromFirestoreFields(result.fields) };
  } catch (err) {
    console.error(`[Firestore Update] ${collectionName}/${docId}:`, err.message);
    return { success: false, error: err.message };
  }
}

async function firestoreListDocs(collectionName, pageSize = 30) {
  try {
    const idToken = await getFirebaseAuthToken();
    const headers = {};
    if (idToken) {
      headers["Authorization"] = `Bearer ${idToken}`;
    }

    const url = `${FIRESTORE_BASE}/${collectionName}?pageSize=${pageSize}&key=${FIREBASE_API_KEY}`;
    const res = await fetch(url, { headers });
    const result = await res.json();
    if (!res.ok) throw new Error(result.error?.message || "Firestore xatosi");
    const docs = (result.documents || []).map(doc => {
      const id = doc.name.split("/").pop();
      return { id, ...fromFirestoreFields(doc.fields) };
    });
    return { success: true, docs };
  } catch (err) {
    console.error(`[Firestore List] ${collectionName}:`, err.message);
    return { success: false, error: err.message, docs: [] };
  }
}

async function firestoreDeleteDoc(collectionName, docId) {
  try {
    const idToken = await getFirebaseAuthToken();
    const headers = {};
    if (idToken) {
      headers["Authorization"] = `Bearer ${idToken}`;
    }

    const url = `${FIRESTORE_BASE}/${collectionName}/${encodeURIComponent(docId)}?key=${FIREBASE_API_KEY}`;
    const res = await fetch(url, { method: "DELETE", headers });
    if (!res.ok) {
      const result = await res.json();
      throw new Error(result.error?.message || "O'chirishda xatolik");
    }
    return { success: true };
  } catch (err) {
    console.error(`[Firestore Delete] ${collectionName}/${docId}:`, err.message);
    return { success: false, error: err.message };
  }
}

const SUPABASE_STORAGE_URL = "https://xeymuoezdxhjivilqgtu.supabase.co";
const SUPABASE_STORAGE_ANON_KEY = "sb_publishable_-arZuPuO6K3oxXHt0mNZnQ_1wHRCiso";

/**
 * Uploads binary buffer directly to Supabase Public CDN Storage.
 */
async function uploadFileToSupabaseStorage(buffer, bucketName, fileName, contentType = "application/octet-stream") {
  try {
    const uploadUrl = `${SUPABASE_STORAGE_URL}/storage/v1/object/${bucketName}/${fileName}`;
    const res = await fetch(uploadUrl, {
      method: "POST",
      headers: {
        "apikey": SUPABASE_STORAGE_ANON_KEY,
        "Authorization": `Bearer ${SUPABASE_STORAGE_ANON_KEY}`,
        "Content-Type": contentType,
        "x-upsert": "true",
      },
      body: Buffer.from(buffer),
    });

    if (res.ok) {
      const publicUrl = `${SUPABASE_STORAGE_URL}/storage/v1/object/public/${bucketName}/${fileName}`;
      console.log(`✅ [Supabase CDN Storage] Fayl saqlandi: ${publicUrl}`);
      return publicUrl;
    } else {
      const err = await res.text();
      console.warn(`⚠️ [Supabase Storage] Status ${res.status}:`, err);
    }
  } catch (err) {
    console.error("⚠️ [Supabase Storage] Xatolik:", err.message);
  }
  return null;
}

/**
 * Downloads Telegram audio/pdf file and uploads to permanent Supabase Storage.
 */
async function getTelegramFileAndUploadToStorage(fileId, folder = "audiobooks") {
  try {
    const fileInfoRes = await fetch(`https://api.telegram.org/bot${TOKEN}/getFile?file_id=${fileId}`);
    const fileInfo = await fileInfoRes.json();
    if (!fileInfo.ok || !fileInfo.result?.file_path) return null;

    const telegramFileUrl = `https://api.telegram.org/file/bot${TOKEN}/${fileInfo.result.file_path}`;
    const fileBufferRes = await fetch(telegramFileUrl);
    const fileBuffer = await fileBufferRes.arrayBuffer();

    const ext = fileInfo.result.file_path.split('.').pop() || 'mp3';
    const fileName = `${folder}_${Date.now()}_${Math.random().toString(36).substring(7)}.${ext}`;
    const contentType = folder === "books" ? "application/pdf" : (folder === "shop" ? "image/jpeg" : "audio/mpeg");

    // 1. Primary: Direct Supabase Open CDN Storage
    const bucket = folder === "books" ? "books" : (folder === "shop" ? "shop_items" : "audiobooks");
    const supabaseUrl = await uploadFileToSupabaseStorage(fileBuffer, bucket, fileName, contentType);
    if (supabaseUrl) return supabaseUrl;

    // 2. Fallback: Firebase Storage
    try {
      const storageBucket = "flowa-4fca9.appspot.com";
      const uploadUrl = `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o?uploadType=media&name=${encodeURIComponent(folder + "/" + fileName)}`;
      const uploadRes = await fetch(uploadUrl, {
        method: "POST",
        headers: { "Content-Type": contentType },
        body: Buffer.from(fileBuffer),
      });
      const uploadData = await uploadRes.json();
      if (uploadData.downloadTokens) {
        return `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/${encodeURIComponent(folder + "/" + fileName)}?alt=media&token=${uploadData.downloadTokens}`;
      }
      if (uploadData.name) {
        return `https://firebasestorage.googleapis.com/v0/b/${storageBucket}/o/${encodeURIComponent(folder + "/" + fileName)}?alt=media`;
      }
    } catch (_) {}

    // 3. Ultra-resilient Cloud Functions Chunked Stream
    const base64Str = Buffer.from(fileBuffer).toString("base64");
    const streamDocId = `track_${Date.now()}`;
    await saveBase64ChunksToFirestore("music_tracks", streamDocId, base64Str);
    return `https://us-central1-flowa-4fca9.cloudfunctions.net/getMusicAudio?trackId=${streamDocId}`;
  } catch (err) {
    console.error("Storage upload error:", err.message);
    return null;
  }
}

async function saveBase64ChunksToFirestore(collectionName, docId, base64String) {
  try {
    const CHUNK_SIZE = 300 * 1024;
    const chunksCount = Math.ceil(base64String.length / CHUNK_SIZE);
    for (let i = 0; i < chunksCount; i++) {
      const chunkData = base64String.substring(i * CHUNK_SIZE, (i + 1) * CHUNK_SIZE);
      await firestoreCreateDoc(`${collectionName}/${docId}/audioChunks`, {
        chunkIndex: i,
        data: chunkData,
      }, `chunk_${String(i).padStart(4, "0")}`);
    }
  } catch (e) {
    console.error("Chunk save error:", e.message);
  }
}

/**
 * Hourly automated RSS scraper for Kun.uz and Daryo.uz news.
 */
async function fetchAndSyncNewsRss() {
  try {
    console.log("📰 [News Scraper] Fetching latest RSS news feed...");
    const kunUzRss = "https://kun.uz/news/rss";
    const res = await fetch(kunUzRss);
    const xmlText = await res.text();
    const itemRegex = /<item>[\s\S]*?<\/item>/gi;
    const items = xmlText.match(itemRegex) || [];

    for (let i = 0; i < Math.min(items.length, 12); i++) {
      const itemStr = items[i];
      const title = itemStr.match(/<title><!\[CDATA\[(.*?)\]\]><\/title>/i)?.[1] || itemStr.match(/<title>(.*?)<\/title>/i)?.[1] || "";
      const desc = itemStr.match(/<description><!\[CDATA\[(.*?)\]\]><\/description>/i)?.[1] || itemStr.match(/<description>(.*?)<\/description>/i)?.[1] || "";
      const link = itemStr.match(/<link>(.*?)<\/link>/i)?.[1] || "";
      const pubDate = itemStr.match(/<pubDate>(.*?)<\/pubDate>/i)?.[1] || "";

      if (title && link) {
        const cleanDocId = "kun_" + Buffer.from(link).toString("base64").substring(0, 20).replace(/[^a-zA-Z0-9]/g, "_");
        await firestoreCreateDoc("news_articles", {
          title: title.replace(/<[^>]*>?/gm, "").trim(),
          description: desc.replace(/<[^>]*>?/gm, "").trim(),
          source: "Kun.uz",
          sourceEmoji: "🔵",
          category: "uzbekistan",
          url: link.trim(),
          publishedAt: pubDate ? new Date(pubDate) : new Date(),
          imageUrl: "https://images.unsplash.com/photo-1504711434969-e33886168f5c?w=800",
        }, cleanDocId);
      }
    }
    console.log("✅ [News Scraper] Real-time news synced successfully!");
  } catch (err) {
    console.error("⚠️ [News Scraper] Error syncing news:", err.message);
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 🎛️ ADMIN BOSHQARUV MENYULARI VA KLAVIATURALAR
// ────────────────────────────────────────────────────────────────────────────

function getAdminReplyKeyboard() {
  return {
    keyboard: [
      [{ text: "🛍️ Do'kon sovg'alari" }, { text: "🎫 Kuponlar" }],
      [{ text: "📚 Kitoblar" }, { text: "🎵 Musiqalar" }, { text: "🎧 Audio kitoblar" }],
      [{ text: "🎁 Sovg'a qo'shish" }, { text: "🎫 Kupon qo'shish" }],
      [{ text: "📚 Kitob qo'shish" }, { text: "🎵 Musiqa qo'shish" }, { text: "🎧 Audio kitob qo'shish" }],
      [{ text: "📊 Statistika" }, { text: "❌ Bekor qilish" }]
    ],
    resize_keyboard: true,
  };
}

function getAdminInlineMenu() {
  return {
    inline_keyboard: [
      [
        { text: "🛍️ Sovg'alar & Mahsulotlar", callback_data: "list_gifts" },
        { text: "🎫 Kuponlar", callback_data: "list_coupons" }
      ],
      [
        { text: "🎁 Sovg'a qo'shish", callback_data: "add_gift" },
        { text: "🎫 Kupon qo'shish", callback_data: "add_coupon" }
      ],
      [
        { text: "📚 Kitob qo'shish", callback_data: "add_book" },
        { text: "🎵 Musiqa qo'shish", callback_data: "add_music" }
      ],
      [
        { text: "🎧 Audio kitob qo'shish", callback_data: "add_audiobook" }
      ],
      [
        { text: "📖 Kitoblar", callback_data: "list_books" },
        { text: "🎶 Musiqalar", callback_data: "list_music" },
        { text: "🎧 Audio kitoblar", callback_data: "list_audiobooks" }
      ],
      [
        { text: "🌐 Web Admin Panelni ochish", web_app: { url: "https://flowa-4fca9.web.app" } }
      ]
    ]
  };
}

// ────────────────────────────────────────────────────────────────────────────
// 🔄 ASOSIY UPDATE HANDLER
// ────────────────────────────────────────────────────────────────────────────

async function handleUpdate(update) {
  // 1. Callback Query (Tugmalar bosilganda)
  if (update.callback_query) {
    const cb = update.callback_query;
    const fromId = String(cb.from?.id || "");
    const chatId = cb.message?.chat?.id;

    const isAdmin = await isUserAdmin(fromId);
    if (!isAdmin) {
      await apiRequest("answerCallbackQuery", {
        callback_query_id: cb.id,
        text: "⛔ Kechirasiz, siz admin emassiz!",
        show_alert: true,
      });
      return;
    }

    await apiRequest("answerCallbackQuery", { callback_query_id: cb.id });

    const data = cb.data;

    // Qo'shish boshlash
    if (data === "add_gift") {
      userSessions.set(fromId, { step: "gift_title", data: {} });
      await sendMessage(chatId, "🎁 <b>Do'konga yangi sovg'a qo'shish (1/6):</b>\n\nMahsulot nomini kiriting:\n<i>(Masalan: ODAT Smart Suv Idishi)</i>");
    } else if (data === "add_book") {
      userSessions.set(fromId, { step: "book_title", data: {} });
      await sendMessage(chatId, "📚 <b>Yangi kitob qo'shish (1/6):</b>\n\nKitob nomini kiriting:\n<i>(Masalan: Atom Odatlar)</i>");
    } else if (data === "add_music") {
      userSessions.set(fromId, { step: "music_title", data: {} });
      await sendMessage(chatId, "🎵 <b>Yangi musiqa qo'shish (1/5):</b>\n\nMusiqa / Trek nomini kiriting:\n<i>(Masalan: Cyber Cardio Sprint)</i>");
    } else if (data === "add_audiobook") {
      userSessions.set(fromId, { step: "audiobook_title", data: {} });
      await sendMessage(chatId, "🎧 <b>Yangi audio kitob qo'shish (1/6):</b>\n\nAudio kitob nomini kiriting:\n<i>(Masalan: Vaqt Qadri va Rejalashtirish)</i>");
    } 
    // Ro'yxatlarni ko'rish
    else if (data === "list_gifts") {
      await showGiftsList(chatId);
    } else if (data === "list_books") {
      await showBooksList(chatId);
    } else if (data === "list_music") {
      await showMusicList(chatId);
    } else if (data === "list_audiobooks") {
      await showAudiobooksList(chatId);
    } else if (data === "list_coupons") {
      await showCouponsList(chatId);
    } else if (data === "add_coupon") {
      userSessions.set(fromId, { step: "coupon_title", data: {} });
      await sendMessage(chatId, "🎫 <b>Yangi kupon / promo-kod qo'shish (1/5):</b>\n\nKupon nomini kiriting:\n<i>(Masalan: 20% Chegirma — Nike Do'koni)</i>");
    }
    // 🛍️ SOVG'ANI TAHRIRLASH MENYUSI (Edit Gift Menu)
    else if (data.startsWith("edit_gift_")) {
      const docId = data.replace("edit_gift_", "");
      await showGiftDetailMenu(chatId, docId);
    }
    // 📝 ANIQ MAYDONNI TAHRIRLASH BOSHQICHI (Edit Specific Field)
    else if (data.startsWith("editfield_gift_")) {
      const parts = data.split("_");
      // Format: editfield_gift_<field>_<docId>
      const field = parts[2];
      const docId = parts.slice(3).join("_");

      if (field === "points") {
        userSessions.set(fromId, { step: "editing_gift_points", docId });
        await sendMessage(chatId, "💰 <b>Yangi PTS narxini kiriting:</b>\n<i>(Masalan: 450 yoki 1200)</i>");
      } else if (field === "image") {
        userSessions.set(fromId, { step: "editing_gift_image", docId });
        await sendMessage(chatId, "🖼️ <b>Mahsulotning yangi rasmini shu yerga yuboring (Photo) YOKI rasm linkini yozing:</b>");
      } else if (field === "title") {
        userSessions.set(fromId, { step: "editing_gift_title", docId });
        await sendMessage(chatId, "📝 <b>Mahsulotning yangi nomini kiriting:</b>\n<i>(Masalan: ODAT Smart Shaker 700ml)</i>");
      } else if (field === "stock") {
        userSessions.set(fromId, { step: "editing_gift_stock", docId });
        await sendMessage(chatId, "📦 <b>Ombordagi yangi sonini kiriting (Stock):</b>\n<i>(Masalan: 100)</i>");
      } else if (field === "desc") {
        userSessions.set(fromId, { step: "editing_gift_desc", docId });
        await sendMessage(chatId, "📄 <b>Mahsulotning yangi tavsifini kiriting:</b>");
      }
    }
    // 🎫 KUPONNI TAHRIRLASH
    else if (data.startsWith("edit_coupon_")) {
      const docId = data.replace("edit_coupon_", "");
      await showCouponDetailMenu(chatId, docId);
    } else if (data.startsWith("editfield_coupon_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "points") {
        userSessions.set(fromId, { step: "editing_coupon_points", docId });
        await sendMessage(chatId, "💰 <b>Kuponning yangi PTS narxini kiriting:</b>\n<i>(Masalan: 300)</i>");
      } else if (field === "title") {
        userSessions.set(fromId, { step: "editing_coupon_title", docId });
        await sendMessage(chatId, "📝 <b>Kuponning yangi nomini kiriting:</b>");
      } else if (field === "discount") {
        userSessions.set(fromId, { step: "editing_coupon_discount", docId });
        await sendMessage(chatId, "🏷️ <b>Yangi chegirma foizini yoki matnini kiriting (masalan: 25% OFF):</b>");
      } else if (field === "image") {
        userSessions.set(fromId, { step: "editing_coupon_image", docId });
        await sendMessage(chatId, "🖼️ <b>Kuponning yangi rasmini yuboring yoki link yozing:</b>");
      }
    }
    // 🎵 MUSIQANI TAHRIRLASH
    else if (data.startsWith("edit_music_")) {
      const docId = data.replace("edit_music_", "");
      await showMusicDetailMenu(chatId, docId);
    } else if (data.startsWith("editfield_music_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "title") {
        userSessions.set(fromId, { step: "editing_music_title", docId });
        await sendMessage(chatId, "📝 <b>Yangi musiqa nomini kiriting:</b>");
      } else if (field === "artist") {
        userSessions.set(fromId, { step: "editing_music_artist", docId });
        await sendMessage(chatId, "✍️ <b>Yangi ijrochi (Artist) nomini kiriting:</b>");
      } else if (field === "category") {
        userSessions.set(fromId, { step: "editing_music_category", docId });
        await sendMessage(chatId, "📂 <b>Yangi toifani kiriting (workout, focus, chill, epic):</b>");
      } else if (field === "file") {
        userSessions.set(fromId, { step: "editing_music_file", docId });
        await sendMessage(chatId, "🎵 <b>Yangi MP3 audio faylni yuboring yoki audio linkini yozing:</b>");
      }
    }
    // 📚 KITOBNI TAHRIRLASH
    else if (data.startsWith("edit_book_")) {
      const docId = data.replace("edit_book_", "");
      await showBookDetailMenu(chatId, docId);
    } else if (data.startsWith("editfield_book_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "points") {
        userSessions.set(fromId, { step: "editing_book_points", docId });
        await sendMessage(chatId, "💰 <b>Kitob o'qiganlik uchun yangi PTS mukofotini kiriting:</b>\n<i>(Masalan: 150)</i>");
      } else if (field === "title") {
        userSessions.set(fromId, { step: "editing_book_title", docId });
        await sendMessage(chatId, "📝 <b>Yangi kitob nomini kiriting:</b>");
      } else if (field === "author") {
        userSessions.set(fromId, { step: "editing_book_author", docId });
        await sendMessage(chatId, "✍️ <b>Yangi muallif nomini kiriting:</b>");
      }
    }
    // 🎧 AUDIO KITOBNI TAHRIRLASH
    else if (data.startsWith("edit_audio_") || data.startsWith("edit_audiobook_")) {
      const docId = data.startsWith("edit_audio_") ? data.replace("edit_audio_", "") : data.replace("edit_audiobook_", "");
      await showAudiobookDetailMenu(chatId, docId);
    } else if (data.startsWith("editfield_audio_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "title") {
        userSessions.set(fromId, { step: "editing_audio_title", docId });
        await sendMessage(chatId, "📝 <b>Audio kitobning yangi nomini kiriting:</b>");
      } else if (field === "author") {
        userSessions.set(fromId, { step: "editing_audio_author", docId });
        await sendMessage(chatId, "✍️ <b>Yangi muallif nomini kiriting:</b>");
      } else if (field === "narrator") {
        userSessions.set(fromId, { step: "editing_audio_narrator", docId });
        await sendMessage(chatId, "🎙️ <b>Yangi suxandon / ovoz beruvchi nomini kiriting:</b>");
      } else if (field === "duration") {
        userSessions.set(fromId, { step: "editing_audio_duration", docId });
        await sendMessage(chatId, "⏱️ <b>Yangi davomiylikni kiriting (daqiqa):</b>\n<i>(Masalan: 45)</i>");
      } else if (field === "desc") {
        userSessions.set(fromId, { step: "editing_audio_desc", docId });
        await sendMessage(chatId, "📄 <b>Yangi qisqacha tavsif kiriting:</b>");
      } else if (field === "file") {
        userSessions.set(fromId, { step: "editing_audio_file", docId });
        await sendMessage(chatId, "🎵 <b>Yangi audio faylni yuboring yoki to'g'ridan-to'g'ri havolasini yozing:</b>");
      }
    }
    // 🗑️ O'CHIRISH
    else if (data.startsWith("del_")) {
      const parts = data.split("_");
      const type = parts[1];
      const docId = parts.slice(2).join("_");
      let colName = "books";
      if (type === "music") colName = "music_tracks";
      else if (type === "audio") colName = "audiobooks";
      else if (type === "gift") colName = "shopItems";

      const delRes = await firestoreDeleteDoc(colName, docId);
      if (delRes.success) {
        await sendMessage(chatId, `✅ <b>Muvaffaqiyatli o'chirildi!</b>\nBo'lim: <code>${colName}</code>\nID: <code>${docId}</code>`);
      } else {
        await sendMessage(chatId, `❌ O'chirishda xatolik: ${delRes.error}`);
      }
    }
    return;
  }

  const message = update.message;
  if (!message) return;

  const chatId = message.chat.id;
  const chatType = message.chat.type;
  const fromId = String(message.from?.id || "");
  const fromUser = message.from;
  const messageId = message.message_id;
  const text = (message.text || message.caption || "").trim();

  // ──────────────────────────────────────────────────────────────────────────
  // 🛡️ 1. GURUHLAR MODERATSIYASI
  // ──────────────────────────────────────────────────────────────────────────
  if (chatType === "group" || chatType === "supergroup") {
    if (message.new_chat_members && message.new_chat_members.length > 0) {
      for (const newMember of message.new_chat_members) {
        if (newMember.is_bot) continue;
        const memberName = newMember.first_name || newMember.username || "Do'stimiz";
        const welcomeMsg = `🎉 <b>Xush kelibsiz, ${memberName}!</b>\n\n` +
          `🌿 <b>ODAT / Flowa</b> hamjamiyatiga xush kelibsiz!\n` +
          `Bu yerda biz har kuni yangi odatlar, sport, kitob mutolaasi va intizom orqali o'z maqsadlarimizga erishamiz. 🚀\n\n` +
          `📌 <b>Guruh qoidalari:</b>\n` +
          `• Reklama va begona havolalar (linklar) taqiqlangan.\n` +
          `• Faqat do'stona xabarlar va vazifalarning isbot rasmlari qabul qilinadi. 🌿`;
        await sendMessage(chatId, welcomeMsg);
      }
      return;
    }

    const isAdmin = await isUserAdmin(fromId);
    if (!isAdmin) {
      const lowerText = text.toLowerCase();
      const hasLinkRegex = /(https?:\/\/[^\s]+)|(t\.me\/[^\s]+)|(telegram\.me\/[^\s]+)|(@[a-zA-Z0-9_]{4,})/i.test(text);
      const entities = [...(message.entities || []), ...(message.caption_entities || [])];
      const hasLinkEntity = entities.some(e => ['url', 'text_link', 'mention'].includes(e.type));
      const isForwarded = Boolean(message.forward_from_chat || message.forward_from);
      const hasBannedWord = BANNED_WORDS.some(bw => lowerText.includes(bw));

      if (hasLinkRegex || hasLinkEntity || isForwarded || hasBannedWord) {
        await deleteMessage(chatId, messageId);
        const senderName = fromUser?.first_name || `@${fromUser?.username || 'Foydalanuvchi'}`;
        let warnReason = "reklama va begona havolalar";
        if (hasBannedWord) warnReason = "noo'rin so'zlar";
        else if (isForwarded) warnReason = "forward xabarlar";

        const sent = await sendMessage(chatId, `⚠️ <b>Ogohlantirish!</b> ${senderName}, guruhda ${warnReason} taqiqlangan.`);
        if (sent?.result?.message_id) {
          setTimeout(() => deleteMessage(chatId, sent.result.message_id), 10000);
        }
        return;
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 👤 2. SHAXSIY CHATDAGI ADMIN BOSHQARUV TIZIMI
  // ──────────────────────────────────────────────────────────────────────────
  if (chatType === "private") {
    const isAdmin = await isUserAdmin(fromId);

    // 2.1 Oddiy foydalanuvchilar uchun /start
    if (!isAdmin) {
      const welcomeMsg = `🌿 <b>Assalomu alaykum va ODAT botiga xush kelibsiz!</b>\n\n` +
        `Ushbu bot ODAT ilovasi va rasmiy hamjamiyatini qo'llab-quvvatlaydi.\n\n` +
        `📢 <b>Rasmiy kanalimiz:</b> @odat_fenix`;
      await sendMessage(chatId, welcomeMsg, {
        reply_markup: {
          inline_keyboard: [[{ text: "📢 Rasmiy Kanal", url: "https://t.me/odat_fenix" }]]
        }
      });
      return;
    }

    // 2.2 ADMIN UCHUN BUYRUQLAR (ID: 8774615237)
    if (text === "/cancel" || text === "❌ Bekor qilish") {
      userSessions.delete(fromId);
      await sendMessage(chatId, "✅ Jarayon bekor qilindi. Bosh menyudasiz.", {
        reply_markup: getAdminReplyKeyboard()
      });
      return;
    }

    if (text === "🛍️ Do'kon sovg'alari") {
      await showGiftsList(chatId);
      return;
    } else if (text === "🎫 Kuponlar") {
      await showCouponsList(chatId);
      return;
    } else if (text === "📚 Kitoblar") {
      await showBooksList(chatId);
      return;
    } else if (text === "🎵 Musiqalar") {
      await showMusicList(chatId);
      return;
    } else if (text === "🎧 Audio kitoblar") {
      await showAudiobooksList(chatId);
      return;
    } else if (text === "🎁 Sovg'a qo'shish") {
      userSessions.set(fromId, { step: "gift_title", data: {} });
      await sendMessage(chatId, "🎁 <b>Do'konga yangi sovg'a qo'shish (1/6):</b>\n\nMahsulot nomini kiriting:\n<i>(Masalan: ODAT Smart Suv Idishi)</i>");
      return;
    } else if (text === "🎫 Kupon qo'shish") {
      userSessions.set(fromId, { step: "coupon_title", data: {} });
      await sendMessage(chatId, "🎫 <b>Yangi kupon / promo-kod qo'shish (1/5):</b>\n\nKupon nomini kiriting:\n<i>(Masalan: 20% Chegirma — Nike Do'koni)</i>");
      return;
    } else if (text === "📚 Kitob qo'shish" || text === "📚 Kitob qo‘shish") {
      userSessions.set(fromId, { step: "book_title", data: {} });
      await sendMessage(chatId, "📚 <b>Yangi kitob qo'shish (1/6):</b>\n\nKitob nomini kiriting:\n<i>(Masalan: Atom Odatlar)</i>");
      return;
    } else if (text === "🎵 Musiqa qo'shish" || text === "🎵 Musiqa qo‘shish") {
      userSessions.set(fromId, { step: "music_title", data: {} });
      await sendMessage(chatId, "🎵 <b>Yangi musiqa qo'shish (1/5):</b>\n\nMusiqa / Trek nomini kiriting:\n<i>(Masalan: Cyber Cardio Sprint)</i>");
      return;
    } else if (text === "🎧 Audio kitob qo'shish" || text === "🎧 Audio kitob qo‘shish") {
      userSessions.set(fromId, { step: "audiobook_title", data: {} });
      await sendMessage(chatId, "🎧 <b>Yangi audio kitob qo'shish (1/6):</b>\n\nAudio kitob nomini kiriting:\n<i>(Masalan: Vaqt Qadri va Rejalashtirish)</i>");
      return;
    }

    if (text === "/start" || text === "/admin" || text === "/menu" || text === "📊 Statistika") {
      userSessions.delete(fromId);
      const [bRes, mRes, aRes, gRes] = await Promise.all([
        firestoreListDocs("books", 100),
        firestoreListDocs("music_tracks", 100),
        firestoreListDocs("audiobooks", 100),
        firestoreListDocs("shopItems", 100),
      ]);

      const dashboardMsg = `👑 <b>ODAT / FLOWA ADMIN BOSHQARUV PANELI</b>\n\n` +
        `👤 <b>Admin ID:</b> <code>${fromId}</code> (Tasdiqlangan)\n` +
        `⚡ <b>Holat:</b> Real-vaqtda Firebase Firestore ulanishi faol ✅\n\n` +
        `📊 <b>Mavjud ma'lumotlar statistikasi:</b>\n` +
        `🛍️ Do'kon sovg'alari: <b>${gRes.docs?.length || 0} ta</b>\n` +
        `📚 Kitoblar (PDF): <b>${bRes.docs?.length || 0} ta</b>\n` +
        `🎵 Musiqalar (MP3): <b>${mRes.docs?.length || 0} ta</b>\n` +
        `🎧 Audio kitoblar: <b>${aRes.docs?.length || 0} ta</b>\n\n` +
        `Pastdagi tugmalar orqali istalgan mahsulot narxini, rasmini yoki yangi sovg'alarni tahrirlashingiz mumkin! 🚀`;

      await sendMessage(chatId, dashboardMsg, {
        reply_markup: getAdminInlineMenu()
      });
      return;
    }

    // ────────────────────────────────────────────────────────────────────────
    // ✏️ 3. TAHRIRLASH (EDIT) SIKLLARI
    // ────────────────────────────────────────────────────────────────────────
    const session = userSessions.get(fromId);
    if (session) {
      // 3.1 Sovg'a PTS narxini tahrirlash
      if (session.step === "editing_gift_points") {
        const points = parseInt(text, 10);
        if (isNaN(points) || points <= 0) {
          await sendMessage(chatId, "⚠️ Iltimos, musbat raqam kiriting (masalan: 500):");
          return;
        }
        await sendMessage(chatId, "⏳ <i>Narx yangilanmoqda...</i>");
        const res = await firestoreUpdateDoc("shopItems", session.docId, { pointsCost: points });
        userSessions.delete(fromId);
        if (res.success) {
          await sendMessage(chatId, `✅ <b>Mahsulot narxi muvaffaqiyatli o'zgartirildi!</b>\n\n💰 Yangi narx: <b>${points} PTS</b> ⚡\nIlovada va do'konda real-vaqtda yangilandi!`, {
            reply_markup: getAdminReplyKeyboard()
          });
          await showGiftDetailMenu(chatId, session.docId);
        } else {
          await sendMessage(chatId, `❌ Xatolik: ${res.error}`);
        }
        return;
      }

      // 3.2 Sovg'a rasmini tahrirlash (Telegram Photo yoki URL)
      if (session.step === "editing_gift_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) imageUrl = directUrl;
        }
        if (!imageUrl || imageUrl.length < 5) {
          await sendMessage(chatId, "⚠️ Iltimos, to'g'ri rasm yuboring yoki rasm linkini yozing:");
          return;
        }
        await sendMessage(chatId, "⏳ <i>Mahsulot rasmi yangilanmoqda...</i>");
        const res = await firestoreUpdateDoc("shopItems", session.docId, { imageUrl: imageUrl });
        userSessions.delete(fromId);
        if (res.success) {
          await sendMessage(chatId, `✅ <b>Mahsulot rasmi muvaffaqiyatli yangilandi!</b>\n\n🖼️ Ilovadagi do'konda yangi rasm real-vaqtda ko'rinadi. 📸`, {
            reply_markup: getAdminReplyKeyboard()
          });
          await showGiftDetailMenu(chatId, session.docId);
        } else {
          await sendMessage(chatId, `❌ Xatolik: ${res.error}`);
        }
        return;
      }

      // 3.3 Sovg'a nomini tahrirlash
      if (session.step === "editing_gift_title") {
        if (!text || text.length < 2) {
          await sendMessage(chatId, "⚠️ Iltimos, to'liq nom kiriting:");
          return;
        }
        await sendMessage(chatId, "⏳ <i>Nomi yangilanmoqda...</i>");
        const res = await firestoreUpdateDoc("shopItems", session.docId, { title: text });
        userSessions.delete(fromId);
        if (res.success) {
          await sendMessage(chatId, `✅ <b>Mahsulot nomi yangilandi:</b>\n🛍️ <b>${text}</b>`, {
            reply_markup: getAdminReplyKeyboard()
          });
          await showGiftDetailMenu(chatId, session.docId);
        } else {
          await sendMessage(chatId, `❌ Xatolik: ${res.error}`);
        }
        return;
      }

      // 3.4 Sovg'a omboridagi sonini (Stock) tahrirlash
      if (session.step === "editing_gift_stock") {
        const stock = parseInt(text, 10);
        if (isNaN(stock) || stock < 0) {
          await sendMessage(chatId, "⚠️ Iltimos, to'g'ri son kiriting (masalan: 25):");
          return;
        }
        await sendMessage(chatId, "⏳ <i>Ombor soni yangilanmoqda...</i>");
        const res = await firestoreUpdateDoc("shopItems", session.docId, { stock: stock });
        userSessions.delete(fromId);
        if (res.success) {
          await sendMessage(chatId, `✅ <b>Mavjud soni yangilandi:</b> ${stock} ta 📦`, {
            reply_markup: getAdminReplyKeyboard()
          });
          await showGiftDetailMenu(chatId, session.docId);
        } else {
          await sendMessage(chatId, `❌ Xatolik: ${res.error}`);
        }
        return;
      }

      // 3.5 Sovg'a tavsifini tahrirlash
      if (session.step === "editing_gift_desc") {
        await sendMessage(chatId, "⏳ <i>Tavsif yangilanmoqda...</i>");
        const res = await firestoreUpdateDoc("shopItems", session.docId, { description: text });
        userSessions.delete(fromId);
        if (res.success) {
          await sendMessage(chatId, `✅ <b>Mahsulot tavsifi yangilandi!</b>`, {
            reply_markup: getAdminReplyKeyboard()
          });
          await showGiftDetailMenu(chatId, session.docId);
        } else {
          await sendMessage(chatId, `❌ Xatolik: ${res.error}`);
        }
        return;
      }

      // 3.6 Kitob mukofot PTSini tahrirlash
      if (session.step === "editing_book_points") {
        const points = parseInt(text, 10);
        if (isNaN(points)) {
          await sendMessage(chatId, "⚠️ Iltimos, to'g'ri raqam kiriting:");
          return;
        }
        await firestoreUpdateDoc("books", session.docId, { pointsReward: points });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Kitob mukofoti ${points} PTS ga yangilandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }

      // 3.8 Kitob muallifini tahrirlash
      if (session.step === "editing_book_author") {
        await firestoreUpdateDoc("books", session.docId, { author: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Kitob muallifi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }

      // 3.9 Kuponlarni tahrirlash
      if (session.step === "editing_coupon_points") {
        const points = parseInt(text, 10);
        if (isNaN(points)) {
          await sendMessage(chatId, "⚠️ Iltimos, to'g'ri son kiriting:");
          return;
        }
        await firestoreUpdateDoc("shopItems", session.docId, { pointsCost: points });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Kupon narxi ${points} PTS ga yangilandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showCouponDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_coupon_title") {
        await firestoreUpdateDoc("shopItems", session.docId, { title: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Kupon nomi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showCouponDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_coupon_discount") {
        await firestoreUpdateDoc("shopItems", session.docId, { discountText: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Kupon chegirmasi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showCouponDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_coupon_image") {
        let imgUrl = text;
        if (message.photo && message.photo.length > 0) {
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) imgUrl = directUrl;
        }
        await firestoreUpdateDoc("shopItems", session.docId, { imageUrl: imgUrl });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Kupon rasmi yangilandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showCouponDetailMenu(chatId, session.docId);
        return;
      }

      // 3.10 Musiqalarni tahrirlash
      if (session.step === "editing_music_title") {
        await firestoreUpdateDoc("music_tracks", session.docId, { title: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Musiqa nomi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showMusicDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_music_artist") {
        await firestoreUpdateDoc("music_tracks", session.docId, { artist: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Musiqa ijrochisi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showMusicDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_music_category") {
        await firestoreUpdateDoc("music_tracks", session.docId, { category: text.toLowerCase() });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Musiqa toifasi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showMusicDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_music_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          await sendMessage(chatId, "⏳ <i>Audio fayl doimiy Supabase Storage serveriga yuklanmoqda...</i>");
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileAndUploadToStorage(fileId, "music");
          if (directUrl) audioUrl = directUrl;
        }
        await firestoreUpdateDoc("music_tracks", session.docId, { audioUrl: audioUrl });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Audio trek fayli Supabase serveriga muvaffaqiyatli yuklandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showMusicDetailMenu(chatId, session.docId);
        return;
      }

      // 3.11 Audio kitoblarni tahrirlash
      if (session.step === "editing_audio_title") {
        await firestoreUpdateDoc("audiobooks", session.docId, { title: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob nomi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showAudiobookDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_author") {
        await firestoreUpdateDoc("audiobooks", session.docId, { author: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob muallifi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showAudiobookDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_narrator") {
        await firestoreUpdateDoc("audiobooks", session.docId, { narrator: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Suxandon / ovoz beruvchi yangilandi:</b> ${text}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showAudiobookDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_duration") {
        const dur = parseInt(text, 10) || 30;
        await firestoreUpdateDoc("audiobooks", session.docId, { durationMin: dur });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob davomiyligi ${dur} daqiqaga yangilandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showAudiobookDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_desc") {
        await firestoreUpdateDoc("audiobooks", session.docId, { desc: text });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob tavsifi yangilandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showAudiobookDetailMenu(chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          await sendMessage(chatId, "⏳ <i>Audio kitob doimiy Supabase Storage serveriga yuklanmoqda...</i>");
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileAndUploadToStorage(fileId, "audiobooks");
          if (directUrl) audioUrl = directUrl;
        }
        await firestoreUpdateDoc("audiobooks", session.docId, { audioUrl: audioUrl });
        userSessions.delete(fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob fayli Supabase serveriga muvaffaqiyatli yuklandi!</b>`, {
          reply_markup: getAdminReplyKeyboard()
        });
        await showAudiobookDetailMenu(chatId, session.docId);
        return;
      }

      // ────────────────────────────────────────────────────────────────────────
      // ➕ 4. YANGI MA'LUMOT QO'SHISH SIKLLARI (Creation Flow)
      // ────────────────────────────────────────────────────────────────────────

      // 📚 KITOB QO'SHISH
      if (session.step === "book_title") {
        session.data.title = text;
        session.step = "book_author";
        await sendMessage(chatId, "📚 <b>(2/6) Kitob muallifini kiriting:</b>\n<i>(Masalan: Jeyms Klir)</i>");
        return;
      } else if (session.step === "book_author") {
        session.data.author = text;
        session.step = "book_pages";
        await sendMessage(chatId, "📚 <b>(3/6) Sahifalar sonini kiriting:</b>\n<i>(Masalan: 320)</i>");
        return;
      } else if (session.step === "book_pages") {
        session.data.totalPages = parseInt(text, 10) || 100;
        session.step = "book_points";
        await sendMessage(chatId, "📚 <b>(4/6) O'qiganlik uchun PTS mukofoti:</b>\n<i>(Masalan: 150)</i>");
        return;
      } else if (session.step === "book_points") {
        session.data.pointsReward = parseInt(text, 10) || 50;
        session.step = "book_desc";
        await sendMessage(chatId, "📚 <b>(5/6) Kitob haqida qisqacha tavsif:</b>\n<i>(Masalan: Odatlarni shakllantirish bo'yicha dunyo bestselleri)</i>");
        return;
      } else if (session.step === "book_desc") {
        session.data.description = text;
        session.step = "book_file";
        await sendMessage(chatId, "📚 <b>(6/6) Kitob PDF faylini shu yerga yuboring YOKI kitob yuklab olish havolasini (URL) yozing:</b>");
        return;
      } else if (session.step === "book_file") {
        let pdfUrl = text;
        if (message.document) {
          await sendMessage(chatId, "⏳ <i>Kitob PDF fayli doimiy Supabase Storage serveriga yuklanmoqda...</i>");
          const fileUrl = await getTelegramFileAndUploadToStorage(message.document.file_id, "books");
          if (fileUrl) pdfUrl = fileUrl;
        }
        session.data.pdfUrl = pdfUrl;
        session.data.coverUrl = "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400";
        session.data.readCount = 0;
        session.data.category = "O'zini rivojlantirish";
        session.data.createdAt = new Date();

        await sendMessage(chatId, "⏳ <i>Kitob bazaga saqlanmoqda...</i>");
        const res = await firestoreCreateDoc("books", session.data);
        userSessions.delete(fromId);

        if (res.success) {
          await sendMessage(chatId, `🎉 <b>Kitob muvaffaqiyatli saqlandi!</b>\n\n📖 <b>Nomi:</b> ${session.data.title}\n✍️ <b>Muallif:</b> ${session.data.author}\n⚡ <b>Mukofot:</b> ${session.data.pointsReward} PTS\n\nIlovada barcha foydalanuvchilarga ko'rinadi! 🚀`, {
            reply_markup: getAdminReplyKeyboard()
          });
        } else {
          await sendMessage(chatId, `❌ Saqlashda xatolik: ${res.error}`);
        }
        return;
      }

      // 🎵 MUSIQA QO'SHISH
      if (session.step === "music_title") {
        session.data.title = text;
        session.step = "music_artist";
        await sendMessage(chatId, "🎵 <b>(2/5) Ijrochi yoki Muallif:</b>\n<i>(Masalan: Flowa Beats yoki Synthwave Pro)</i>");
        return;
      } else if (session.step === "music_artist") {
        session.data.artist = text;
        session.step = "music_category";
        await sendMessage(chatId, "🎵 <b>(3/5) Kategoriya:</b>\n1. <code>workout</code> (Sport/Mashq uchun)\n2. <code>focus</code> (Diqqat/O'qish uchun)\n3. <code>relax</code> (Dam olish uchun)");
        return;
      } else if (session.step === "music_category") {
        session.data.category = text.toLowerCase().includes("focus") ? "focus" : (text.toLowerCase().includes("relax") ? "relax" : "workout");
        session.step = "music_duration";
        await sendMessage(chatId, "🎵 <b>(4/5) Davomiyligi (soniya):</b>\n<i>(Masalan: 180 = 3 daqiqa)</i>");
        return;
      } else if (session.step === "music_duration") {
        session.data.durationSeconds = parseInt(text, 10) || 180;
        session.step = "music_file";
        await sendMessage(chatId, "🎵 <b>(5/5) MP3 musiqa faylini shu yerga yuboring YOKI audio havolasini yozing:</b>");
        return;
      } else if (session.step === "music_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          await sendMessage(chatId, "⏳ <i>Audio fayl doimiy Firebase Storage serveriga yuklanmoqda...</i>");
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileAndUploadToStorage(fileId, "music");
          if (directUrl) audioUrl = directUrl;
        }
        session.data.audioUrl = audioUrl;
        session.data.coverEmoji = session.data.category === "focus" ? "🧠" : (session.data.category === "relax" ? "🌊" : "⚡");
        session.data.playCount = 0;
        session.data.id = `track_${Date.now()}`;
        session.data.createdAt = new Date();

        await sendMessage(chatId, "⏳ <i>Musiqa Firestore bazasiga saqlanmoqda...</i>");
        const res = await firestoreCreateDoc("music_tracks", session.data, session.data.id);
        userSessions.delete(fromId);

        if (res.success) {
          await sendMessage(chatId, `🎉 <b>Musiqa muvaffaqiyatli saqlandi!</b>\n\n🎶 <b>Nomi:</b> ${session.data.title}\n🎙️ <b>Ijrochi:</b> ${session.data.artist}\n📂 <b>Kategoriya:</b> ${session.data.category}\n\nIlovadagi audio pleerda doimiy tarzda yangraydi! 🎧`, {
            reply_markup: getAdminReplyKeyboard()
          });
        } else {
          await sendMessage(chatId, `❌ Saqlashda xatolik: ${res.error}`);
        }
        return;
      }

      // 🎧 AUDIO KITOB QO'SHISH
      if (session.step === "audiobook_title") {
        session.data.title = text;
        session.step = "audiobook_author";
        await sendMessage(chatId, "🎧 <b>(2/6) Kitob muallifi:</b>\n<i>(Masalan: Jeyms Klir)</i>");
        return;
      } else if (session.step === "audiobook_author") {
        session.data.author = text;
        session.step = "audiobook_narrator";
        await sendMessage(chatId, "🎧 <b>(3/6) Suhxandon / Ovoz beruvchi:</b>\n<i>(Masalan: O‘zbekcha ovoz yoki Audio studiya)</i>");
        return;
      } else if (session.step === "audiobook_narrator") {
        session.data.narrator = text;
        session.step = "audiobook_duration";
        await sendMessage(chatId, "🎧 <b>(4/6) Davomiyligi (daqiqa):</b>\n<i>(Masalan: 45)</i>");
        return;
      } else if (session.step === "audiobook_duration") {
        session.data.durationMin = parseInt(text, 10) || 30;
        session.step = "audiobook_desc";
        await sendMessage(chatId, "🎧 <b>(5/6) Qisqa tavsif yozing:</b>\n<i>(Masalan: Har kuni 1% yaxshilanish formulasi)</i>");
        return;
      } else if (session.step === "audiobook_desc") {
        session.data.desc = text;
        session.data.emoji = "🎧";
        session.step = "audiobook_file";
        await sendMessage(chatId, "🎧 <b>(6/6) Audio faylni shu yerga yuboring YOKI audio havolasini yozing:</b>");
        return;
      } else if (session.step === "audiobook_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          await sendMessage(chatId, "⏳ <i>Audio kitob doimiy Firebase Storage serveriga yuklanmoqda...</i>");
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileAndUploadToStorage(fileId, "audiobooks");
          if (directUrl) audioUrl = directUrl;
        }
        session.data.audioUrl = audioUrl;
        session.data.telegramUrl = "https://t.me/odat_fenix";
        session.data.createdAt = new Date();

        await sendMessage(chatId, "⏳ <i>Audio kitob Firestore bazasiga saqlanmoqda...</i>");
        const res = await firestoreCreateDoc("audiobooks", session.data);
        userSessions.delete(fromId);

        if (res.success) {
          await sendMessage(chatId, `🎉 <b>Audio kitob muvaffaqiyatli saqlandi!</b>\n\n🎧 <b>Nomi:</b> ${session.data.title}\n✍️ <b>Muallif:</b> ${session.data.author}\n⏱️ <b>Davomiyligi:</b> ${session.data.durationMin} daqiqa\n\nIlovadagi Audio kitoblar bo'limida doimiy chiqdi! 🚀`, {
            reply_markup: getAdminReplyKeyboard()
          });
        } else {
          await sendMessage(chatId, `❌ Saqlashda xatolik: ${res.error}`);
        }
        return;
      }

      // 🎁 DO'KONGA SOVG'A QO'SHISH
      if (session.step === "gift_title") {
        session.data.title = text;
        session.step = "gift_type";
        await sendMessage(chatId, "🎁 <b>(2/6) Mahsulot turi:</b>\n1. <code>gift</code> (Yetkazib beriladigan haqiqiy sovg'a)\n2. <code>coupon</code> (Chegirma promo-kodi)");
        return;
      } else if (session.step === "gift_type") {
        session.data.type = text.toLowerCase().includes("coupon") ? "coupon" : "gift";
        session.data.requiresShipping = session.data.type === "gift";
        session.step = "gift_points";
        await sendMessage(chatId, "🎁 <b>(3/6) PTS narxi (Coins):</b>\n<i>(Masalan: 500 yoki 1000)</i>");
        return;
      } else if (session.step === "gift_points") {
        session.data.pointsCost = parseInt(text, 10) || 100;
        session.step = "gift_desc";
        await sendMessage(chatId, "🎁 <b>(4/6) Mahsulot tavsifi:</b>\n<i>(Masalan: ODAT logotipi tushirilgan sifatli sport idishi)</i>");
        return;
      } else if (session.step === "gift_desc") {
        session.data.description = text;
        session.step = "gift_stock";
        await sendMessage(chatId, "🎁 <b>(5/6) Ombordagi soni (stock):</b>\n<i>(Masalan: 50)</i>");
        return;
      } else if (session.step === "gift_stock") {
        session.data.stock = parseInt(text, 10) || 10;
        session.step = "gift_image";
        await sendMessage(chatId, "🎁 <b>(6/6) Mahsulot rasmini shu yerga yuboring (Photo) YOKI rasm havolasini yozing:</b>");
        return;
      } else if (session.step === "gift_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          await sendMessage(chatId, "⏳ <i>Mahsulot rasmi Supabase Storage serveriga yuklanmoqda...</i>");
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileAndUploadToStorage(photo.file_id, "shop");
          if (directUrl) imageUrl = directUrl;
        }
        session.data.imageUrl = imageUrl || "https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=400";
        session.data.partnerName = "ODAT Rasmiy Do'koni";
        session.data.isActive = true;
        session.data.createdAt = new Date();

        await sendMessage(chatId, "⏳ <i>Sovg'a do'kon bazasiga saqlanmoqda...</i>");
        const res = await firestoreCreateDoc("shopItems", session.data);
        userSessions.delete(fromId);

        if (res.success) {
          await sendMessage(chatId, `🎉 <b>Mahsulot do'konga muvaffaqiyatli qo'shildi!</b>\n\n🛍️ <b>Nomi:</b> ${session.data.title}\n⚡ <b>Narxi:</b> ${session.data.pointsCost} PTS\n📦 <b>Mavjud soni:</b> ${session.data.stock} ta\n\nIlovadagi Do'kon (Shop) bo'limida real-vaqtda sotuvga chiqdi! 🚀`, {
            reply_markup: getAdminReplyKeyboard()
          });
        } else {
          await sendMessage(chatId, `❌ Saqlashda xatolik: ${res.error}`);
        }
        return;
      }

      // 🎫 KUPON QO'SHISH
      if (session.step === "coupon_title") {
        session.data.title = text;
        session.data.type = "coupon";
        session.data.requiresShipping = false;
        session.step = "coupon_discount";
        await sendMessage(chatId, "🎫 <b>(2/5) Chegirma matni:</b>\n<i>(Masalan: 30% OFF yoki 50,000 UZS Chegirma)</i>");
        return;
      } else if (session.step === "coupon_discount") {
        session.data.discountText = text;
        session.step = "coupon_points";
        await sendMessage(chatId, "🎫 <b>(3/5) PTS narxi (Coins):</b>\n<i>(Masalan: 200 yoki 500)</i>");
        return;
      } else if (session.step === "coupon_points") {
        session.data.pointsCost = parseInt(text, 10) || 100;
        session.step = "coupon_desc";
        await sendMessage(chatId, "🎫 <b>(4/5) Kupon tavsifi va shartlari:</b>\n<i>(Masalan: Barcha sport kiyimlari uchun 30% chegirma)</i>");
        return;
      } else if (session.step === "coupon_desc") {
        session.data.description = text;
        session.step = "coupon_image";
        await sendMessage(chatId, "🎫 <b>(5/5) Kupon rasmini yuboring YOKI rasm linkini yozing:</b>");
        return;
      } else if (session.step === "coupon_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) imageUrl = directUrl;
        }
        session.data.imageUrl = imageUrl || "https://images.unsplash.com/photo-1607083206869-4c7672e72a8a?w=400";
        session.data.partnerName = "ODAT Hamkor Do'koni";
        session.data.isActive = true;
        session.data.createdAt = new Date();

        await sendMessage(chatId, "⏳ <i>Kupon Firestore bazasiga saqlanmoqda...</i>");
        const res = await firestoreCreateDoc("shopItems", session.data);
        userSessions.delete(fromId);

        if (res.success) {
          await sendMessage(chatId, `🎉 <b>Kupon muvaffaqiyatli yaratildi!</b>\n\n🎫 <b>Nomi:</b> ${session.data.title}\n🏷️ <b>Chegirma:</b> ${session.data.discountText}\n⚡ <b>Narxi:</b> ${session.data.pointsCost} PTS\n\nIlovada barcha foydalanuvchilarga chiqdi! 🚀`, {
            reply_markup: getAdminReplyKeyboard()
          });
        } else {
          await sendMessage(chatId, `❌ Saqlashda xatolik: ${res.error}`);
        }
        return;
      }
    }

    // To'g'ridan-to'g'ri rasm yoki fayl yuborilganda
    if (message.photo || message.document || message.audio || message.voice) {
      await sendMessage(chatId, "📎 <b>Fayl yoki rasm qabul qilindi!</b>\nUshbu faylni nima maqsadda ishlatmoqchisiz?", {
        reply_markup: {
          inline_keyboard: [
            [{ text: "🎧 Yangi Audio Kitob qo'shish", callback_data: "add_audiobook" }],
            [{ text: "🎵 Yangi Musiqa qo'shish", callback_data: "add_music" }],
            [{ text: "📚 Yangi Kitob (PDF) qo'shish", callback_data: "add_book" }],
            [{ text: "🎁 Yangi Sovg'a qo'shish", callback_data: "add_gift" }],
            [{ text: "🛍️ Mavjud sovg'ani tahrirlash", callback_data: "list_gifts" }],
          ]
        }
      });
      return;
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// 📋 RO'YXATLAR VA TAHRIRLASH MENYULARI
// ────────────────────────────────────────────────────────────────────────────

async function showGiftsList(chatId) {
  const res = await firestoreListDocs("shopItems", 20);
  if (!res.success || !res.docs.length) {
    await sendMessage(chatId, "🎁 Do'konda hali sovg'alar yo'q.", {
      reply_markup: {
        inline_keyboard: [[{ text: "➕ Yangi sovg'a qo'shish", callback_data: "add_gift" }]]
      }
    });
    return;
  }
  let text = "🛍️ <b>ODAT DO'KONI — SOVG'ALAR RO'YXATI:</b>\n<i>(Tahrirlash uchun mahsulot tugmasini bosing)</i>\n\n";
  const buttons = [];
  res.docs.forEach((g, i) => {
    text += `${i + 1}. 🛍️ <b>${g.title}</b>\n💰 Narxi: <b>${g.pointsCost || 100} PTS</b> | Omborda: <b>${g.stock || 0} ta</b>\n\n`;
    buttons.push([
      { text: `✏️ Tahrirlash: ${g.title.slice(0, 16)}`, callback_data: `edit_gift_${g.id}` },
      { text: `🗑️`, callback_data: `del_gift_${g.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi sovg'a qo'shish", callback_data: "add_gift" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showGiftDetailMenu(chatId, docId) {
  const res = await firestoreGetDoc("shopItems", docId);
  if (!res.success || !res.data) {
    await sendMessage(chatId, "❌ Mahsulot topilmadi yoki o'chirilgan.");
    return;
  }
  const g = res.data;
  const msg = `🛍️ <b>MAHSULOT MA'LUMOTLARI:</b>\n\n` +
    `🏷️ <b>Nomi:</b> ${g.title || 'Nomsiz'}\n` +
    `💰 <b>PTS Narxi:</b> ${g.pointsCost || 0} PTS (Coins)\n` +
    `📦 <b>Ombordagi soni:</b> ${g.stock || 0} ta\n` +
    `📝 <b>Tavsifi:</b> ${g.description || 'Kiritilmagan'}\n` +
    `🖼️ <b>Rasmi:</b> ${g.imageUrl ? 'Mavjud ✅' : 'Kiritilmagan ❌'}\n\n` +
    `👇 <b>Qaysi ma'lumotni o'zgartirmoqchisiz?</b>`;

  const buttons = [
    [
      { text: "💰 PTS Narxini o'zgartirish", callback_data: `editfield_gift_points_${docId}` },
      { text: "🖼️ Rasmni almashtirish", callback_data: `editfield_gift_image_${docId}` }
    ],
    [
      { text: "📝 Nomini o'zgartirish", callback_data: `editfield_gift_title_${docId}` },
      { text: "📦 Soni (Stock)ni o'zgartirish", callback_data: `editfield_gift_stock_${docId}` }
    ],
    [
      { text: "📄 Tavsifini o'zgartirish", callback_data: `editfield_gift_desc_${docId}` }
    ],
    [
      { text: "🗑️ Butunlay o'chirish", callback_data: `del_gift_${docId}` },
      { text: "🔙 Sovg'alar ro'yxatiga qaytish", callback_data: "list_gifts" }
    ]
  ];

  if (g.imageUrl && (g.imageUrl.startsWith("http://") || g.imageUrl.startsWith("https://"))) {
    try {
      await sendPhoto(chatId, g.imageUrl, msg, {
        reply_markup: { inline_keyboard: buttons }
      });
      return;
    } catch (_) {}
  }

  await sendMessage(chatId, msg, { reply_markup: { inline_keyboard: buttons } });
}

async function showBooksList(chatId) {
  const res = await firestoreListDocs("books", 20);
  if (!res.success || !res.docs.length) {
    await sendMessage(chatId, "📚 Kutubxonada hali kitoblar yo'q.", {
      reply_markup: {
        inline_keyboard: [[{ text: "➕ Yangi kitob qo'shish", callback_data: "add_book" }]]
      }
    });
    return;
  }
  let text = "📚 <b>Kutubxonadagi kitoblar:</b>\n\n";
  const buttons = [];
  res.docs.forEach((b, i) => {
    text += `${i + 1}. <b>${b.title}</b> (${b.author || 'Muallif'}) — ${b.pointsReward || 100} PTS\n`;
    buttons.push([
      { text: `✏️ ${b.title.slice(0, 16)}`, callback_data: `edit_book_${b.id}` },
      { text: `🗑️`, callback_data: `del_book_${b.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi kitob qo'shish", callback_data: "add_book" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showBookDetailMenu(chatId, docId) {
  const res = await firestoreGetDoc("books", docId);
  if (!res.success || !res.data) {
    await sendMessage(chatId, "❌ Kitob topilmadi.");
    return;
  }
  const b = res.data;
  const msg = `📚 <b>KITOB MA'LUMOTLARI:</b>\n\n` +
    `📖 <b>Nomi:</b> ${b.title}\n` +
    `✍️ <b>Muallif:</b> ${b.author || 'Kiritilmagan'}\n` +
    `⚡ <b>Mukofot:</b> ${b.pointsReward || 0} PTS\n` +
    `📄 <b>Sahifalar:</b> ${b.totalPages || 0}\n\n` +
    `👇 <b>O'zgartirmoqchi bo'lgan ma'lumotni tanlang:</b>`;

  const buttons = [
    [
      { text: "⚡ PTS Mukofotini o'zgartirish", callback_data: `editfield_book_points_${docId}` },
      { text: "📝 Nomini o'zgartirish", callback_data: `editfield_book_title_${docId}` }
    ],
    [
      { text: "✍️ Muallifni o'zgartirish", callback_data: `editfield_book_author_${docId}` },
      { text: "🗑️ O'chirish", callback_data: `del_book_${docId}` }
    ],
    [
      { text: "🔙 Kitoblar ro'yxatiga qaytish", callback_data: "list_books" }
    ]
  ];

  await sendMessage(chatId, msg, { reply_markup: { inline_keyboard: buttons } });
}

async function showMusicList(chatId) {
  const res = await firestoreListDocs("music_tracks", 20);
  if (!res.success || !res.docs.length) {
    await sendMessage(chatId, "🎵 Musiqalar ro'yxati bo'sh.", {
      reply_markup: {
        inline_keyboard: [[{ text: "➕ Yangi musiqa qo'shish", callback_data: "add_music" }]]
      }
    });
    return;
  }
  let text = "🎵 <b>ODAT MUSIQALARI RO'YXATI:</b>\n<i>(Tahrirlash uchun musiqa nomini bosing)</i>\n\n";
  const buttons = [];
  res.docs.forEach((m, i) => {
    text += `${i + 1}. ${m.coverEmoji || '🎵'} <b>${m.title}</b> (${m.artist || 'ODAT'}) [${m.category || 'workout'}]\n`;
    buttons.push([
      { text: `✏️ ${m.title.slice(0, 16)}`, callback_data: `edit_music_${m.id}` },
      { text: `🗑️`, callback_data: `del_music_${m.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi musiqa qo'shish", callback_data: "add_music" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showMusicDetailMenu(chatId, docId) {
  const res = await firestoreGetDoc("music_tracks", docId);
  if (!res.success || !res.data) {
    await sendMessage(chatId, "❌ Musiqa topilmadi.");
    return;
  }
  const m = res.data;
  const msg = `🎵 <b>MUSIQA MA'LUMOTLARI:</b>\n\n` +
    `🎼 <b>Nomi:</b> ${m.title}\n` +
    `🎤 <b>Ijrochi:</b> ${m.artist || 'ODAT'}\n` +
    `📂 <b>Toifasi:</b> ${m.category || 'workout'}\n` +
    `🔗 <b>Audio fayl:</b> ${m.audioUrl ? 'Mavjud ✅' : 'Kiritilmagan ❌'}\n\n` +
    `👇 <b>O'zgartirmoqchi bo'lgan ma'lumotni tanlang:</b>`;

  const buttons = [
    [
      { text: "📝 Nomini o'zgartirish", callback_data: `editfield_music_title_${docId}` },
      { text: "🎤 Ijrochini o'zgartirish", callback_data: `editfield_music_artist_${docId}` }
    ],
    [
      { text: "📂 Toifani o'zgartirish", callback_data: `editfield_music_category_${docId}` },
      { text: "🎵 Audio faylni almashtirish", callback_data: `editfield_music_file_${docId}` }
    ],
    [
      { text: "🗑️ O'chirish", callback_data: `del_music_${docId}` },
      { text: "🔙 Musiqalar ro'yxatiga qaytish", callback_data: "list_music" }
    ]
  ];

  await sendMessage(chatId, msg, { reply_markup: { inline_keyboard: buttons } });
}

async function showCouponsList(chatId) {
  const res = await firestoreListDocs("shopItems", 50);
  if (!res.success || !res.docs.length) {
    await sendMessage(chatId, "🎫 Kuponlar hali yo'q.", {
      reply_markup: {
        inline_keyboard: [[{ text: "➕ Yangi kupon qo'shish", callback_data: "add_coupon" }]]
      }
    });
    return;
  }
  const coupons = res.docs.filter(d => d.type === "coupon" || d.discountText);
  if (!coupons.length) {
    await sendMessage(chatId, "🎫 Hozircha kuponlar mavjud emas.", {
      reply_markup: {
        inline_keyboard: [[{ text: "➕ Yangi kupon qo'shish", callback_data: "add_coupon" }]]
      }
    });
    return;
  }

  let text = "🎫 <b>ODAT KUPON VA PROMO-KODLAR RO'YXATI:</b>\n\n";
  const buttons = [];
  coupons.forEach((c, i) => {
    text += `${i + 1}. 🎫 <b>${c.title}</b> (${c.discountText || 'Chegirma'})\n💰 Narxi: <b>${c.pointsCost || 100} PTS</b>\n\n`;
    buttons.push([
      { text: `✏️ ${c.title.slice(0, 16)}`, callback_data: `edit_coupon_${c.id}` },
      { text: `🗑️`, callback_data: `del_gift_${c.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi kupon qo'shish", callback_data: "add_coupon" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showCouponDetailMenu(chatId, docId) {
  const res = await firestoreGetDoc("shopItems", docId);
  if (!res.success || !res.data) {
    await sendMessage(chatId, "❌ Kupon topilmadi.");
    return;
  }
  const c = res.data;
  const msg = `🎫 <b>KUPON MA'LUMOTLARI:</b>\n\n` +
    `🏷️ <b>Nomi:</b> ${c.title}\n` +
    `💰 <b>PTS Narxi:</b> ${c.pointsCost || 0} PTS\n` +
    `🏷️ <b>Chegirma:</b> ${c.discountText || 'Kiritilmagan'}\n` +
    `📝 <b>Tavsifi:</b> ${c.description || 'Kiritilmagan'}\n\n` +
    `👇 <b>O'zgartirmoqchi bo'lgan ma'lumotni tanlang:</b>`;

  const buttons = [
    [
      { text: "💰 PTS Narxini o'zgartirish", callback_data: `editfield_coupon_points_${docId}` },
      { text: "🏷️ Chegirma foizini o'zgartirish", callback_data: `editfield_coupon_discount_${docId}` }
    ],
    [
      { text: "📝 Nomini o'zgartirish", callback_data: `editfield_coupon_title_${docId}` },
      { text: "🖼️ Rasmni almashtirish", callback_data: `editfield_coupon_image_${docId}` }
    ],
    [
      { text: "🗑️ O'chirish", callback_data: `del_gift_${docId}` },
      { text: "🔙 Kuponlar ro'yxatiga qaytish", callback_data: "list_coupons" }
    ]
  ];

  await sendMessage(chatId, msg, { reply_markup: { inline_keyboard: buttons } });
}

async function showAudiobooksList(chatId) {
  const res = await firestoreListDocs("audiobooks", 30);
  if (!res.success || !res.docs.length) {
    await sendMessage(chatId, "🎧 Audio kitoblar hali mavjud emas.", {
      reply_markup: {
        inline_keyboard: [[{ text: "➕ Yangi audio kitob qo'shish", callback_data: "add_audiobook" }]]
      }
    });
    return;
  }
  let text = "🎧 <b>ODAT AUDIO KITOBLAR RO'YXATI:</b>\n<i>(Tahrirlash yoki ko'rish uchun audio kitob nomini bosing)</i>\n\n";
  const buttons = [];
  res.docs.forEach((a, i) => {
    text += `${i + 1}. ${a.emoji || '🎧'} <b>${a.title}</b>\n✍️ Muallif: <i>${a.author || 'Noma\'lum'}</i> | 🎙️ Ovoz: <i>${a.narrator || 'O\'zbekcha'}</i> | ⏱️ <b>${a.durationMin || 30} daqiqa</b>\n\n`;
    buttons.push([
      { text: `✏️ ${a.title.slice(0, 18)}`, callback_data: `edit_audio_${a.id}` },
      { text: `🗑️`, callback_data: `del_audio_${a.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi audio kitob qo'shish", callback_data: "add_audiobook" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showAudiobookDetailMenu(chatId, docId) {
  const res = await firestoreGetDoc("audiobooks", docId);
  if (!res.success || !res.data) {
    await sendMessage(chatId, "❌ Audio kitob topilmadi.");
    return;
  }
  const a = res.data;
  const msg = `🎧 <b>AUDIO KITOB MA'LUMOTLARI:</b>\n\n` +
    `📖 <b>Nomi:</b> ${a.title}\n` +
    `✍️ <b>Muallif:</b> ${a.author || 'Kiritilmagan'}\n` +
    `🎙️ <b>Ovoz beruvchi:</b> ${a.narrator || 'O‘zbekcha ovoz'}\n` +
    `⏱️ <b>Davomiyligi:</b> ${a.durationMin || 30} daqiqa\n` +
    `📝 <b>Tavsifi:</b> ${a.desc || 'Kiritilmagan'}\n` +
    `🔗 <b>Audio fayl:</b> ${a.audioUrl ? 'Mavjud ✅' : 'Kiritilmagan ❌'}\n` +
    `📢 <b>Telegram havola:</b> ${a.telegramUrl || 'https://t.me/odat_fenix'}\n\n` +
    `👇 <b>O'zgartirmoqchi bo'lgan ma'lumotni tanlang:</b>`;

  const buttons = [
    [
      { text: "📝 Nomini o'zgartirish", callback_data: `editfield_audio_title_${docId}` },
      { text: "✍️ Muallifni o'zgartirish", callback_data: `editfield_audio_author_${docId}` }
    ],
    [
      { text: "🎙️ Suxandonni o'zgartirish", callback_data: `editfield_audio_narrator_${docId}` },
      { text: "⏱️ Vaqtini o'zgartirish", callback_data: `editfield_audio_duration_${docId}` }
    ],
    [
      { text: "📄 Tavsifini o'zgartirish", callback_data: `editfield_audio_desc_${docId}` },
      { text: "🎵 Audio faylni almashtirish", callback_data: `editfield_audio_file_${docId}` }
    ],
    [
      { text: "🗑️ O'chirish", callback_data: `del_audio_${docId}` },
      { text: "🔙 Audio kitoblar ro'yxatiga qaytish", callback_data: "list_audiobooks" }
    ]
  ];

  await sendMessage(chatId, msg, { reply_markup: { inline_keyboard: buttons } });
}

// ────────────────────────────────────────────────────────────────────────────
// 🚀 POLLING ISHGA TUSHIRISH
// ────────────────────────────────────────────────────────────────────────────

async function startPolling() {
  console.log("🚀 ODAT Telegram Admin Boti (@odat_fenix_bot) ishga tushmoqda...");
  console.log("👑 Super Adminlar:", ADMIN_IDS.join(", "));
  console.log("🔥 Firebase Loyiha:", FIREBASE_PROJECT_ID);

  // 📰 Start hourly real-time news scraper
  fetchAndSyncNewsRss();
  setInterval(fetchAndSyncNewsRss, 3600 * 1000);

  await apiRequest("deleteWebhook", { drop_pending_updates: false });

  const me = await apiRequest("getMe");
  if (me?.ok) {
    console.log(`✅ Bot muvaffaqiyatli ulandi: @${me.result.username} (${me.result.first_name})`);
  } else {
    console.error("❌ Bot token noto'g'ri yoki ulanishda xatolik!");
  }

  let offset = 0;
  while (true) {
    try {
      const res = await apiRequest("getUpdates", {
        offset: offset,
        timeout: 30,
        allowed_updates: ["message", "callback_query", "chat_member"],
      });

      if (res?.ok && Array.isArray(res.result)) {
        for (const update of res.result) {
          offset = update.update_id + 1;
          await handleUpdate(update);
        }
      }
    } catch (err) {
      console.error("Polling xatolik:", err.message);
      await new Promise(r => setTimeout(r, 3000));
    }
  }
}

startPolling();
