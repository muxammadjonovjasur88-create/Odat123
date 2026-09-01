import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { getAuth } from "firebase-admin/auth";

const TOKEN = "8855349705:AAGMa9cMyo62Fh8gThoC1xtuRyQwnwu6N4U";
const TELEGRAM_API = `https://api.telegram.org/bot${TOKEN}`;
const TELEGRAM_FILE_API = `https://api.telegram.org/file/bot${TOKEN}`;

const ADMIN_IDS = ["8774615237", "658069248"];
const cachedAdmins = new Set(ADMIN_IDS.map(id => String(id)));
let lastAdminCacheSync = 0;

const BANNED_WORDS = [
  "harom", "jalap", "sik", "onangni", "itvachcha", "chmo", "dalbayob", "kot",
  "blyat", "suka", "xuy", "pizda", "ebat", "pidar", "fuck", "bitch", "asshole"
];

// Helper to interact with Telegram API
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

async function downloadAndUploadToFirebase(directUrl, filePath, contentType) {
  try {
    const response = await fetch(directUrl);
    if (!response.ok) {
      console.warn(`Failed to fetch file from Telegram: ${response.statusText}`);
      return null;
    }
    const arrayBuffer = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuffer);

    let defaultBucketName = null;
    try {
      const defaultBucket = getStorage().bucket();
      if (defaultBucket && defaultBucket.name) {
        defaultBucketName = defaultBucket.name;
      }
    } catch (e) {
      // ignore
    }

    const candidateBuckets = Array.from(
      new Set(
        [
          defaultBucketName,
          "flowa-4fca9.firebasestorage.app",
          "flowa-4fca9.appspot.com",
          process.env.GCP_PROJECT ? `${process.env.GCP_PROJECT}.appspot.com` : null,
          process.env.GCP_PROJECT ? `${process.env.GCP_PROJECT}.firebasestorage.app` : null,
        ].filter(Boolean)
      )
    );

    for (const bucketName of candidateBuckets) {
      try {
        const bucket = getStorage().bucket(bucketName);
        const file = bucket.file(filePath);
        await file.save(buffer, {
          metadata: { contentType },
          public: true,
          resumable: false,
        });
        try {
          await file.makePublic();
        } catch (e) {
          // Ignore if ACL/rules handle public access
        }
        return `https://storage.googleapis.com/${bucketName}/${filePath}`;
      } catch (err) {
        console.warn(`Firebase Storage upload attempt for bucket ${bucketName} failed:`, err.message);
      }
    }
  } catch (err) {
    console.error("downloadAndUploadToFirebase error:", err.message);
  }
  return null;
}

// Check admin
async function isUserAdmin(db, userId) {
  if (!userId) return false;
  const idStr = String(userId).trim();
  if (cachedAdmins.has(idStr)) return true;

  if (Date.now() - lastAdminCacheSync > 30000) {
    try {
      const snap = await db.collection("admins").get();
      ADMIN_IDS.forEach(id => cachedAdmins.add(String(id)));
      snap.forEach(doc => {
        if (doc.id) cachedAdmins.add(String(doc.id).trim());
        const d = doc.data();
        if (d.telegramId) cachedAdmins.add(String(d.telegramId).trim());
        if (d.idStr) cachedAdmins.add(String(d.idStr).trim());
      });
      lastAdminCacheSync = Date.now();
    } catch (e) {
      console.warn("Adminlarni sinxronlashda xatolik:", e.message);
    }
  }

  if (cachedAdmins.has(idStr)) return true;

  try {
    const docSnap = await db.collection("admins").doc(idStr).get();
    if (docSnap.exists) {
      cachedAdmins.add(idStr);
      return true;
    }
  } catch (_) {}

  return false;
}

// Keyboards
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

// Session store in Firestore `botSessions`
async function getSession(db, userId) {
  try {
    const snap = await db.collection("botSessions").doc(String(userId)).get();
    return snap.exists ? snap.data() : null;
  } catch (_) {
    return null;
  }
}

async function setSession(db, userId, data) {
  try {
    await db.collection("botSessions").doc(String(userId)).set({
      ...data,
      updatedAt: FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

async function clearSession(db, userId) {
  try {
    await db.collection("botSessions").doc(String(userId)).delete();
  } catch (_) {}
}

// Lists & Menus
async function showGiftsList(db, chatId) {
  const snap = await db.collection("shopItems").limit(20).get();
  if (snap.empty) {
    await sendMessage(chatId, "🎁 Do'konda hali sovg'alar yo'q.", {
      reply_markup: { inline_keyboard: [[{ text: "➕ Yangi sovg'a qo'shish", callback_data: "add_gift" }]] }
    });
    return;
  }
  let text = "🛍️ <b>ODAT DO'KONI — SOVG'ALAR RO'YXATI:</b>\n<i>(Tahrirlash uchun mahsulot tugmasini bosing)</i>\n\n";
  const buttons = [];
  snap.docs.forEach((d, i) => {
    const g = d.data();
    text += `${i + 1}. 🛍️ <b>${g.title}</b>\n💰 Narxi: <b>${g.pointsCost || 100} PTS</b> | Omborda: <b>${g.stock || 0} ta</b>\n\n`;
    buttons.push([
      { text: `✏️ Tahrirlash: ${(g.title || '').slice(0, 16)}`, callback_data: `edit_gift_${d.id}` },
      { text: `🗑️`, callback_data: `del_gift_${d.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi sovg'a qo'shish", callback_data: "add_gift" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showGiftDetailMenu(db, chatId, docId) {
  const snap = await db.collection("shopItems").doc(docId).get();
  if (!snap.exists) {
    await sendMessage(chatId, "❌ Mahsulot topilmadi.");
    return;
  }
  const g = snap.data();
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
      await sendPhoto(chatId, g.imageUrl, msg, { reply_markup: { inline_keyboard: buttons } });
      return;
    } catch (_) {}
  }
  await sendMessage(chatId, msg, { reply_markup: { inline_keyboard: buttons } });
}

async function showBooksList(db, chatId) {
  const snap = await db.collection("books").limit(20).get();
  if (snap.empty) {
    await sendMessage(chatId, "📚 Kutubxonada hali kitoblar yo'q.", {
      reply_markup: { inline_keyboard: [[{ text: "➕ Yangi kitob qo'shish", callback_data: "add_book" }]] }
    });
    return;
  }
  let text = "📚 <b>Kutubxonadagi kitoblar:</b>\n\n";
  const buttons = [];
  snap.docs.forEach((d, i) => {
    const b = d.data();
    text += `${i + 1}. <b>${b.title}</b> (${b.author || 'Muallif'}) — ${b.pointsReward || 100} PTS\n`;
    buttons.push([
      { text: `✏️ ${(b.title || '').slice(0, 16)}`, callback_data: `edit_book_${d.id}` },
      { text: `🗑️`, callback_data: `del_book_${d.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi kitob qo'shish", callback_data: "add_book" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showBookDetailMenu(db, chatId, docId) {
  const snap = await db.collection("books").doc(docId).get();
  if (!snap.exists) {
    await sendMessage(chatId, "❌ Kitob topilmadi.");
    return;
  }
  const b = snap.data();
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

async function showMusicList(db, chatId) {
  const snap = await db.collection("music_tracks").limit(20).get();
  if (snap.empty) {
    await sendMessage(chatId, "🎵 Musiqalar ro'yxati bo'sh.", {
      reply_markup: { inline_keyboard: [[{ text: "➕ Yangi musiqa qo'shish", callback_data: "add_music" }]] }
    });
    return;
  }
  let text = "🎵 <b>ODAT MUSIQALARI RO'YXATI:</b>\n<i>(Tahrirlash uchun musiqa nomini bosing)</i>\n\n";
  const buttons = [];
  snap.docs.forEach((d, i) => {
    const m = d.data();
    text += `${i + 1}. ${m.coverEmoji || '🎵'} <b>${m.title}</b> (${m.artist || 'ODAT'}) [${m.category || 'workout'}]\n`;
    buttons.push([
      { text: `✏️ ${(m.title || '').slice(0, 16)}`, callback_data: `edit_music_${d.id}` },
      { text: `🗑️`, callback_data: `del_music_${d.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi musiqa qo'shish", callback_data: "add_music" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showMusicDetailMenu(db, chatId, docId) {
  const snap = await db.collection("music_tracks").doc(docId).get();
  if (!snap.exists) {
    await sendMessage(chatId, "❌ Musiqa topilmadi.");
    return;
  }
  const m = snap.data();
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

async function showCouponsList(db, chatId) {
  const snap = await db.collection("shopItems").limit(50).get();
  const coupons = snap.docs.filter(d => d.data().type === "coupon" || d.data().discountText);
  if (!coupons.length) {
    await sendMessage(chatId, "🎫 Hozircha kuponlar mavjud emas.", {
      reply_markup: { inline_keyboard: [[{ text: "➕ Yangi kupon qo'shish", callback_data: "add_coupon" }]] }
    });
    return;
  }
  let text = "🎫 <b>ODAT KUPON VA PROMO-KODLAR RO'YXATI:</b>\n\n";
  const buttons = [];
  coupons.forEach((d, i) => {
    const c = d.data();
    text += `${i + 1}. 🎫 <b>${c.title}</b> (${c.discountText || 'Chegirma'})\n💰 Narxi: <b>${c.pointsCost || 100} PTS</b>\n\n`;
    buttons.push([
      { text: `✏️ ${(c.title || '').slice(0, 16)}`, callback_data: `edit_coupon_${d.id}` },
      { text: `🗑️`, callback_data: `del_gift_${d.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi kupon qo'shish", callback_data: "add_coupon" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showCouponDetailMenu(db, chatId, docId) {
  const snap = await db.collection("shopItems").doc(docId).get();
  if (!snap.exists) {
    await sendMessage(chatId, "❌ Kupon topilmadi.");
    return;
  }
  const c = snap.data();
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

async function showAudiobooksList(db, chatId) {
  const snap = await db.collection("audiobooks").limit(30).get();
  if (snap.empty) {
    await sendMessage(chatId, "🎧 Audio kitoblar hali mavjud emas.", {
      reply_markup: { inline_keyboard: [[{ text: "➕ Yangi audio kitob qo'shish", callback_data: "add_audiobook" }]] }
    });
    return;
  }
  let text = "🎧 <b>ODAT AUDIO KITOBLAR RO'YXATI:</b>\n<i>(Tahrirlash yoki ko'rish uchun audio kitob nomini bosing)</i>\n\n";
  const buttons = [];
  snap.docs.forEach((d, i) => {
    const a = d.data();
    text += `${i + 1}. ${a.emoji || '🎧'} <b>${a.title}</b>\n✍️ Muallif: <i>${a.author || 'Noma\'lum'}</i> | 🎙️ Ovoz: <i>${a.narrator || 'O\'zbekcha'}</i> | ⏱️ <b>${a.durationMin || 30} daqiqa</b>\n\n`;
    buttons.push([
      { text: `✏️ ${(a.title || '').slice(0, 18)}`, callback_data: `edit_audio_${d.id}` },
      { text: `🗑️`, callback_data: `del_audio_${d.id}` }
    ]);
  });
  buttons.push([{ text: "➕ Yangi audio kitob qo'shish", callback_data: "add_audiobook" }]);
  await sendMessage(chatId, text, { reply_markup: { inline_keyboard: buttons } });
}

async function showAudiobookDetailMenu(db, chatId, docId) {
  const snap = await db.collection("audiobooks").doc(docId).get();
  if (!snap.exists) {
    await sendMessage(chatId, "❌ Audio kitob topilmadi.");
    return;
  }
  const a = snap.data();
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

// MAIN WEBHOOK PROCESSOR
export async function processTelegramUpdate(db, update) {
  if (!update) return;

  // 1. Callback Query
  if (update.callback_query) {
    const cb = update.callback_query;
    const fromId = String(cb.from?.id || "");
    const chatId = cb.message?.chat?.id;

    // Bug report handler (approve_bug / reject_bug)
    const data = cb.data || "";
    if (data.startsWith("approve_bug:")) {
      const parts = data.split(":");
      const reportId = parts[1];
      const userUid = parts[2];
      await db.collection("users").doc(userUid).update({
        totalPoints: FieldValue.increment(4000),
        weeklyPoints: FieldValue.increment(4000),
      });
      await db.collection("bug_reports").doc(reportId).update({
        status: "approved",
        approvedAt: FieldValue.serverTimestamp(),
      });
      await apiRequest("answerCallbackQuery", {
        callback_query_id: cb.id,
        text: "✅ Bug hisoboti tasdiqlandi! Foydalanuvchiga 4,000 PTS berildi!",
        show_alert: true,
      });
      return;
    } else if (data.startsWith("reject_bug:")) {
      const reportId = data.split(":")[1];
      await db.collection("bug_reports").doc(reportId).update({
        status: "rejected",
        rejectedAt: FieldValue.serverTimestamp(),
      });
      await apiRequest("answerCallbackQuery", {
        callback_query_id: cb.id,
        text: "❌ Bug hisoboti rad etildi.",
      });
      return;
    }

    const isAdmin = await isUserAdmin(db, fromId);
    if (!isAdmin) {
      await apiRequest("answerCallbackQuery", {
        callback_query_id: cb.id,
        text: "⛔ Kechirasiz, siz admin emassiz!",
        show_alert: true,
      });
      return;
    }

    await apiRequest("answerCallbackQuery", { callback_query_id: cb.id });

    if (data === "add_gift") {
      await setSession(db, fromId, { step: "gift_title", data: {} });
      await sendMessage(chatId, "🎁 <b>Do'konga yangi sovg'a qo'shish (1/6):</b>\n\nMahsulot nomini kiriting:\n<i>(Masalan: ODAT Smart Suv Idishi)</i>");
    } else if (data === "add_book") {
      await setSession(db, fromId, { step: "book_title", data: {} });
      await sendMessage(chatId, "📚 <b>Yangi kitob qo'shish (1/6):</b>\n\nKitob nomini kiriting:\n<i>(Masalan: Atom Odatlar)</i>");
    } else if (data === "add_music") {
      await setSession(db, fromId, { step: "music_title", data: {} });
      await sendMessage(chatId, "🎵 <b>Yangi musiqa qo'shish (1/5):</b>\n\nMusiqa / Trek nomini kiriting:\n<i>(Masalan: Cyber Cardio Sprint)</i>");
    } else if (data === "add_audiobook") {
      await setSession(db, fromId, { step: "audiobook_title", data: {} });
      await sendMessage(chatId, "🎧 <b>Yangi audio kitob qo'shish (1/6):</b>\n\nAudio kitob nomini kiriting:\n<i>(Masalan: Vaqt Qadri va Rejalashtirish)</i>");
    } else if (data === "list_gifts") {
      await showGiftsList(db, chatId);
    } else if (data === "list_books") {
      await showBooksList(db, chatId);
    } else if (data === "list_music") {
      await showMusicList(db, chatId);
    } else if (data === "list_audiobooks") {
      await showAudiobooksList(db, chatId);
    } else if (data === "list_coupons") {
      await showCouponsList(db, chatId);
    } else if (data === "add_coupon") {
      await setSession(db, fromId, { step: "coupon_title", data: {} });
      await sendMessage(chatId, "🎫 <b>Yangi kupon / promo-kod qo'shish (1/5):</b>\n\nKupon nomini kiriting:\n<i>(Masalan: 20% Chegirma — Nike Do'koni)</i>");
    } else if (data.startsWith("edit_gift_")) {
      await showGiftDetailMenu(db, chatId, data.replace("edit_gift_", ""));
    } else if (data.startsWith("editfield_gift_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "points") {
        await setSession(db, fromId, { step: "editing_gift_points", docId });
        await sendMessage(chatId, "💰 <b>Yangi PTS narxini kiriting:</b>\n<i>(Masalan: 450 yoki 1200)</i>");
      } else if (field === "image") {
        await setSession(db, fromId, { step: "editing_gift_image", docId });
        await sendMessage(chatId, "🖼️ <b>Mahsulotning yangi rasmini shu yerga yuboring (Photo) YOKI rasm linkini yozing:</b>");
      } else if (field === "title") {
        await setSession(db, fromId, { step: "editing_gift_title", docId });
        await sendMessage(chatId, "📝 <b>Mahsulotning yangi nomini kiriting:</b>\n<i>(Masalan: ODAT Smart Shaker 700ml)</i>");
      } else if (field === "stock") {
        await setSession(db, fromId, { step: "editing_gift_stock", docId });
        await sendMessage(chatId, "📦 <b>Ombordagi yangi sonini kiriting (Stock):</b>\n<i>(Masalan: 100)</i>");
      } else if (field === "desc") {
        await setSession(db, fromId, { step: "editing_gift_desc", docId });
        await sendMessage(chatId, "📄 <b>Mahsulotning yangi tavsifini kiriting:</b>");
      }
    } else if (data.startsWith("edit_coupon_")) {
      await showCouponDetailMenu(db, chatId, data.replace("edit_coupon_", ""));
    } else if (data.startsWith("editfield_coupon_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "points") {
        await setSession(db, fromId, { step: "editing_coupon_points", docId });
        await sendMessage(chatId, "💰 <b>Kuponning yangi PTS narxini kiriting:</b>\n<i>(Masalan: 300)</i>");
      } else if (field === "title") {
        await setSession(db, fromId, { step: "editing_coupon_title", docId });
        await sendMessage(chatId, "📝 <b>Kuponning yangi nomini kiriting:</b>");
      } else if (field === "discount") {
        await setSession(db, fromId, { step: "editing_coupon_discount", docId });
        await sendMessage(chatId, "🏷️ <b>Yangi chegirma foizini yoki matnini kiriting (masalan: 25% OFF):</b>");
      } else if (field === "image") {
        await setSession(db, fromId, { step: "editing_coupon_image", docId });
        await sendMessage(chatId, "🖼️ <b>Kuponning yangi rasmini yuboring yoki link yozing:</b>");
      }
    } else if (data.startsWith("edit_music_")) {
      await showMusicDetailMenu(db, chatId, data.replace("edit_music_", ""));
    } else if (data.startsWith("editfield_music_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "title") {
        await setSession(db, fromId, { step: "editing_music_title", docId });
        await sendMessage(chatId, "📝 <b>Yangi musiqa nomini kiriting:</b>");
      } else if (field === "artist") {
        await setSession(db, fromId, { step: "editing_music_artist", docId });
        await sendMessage(chatId, "✍️ <b>Yangi ijrochi (Artist) nomini kiriting:</b>");
      } else if (field === "category") {
        await setSession(db, fromId, { step: "editing_music_category", docId });
        await sendMessage(chatId, "📂 <b>Yangi toifani kiriting (workout, focus, chill, epic):</b>");
      } else if (field === "file") {
        await setSession(db, fromId, { step: "editing_music_file", docId });
        await sendMessage(chatId, "🎵 <b>Yangi MP3 audio faylni yuboring yoki audio linkini yozing:</b>");
      }
    } else if (data.startsWith("edit_book_")) {
      await showBookDetailMenu(db, chatId, data.replace("edit_book_", ""));
    } else if (data.startsWith("editfield_book_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "points") {
        await setSession(db, fromId, { step: "editing_book_points", docId });
        await sendMessage(chatId, "💰 <b>Kitob o'qiganlik uchun yangi PTS mukofotini kiriting:</b>\n<i>(Masalan: 150)</i>");
      } else if (field === "title") {
        await setSession(db, fromId, { step: "editing_book_title", docId });
        await sendMessage(chatId, "📝 <b>Yangi kitob nomini kiriting:</b>");
      } else if (field === "author") {
        await setSession(db, fromId, { step: "editing_book_author", docId });
        await sendMessage(chatId, "✍️ <b>Yangi muallif nomini kiriting:</b>");
      }
    } else if (data.startsWith("edit_audio_") || data.startsWith("edit_audiobook_")) {
      const docId = data.startsWith("edit_audio_") ? data.replace("edit_audio_", "") : data.replace("edit_audiobook_", "");
      await showAudiobookDetailMenu(db, chatId, docId);
    } else if (data.startsWith("editfield_audio_")) {
      const parts = data.split("_");
      const field = parts[2];
      const docId = parts.slice(3).join("_");
      if (field === "title") {
        await setSession(db, fromId, { step: "editing_audio_title", docId });
        await sendMessage(chatId, "📝 <b>Audio kitobning yangi nomini kiriting:</b>");
      } else if (field === "author") {
        await setSession(db, fromId, { step: "editing_audio_author", docId });
        await sendMessage(chatId, "✍️ <b>Yangi muallif nomini kiriting:</b>");
      } else if (field === "narrator") {
        await setSession(db, fromId, { step: "editing_audio_narrator", docId });
        await sendMessage(chatId, "🎙️ <b>Yangi suxandon / ovoz beruvchi nomini kiriting:</b>");
      } else if (field === "duration") {
        await setSession(db, fromId, { step: "editing_audio_duration", docId });
        await sendMessage(chatId, "⏱️ <b>Yangi davomiylikni kiriting (daqiqa):</b>\n<i>(Masalan: 45)</i>");
      } else if (field === "desc") {
        await setSession(db, fromId, { step: "editing_audio_desc", docId });
        await sendMessage(chatId, "📄 <b>Yangi qisqacha tavsif kiriting:</b>");
      } else if (field === "file") {
        await setSession(db, fromId, { step: "editing_audio_file", docId });
        await sendMessage(chatId, "🎵 <b>Yangi audio faylni yuboring yoki to'g'ridan-to'g'ri havolasini yozing:</b>");
      }
    } else if (data.startsWith("del_")) {
      const parts = data.split("_");
      const type = parts[1];
      const docId = parts.slice(2).join("_");
      let colName = "books";
      if (type === "music") colName = "music_tracks";
      else if (type === "audio") colName = "audiobooks";
      else if (type === "gift") colName = "shopItems";

      await db.collection(colName).doc(docId).delete();
      await sendMessage(chatId, `✅ <b>Muvaffaqiyatli o'chirildi!</b>\nBo'lim: <code>${colName}</code>\nID: <code>${docId}</code>`);
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

  // Group Moderation
  if (chatType === "group" || chatType === "supergroup") {
    if (message.new_chat_members && message.new_chat_members.length > 0) {
      for (const newMember of message.new_chat_members) {
        if (newMember.is_bot) continue;
        const memberName = newMember.first_name || newMember.username || "Do'stimiz";
        const welcomeMsg = `🎉 <b>Xush kelibsiz, ${memberName}!</b>\n\n` +
          `🌿 <b>ODAT / Flowa</b> hamjamiyatiga xush kelibsiz!\n` +
          `Bu yerda biz har kuni yangi odatlar, sport, kitob mutolaasi va intizom orqali o'z maqsadlarimizga erishamiz. 🚀\n\n` +
          `📌 <b>Guruh qoidalari:</b>\n` +
          `• Reklama va begona havolalar taqiqlangan.\n` +
          `• Faqat do'stona xabarlar va vazifalarning isbot rasmlari qabul qilinadi. 🌿`;
        await sendMessage(chatId, welcomeMsg);
      }
      return;
    }

    const isAdmin = await isUserAdmin(db, fromId);
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

  // Private Messages (Login, Authentication & Admin Panel)
  if (chatType === "private") {
    // ── A. TELEFON RAQAM / CONTACT QABUL QILISH (Login & Account Creation) ──
    if (message.contact) {
      const contact = message.contact;
      const rawPhone = String(contact.phone_number || "").trim();
      if (rawPhone) {
        const cleanPhone = rawPhone.replace(/\s+|-|\(|\)/g, "");
        const formattedPhone = cleanPhone.startsWith("+")
          ? cleanPhone
          : (cleanPhone.startsWith("998") ? `+${cleanPhone}` : `+998${cleanPhone}`);

        console.log(`Telegram contact received: ${formattedPhone} fromId=${fromId}`);

        // Pending login tokenini tekshirish
        const tgUserRef = db.collection("telegramUsers").doc(fromId);
        const tgUserSnap = await tgUserRef.get();
        const loginToken = tgUserSnap.data()?.pendingLoginToken;

        let targetUid = null;
        let isNewUser = false;

        // 1. users ichidan qidirish (phoneNumber, phone yoki telegramId)
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
            telegramChatId: String(chatId),
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
              telegramChatId: String(chatId),
              updatedAt: FieldValue.serverTimestamp(),
            }, { merge: true });
          } else {
            // Yangi user yaratish
            isNewUser = true;
            const firstName = contact.first_name || fromUser?.first_name || "Foydalanuvchi";
            const lastName = contact.last_name || fromUser?.last_name || "";
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
              telegramChatId: String(chatId),
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

        // Firebase Auth Custom Token yaratish
        const customToken = await getAuth().createCustomToken(targetUid);

        // loginRequests tokenini tasdiqlash
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
              chatId: String(chatId),
              isNewUser: isNewUser,
              approvedAt: FieldValue.serverTimestamp(),
            });
            await tgUserRef.set({ pendingLoginToken: null }, { merge: true });
          }
        }

        const successMsg =
          `✅ <b>Telefon raqamingiz muvaffaqiyatli tasdiqlandi!</b> (${formattedPhone})\n\n` +
          `Odat ilovasiga xush kelibsiz! Ilovaga qaytishingiz mumkin, tizimga avtomatik kirilmoqda... 🌿`;

        await sendMessage(chatId, successMsg, {
          reply_markup: { remove_keyboard: true },
        });
        return;
      }
    }

    // ── B. DEEP LINK BILAN KIRISH (/start login_<token>) ──
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
        await sendMessage(
          chatId,
          "❌ <b>Kirish so'rovi topilmadi.</b>\n\nIltimos, Odat ilovasiga qaytib, qayta urinib ko'ring. 🌿"
        );
        return;
      }

      const reqData = reqDoc.data() || {};
      if (reqData.status !== "pending") {
        await sendMessage(
          chatId,
          "❌ <b>Bu kirish so'rovi allaqachon ishlatilgan yoki bekor qilingan.</b> 🌿"
        );
        return;
      }

      if (Date.now() > (reqData.expiresAt || 0)) {
        await reqRef.update({ status: "expired" });
        await sendMessage(
          chatId,
          "⏰ <b>Kirish so'rovi vaqti tugagan (5 daqiqa).</b>\n\nIlovadan yangi so'rov yuboring. 🌿"
        );
        return;
      }

      // Foydalanuvchi oldin ro'yxatdan o'tgan yoki telegramId/telegramChatId ulanganmi tekshirish
      const existingUserSnap = await db
        .collection("users")
        .where("telegramId", "==", fromId)
        .limit(1)
        .get();

      let targetUid = null;
      let existingName = null;

      if (!existingUserSnap.empty) {
        targetUid = existingUserSnap.docs[0].id;
        existingName = existingUserSnap.docs[0].data()?.name;
      } else {
        const existingChatSnap = await db
          .collection("users")
          .where("telegramChatId", "==", String(chatId))
          .limit(1)
          .get();
        if (!existingChatSnap.empty) {
          targetUid = existingChatSnap.docs[0].id;
          existingName = existingChatSnap.docs[0].data()?.name;
        }
      }

      if (targetUid) {
        // Avval bog'langan bo'lsa darhol avtomatik kirish
        const customToken = await getAuth().createCustomToken(targetUid);
        await reqRef.update({
          status: "approved",
          uid: targetUid,
          customToken: customToken,
          telegramId: fromId,
          chatId: String(chatId),
          isNewUser: false,
          approvedAt: FieldValue.serverTimestamp(),
        });
        await db.collection("telegramUsers").doc(fromId).set({
          pendingLoginToken: null,
          chatId: String(chatId),
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        const welcomeBackMsg =
          `✅ <b>Kirish muvaffaqiyatli tasdiqlandi!</b>\n\n` +
          `Assalomu alaykum, <b>${existingName || "Foydalanuvchi"}</b>! 🌿\n` +
          `Odat ilovasiga qaytishingiz mumkin, tizimga avtomatik kirilmoqda... 🚀`;

        await sendMessage(chatId, welcomeBackMsg, {
          reply_markup: { remove_keyboard: true },
        });
        return;
      }

      // Yangi foydalanuvchi bo'lsa yoki telefon ulanmagan bo'lsa:
      // pendingLoginToken saqlanadi
      await db.collection("telegramUsers").doc(fromId).set({
        pendingLoginToken: loginToken,
        chatId: String(chatId),
        updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });

      // Telefon raqam so'rash
      await sendMessage(
        chatId,
        "👋 <b>Assalomu alaykum!</b>\n\n" +
        "Odat ilovasiga kirish yoki yangi hisob yaratish uchun pastdagi <b>«📱 Telefon raqamimni yuborish»</b> tugmasini bosing 👇",
        {
          reply_markup: {
            keyboard: [
              [{ text: "📱 Telefon raqamimni yuborish", request_contact: true }]
            ],
            resize_keyboard: true,
            one_time_keyboard: true
          }
        }
      );
      return;
    }

    const isAdmin = await isUserAdmin(db, fromId);

    if (!isAdmin) {
      const welcomeMsg = `🌿 <b>Assalomu alaykum va ODAT botiga xush kelibsiz!</b>\n\n` +
        `Ushbu bot ODAT ilovasi orqali tizimga tezkor va xavfsiz kirish, hamjamiyat guruhlarini nazorat qilish hamda bildirishnomalarni yetkazish uchun xizmat qiladi.\n\n` +
        `📢 <b>Rasmiy kanalimiz:</b> @odat_fenix`;
      await sendMessage(chatId, welcomeMsg, {
        reply_markup: {
          inline_keyboard: [[{ text: "📢 Rasmiy Kanal", url: "https://t.me/odat_fenix" }]]
        }
      });
      return;
    }

    if (text === "/cancel" || text === "❌ Bekor qilish") {
      await clearSession(db, fromId);
      await sendMessage(chatId, "✅ Jarayon bekor qilindi. Bosh menyudasiz.", {
        reply_markup: getAdminReplyKeyboard()
      });
      return;
    }

    if (text === "🛍️ Do'kon sovg'alari") {
      await showGiftsList(db, chatId);
      return;
    } else if (text === "🎫 Kuponlar") {
      await showCouponsList(db, chatId);
      return;
    } else if (text === "📚 Kitoblar") {
      await showBooksList(db, chatId);
      return;
    } else if (text === "🎵 Musiqalar") {
      await showMusicList(db, chatId);
      return;
    } else if (text === "🎧 Audio kitoblar") {
      await showAudiobooksList(db, chatId);
      return;
    } else if (text === "🎁 Sovg'a qo'shish") {
      await setSession(db, fromId, { step: "gift_title", data: {} });
      await sendMessage(chatId, "🎁 <b>Do'konga yangi sovg'a qo'shish (1/6):</b>\n\nMahsulot nomini kiriting:\n<i>(Masalan: ODAT Smart Suv Idishi)</i>");
      return;
    } else if (text === "🎫 Kupon qo'shish") {
      await setSession(db, fromId, { step: "coupon_title", data: {} });
      await sendMessage(chatId, "🎫 <b>Yangi kupon / promo-kod qo'shish (1/5):</b>\n\nKupon nomini kiriting:\n<i>(Masalan: 20% Chegirma — Nike Do'koni)</i>");
      return;
    } else if (text === "📚 Kitob qo'shish" || text === "📚 Kitob qo‘shish") {
      await setSession(db, fromId, { step: "book_title", data: {} });
      await sendMessage(chatId, "📚 <b>Yangi kitob qo'shish (1/6):</b>\n\nKitob nomini kiriting:\n<i>(Masalan: Atom Odatlar)</i>");
      return;
    } else if (text === "🎵 Musiqa qo'shish" || text === "🎵 Musiqa qo‘shish") {
      await setSession(db, fromId, { step: "music_title", data: {} });
      await sendMessage(chatId, "🎵 <b>Yangi musiqa qo'shish (1/5):</b>\n\nMusiqa / Trek nomini kiriting:\n<i>(Masalan: Cyber Cardio Sprint)</i>");
      return;
    } else if (text === "🎧 Audio kitob qo'shish" || text === "🎧 Audio kitob qo‘shish") {
      await setSession(db, fromId, { step: "audiobook_title", data: {} });
      await sendMessage(chatId, "🎧 <b>Yangi audio kitob qo'shish (1/6):</b>\n\nAudio kitob nomini kiriting:\n<i>(Masalan: Vaqt Qadri va Rejalashtirish)</i>");
      return;
    }

    if (text === "/resetplayers" || text === "/clearplayers" || text === "/deleteplayers") {
      await sendMessage(chatId, "⏳ <b>O'yinchilar ma'lumotlari tozalanmoqda...</b> Iltimos kuting.");
      try {
        const result = await cleanupPlayersDatabase(db);
        const msg = `✅ <b>O'yinchilar ma'lumotlari muvaffaqiyatli to'liq o'chirildi!</b>\n\n` +
          `👤 O'chirilgan foydalanuvchilar (users): <b>${result.usersDeleted} ta</b>\n` +
          `🏰 O'chirilgan klanlar: <b>${result.clansDeleted} ta</b>\n` +
          `📸 O'chirilgan isbotlar (proofs): <b>${result.proofsDeleted} ta</b>\n` +
          `🔑 O'chirilgan login so'rovlari: <b>${result.loginsDeleted} ta</b>\n` +
          `🔐 O'chirilgan Auth hisoblari: <b>${result.authUsersDeleted} ta</b>\n\n` +
          `📚 Kitoblar, 🎵 Musiqalar, 🎧 Audio kitoblar va 🛍️ Do'kon to'liq saqlanib qoldi! 🌿`;
        await sendMessage(chatId, msg);
      } catch (err) {
        await sendMessage(chatId, `❌ <b>Tozalashda xatolik:</b> ${err.message}`);
      }
      return;
    }

    if (text === "/start" || text === "/admin" || text === "/menu" || text === "📊 Statistika") {
      await clearSession(db, fromId);
      const [bSnap, mSnap, aSnap, gSnap] = await Promise.all([
        db.collection("books").get(),
        db.collection("music_tracks").get(),
        db.collection("audiobooks").get(),
        db.collection("shopItems").get(),
      ]);

      const dashboardMsg = `👑 <b>ODAT / FLOWA CLOUD ADMIN BOSHQARUV PANELI</b> ☁️\n\n` +
        `👤 <b>Admin ID:</b> <code>${fromId}</code> (Tasdiqlangan)\n` +
        `⚡ <b>Holat:</b> 24/7 Firebase Cloud Server faol ✅\n\n` +
        `📊 <b>Mavjud ma'lumotlar statistikasi:</b>\n` +
        `🛍️ Do'kon sovg'alari: <b>${gSnap.size} ta</b>\n` +
        `📚 Kitoblar (PDF): <b>${bSnap.size} ta</b>\n` +
        `🎵 Musiqalar (MP3): <b>${mSnap.size} ta</b>\n` +
        `🎧 Audio kitoblar: <b>${aSnap.size} ta</b>\n\n` +
        `Quyidagi tugmalar orqali audio kitoblar, musiqalar yoki sovg'alarni boshqaring! 🚀`;

      await sendMessage(chatId, dashboardMsg, {
        reply_markup: getAdminInlineMenu()
      });
      return;
    }

    // FSM Editing & Creation
    const session = await getSession(db, fromId);
    if (session) {
      // Gift Edits
      if (session.step === "editing_gift_points") {
        const points = parseInt(text, 10);
        if (isNaN(points) || points <= 0) {
          await sendMessage(chatId, "⚠️ Iltimos, musbat raqam kiriting (masalan: 500):");
          return;
        }
        await db.collection("shopItems").doc(session.docId).update({ pointsCost: points });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Mahsulot narxi ${points} PTS ga o'zgartirildi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showGiftDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_gift_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) imageUrl = directUrl;
        }
        await db.collection("shopItems").doc(session.docId).update({ imageUrl });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Mahsulot rasmi yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showGiftDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_gift_title") {
        await db.collection("shopItems").doc(session.docId).update({ title: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Mahsulot nomi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showGiftDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_gift_stock") {
        const stock = parseInt(text, 10) || 0;
        await db.collection("shopItems").doc(session.docId).update({ stock });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Ombor soni ${stock} ta deb yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showGiftDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_gift_desc") {
        await db.collection("shopItems").doc(session.docId).update({ description: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Tavsif yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showGiftDetailMenu(db, chatId, session.docId);
        return;
      }

      // Coupon Edits
      if (session.step === "editing_coupon_points") {
        const points = parseInt(text, 10) || 100;
        await db.collection("shopItems").doc(session.docId).update({ pointsCost: points });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Kupon narxi yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showCouponDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_coupon_title") {
        await db.collection("shopItems").doc(session.docId).update({ title: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Kupon nomi yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showCouponDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_coupon_discount") {
        await db.collection("shopItems").doc(session.docId).update({ discountText: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Chegirma matni yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showCouponDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_coupon_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) imageUrl = directUrl;
        }
        await db.collection("shopItems").doc(session.docId).update({ imageUrl });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Kupon rasmi yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showCouponDetailMenu(db, chatId, session.docId);
        return;
      }

      // Music Edits
      if (session.step === "editing_music_title") {
        await db.collection("music_tracks").doc(session.docId).update({ title: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Musiqa nomi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showMusicDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_music_artist") {
        await db.collection("music_tracks").doc(session.docId).update({ artist: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Ijrochi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showMusicDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_music_category") {
        await db.collection("music_tracks").doc(session.docId).update({ category: text.toLowerCase() });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Toifa yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showMusicDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_music_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileUrl(fileId);
          if (directUrl) audioUrl = directUrl;
        }
        await db.collection("music_tracks").doc(session.docId).update({ audioUrl });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Audio trek fayli yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showMusicDetailMenu(db, chatId, session.docId);
        return;
      }

      // Book Edits
      if (session.step === "editing_book_points") {
        const points = parseInt(text, 10) || 50;
        await db.collection("books").doc(session.docId).update({ pointsReward: points });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Kitob mukofoti ${points} PTS ga yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        return;
      } else if (session.step === "editing_book_title") {
        await db.collection("books").doc(session.docId).update({ title: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Kitob nomi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        return;
      } else if (session.step === "editing_book_author") {
        await db.collection("books").doc(session.docId).update({ author: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Kitob muallifi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        return;
      }

      // Audiobook Edits
      if (session.step === "editing_audio_title") {
        await db.collection("audiobooks").doc(session.docId).update({ title: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob nomi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showAudiobookDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_author") {
        await db.collection("audiobooks").doc(session.docId).update({ author: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Audio kitob muallifi yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showAudiobookDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_narrator") {
        await db.collection("audiobooks").doc(session.docId).update({ narrator: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Suxandon yangilandi:</b> ${text}`, { reply_markup: getAdminReplyKeyboard() });
        await showAudiobookDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_duration") {
        const dur = parseInt(text, 10) || 30;
        await db.collection("audiobooks").doc(session.docId).update({ durationMin: dur });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Davomiylik ${dur} daqiqaga yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showAudiobookDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_desc") {
        await db.collection("audiobooks").doc(session.docId).update({ desc: text });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Tavsif yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showAudiobookDetailMenu(db, chatId, session.docId);
        return;
      } else if (session.step === "editing_audio_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileUrl(fileId);
          if (directUrl) audioUrl = directUrl;
        }
        await db.collection("audiobooks").doc(session.docId).update({ audioUrl });
        await clearSession(db, fromId);
        await sendMessage(chatId, `✅ <b>Audio fayli muvaffaqiyatli yangilandi!</b>`, { reply_markup: getAdminReplyKeyboard() });
        await showAudiobookDetailMenu(db, chatId, session.docId);
        return;
      }

      // CREATION FLOWS
      const sData = session.data || {};

      // Book creation
      if (session.step === "book_title") {
        sData.title = text;
        await setSession(db, fromId, { step: "book_author", data: sData });
        await sendMessage(chatId, "📚 <b>(2/6) Kitob muallifini kiriting:</b>\n<i>(Masalan: Jeyms Klir)</i>");
        return;
      } else if (session.step === "book_author") {
        sData.author = text;
        await setSession(db, fromId, { step: "book_pages", data: sData });
        await sendMessage(chatId, "📚 <b>(3/6) Sahifalar sonini kiriting:</b>\n<i>(Masalan: 320)</i>");
        return;
      } else if (session.step === "book_pages") {
        sData.totalPages = parseInt(text, 10) || 100;
        await setSession(db, fromId, { step: "book_points", data: sData });
        await sendMessage(chatId, "📚 <b>(4/6) O'qiganlik uchun PTS mukofoti:</b>\n<i>(Masalan: 150)</i>");
        return;
      } else if (session.step === "book_points") {
        sData.pointsReward = parseInt(text, 10) || 50;
        await setSession(db, fromId, { step: "book_desc", data: sData });
        await sendMessage(chatId, "📚 <b>(5/6) Kitob haqida qisqacha tavsif:</b>\n<i>(Masalan: Odatlarni shakllantirish bo'yicha dunyo bestselleri)</i>");
        return;
      } else if (session.step === "book_desc") {
        sData.description = text;
        await setSession(db, fromId, { step: "book_file", data: sData });
        await sendMessage(chatId, "📚 <b>(6/6) Kitob PDF faylini shu yerga yuboring YOKI kitob yuklab olish havolasini yozing:</b>");
        return;
      } else if (session.step === "book_file") {
        let pdfUrl = text;
        if (message.document) {
          const waitMsg = await sendMessage(chatId, "⏳ <b>PDF fayli Firebase Storage-ga yuklanmoqda... Iltimos kuting.</b>");
          const fileUrl = await getTelegramFileUrl(message.document.file_id);
          if (fileUrl) {
            const fileName = message.document.file_name || `book_${Date.now()}.pdf`;
            const storageUrl = await downloadAndUploadToFirebase(
              fileUrl,
              `books/pdfs/${Date.now()}_${fileName}`,
              message.document.mime_type || "application/pdf"
            );
            if (storageUrl) pdfUrl = storageUrl;
          }
          if (waitMsg?.result?.message_id) {
            await deleteMessage(chatId, waitMsg.result.message_id);
          }
        }
        sData.pdfUrl = pdfUrl;
        sData.coverUrl = "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=400";
        sData.readCount = 0;
        sData.category = "O'zini rivojlantirish";
        sData.createdAt = FieldValue.serverTimestamp();

        await db.collection("books").add(sData);
        await clearSession(db, fromId);
        await sendMessage(chatId, `🎉 <b>Kitob muvaffaqiyatli saqlandi!</b>\n\n📖 <b>Nomi:</b> ${sData.title}\n✍️ <b>Muallif:</b> ${sData.author}\n⚡ <b>Mukofot:</b> ${sData.pointsReward} PTS`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }

      // Music creation
      if (session.step === "music_title") {
        sData.title = text;
        await setSession(db, fromId, { step: "music_artist", data: sData });
        await sendMessage(chatId, "🎵 <b>(2/5) Ijrochi yoki Muallif:</b>\n<i>(Masalan: Flowa Beats)</i>");
        return;
      } else if (session.step === "music_artist") {
        sData.artist = text;
        await setSession(db, fromId, { step: "music_category", data: sData });
        await sendMessage(chatId, "🎵 <b>(3/5) Kategoriya:</b>\n1. <code>workout</code>\n2. <code>focus</code>\n3. <code>relax</code>");
        return;
      } else if (session.step === "music_category") {
        sData.category = text.toLowerCase().includes("focus") ? "focus" : (text.toLowerCase().includes("relax") ? "relax" : "workout");
        await setSession(db, fromId, { step: "music_duration", data: sData });
        await sendMessage(chatId, "🎵 <b>(4/5) Davomiyligi (soniya):</b>\n<i>(Masalan: 180)</i>");
        return;
      } else if (session.step === "music_duration") {
        sData.durationSeconds = parseInt(text, 10) || 180;
        await setSession(db, fromId, { step: "music_file", data: sData });
        await sendMessage(chatId, "🎵 <b>(5/5) MP3 musiqa faylini yuboring yoki audio havolasini yozing:</b>");
        return;
      } else if (session.step === "music_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          const waitMsg = await sendMessage(chatId, "⏳ <b>Musiqa fayli Firebase Storage-ga yuklanmoqda... Iltimos kuting.</b>");
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileUrl(fileId);
          if (directUrl) {
            const fileName = message.audio?.file_name || message.document?.file_name || `track_${Date.now()}.mp3`;
            const mimeType = message.audio?.mime_type || message.document?.mime_type || "audio/mpeg";
            const storageUrl = await downloadAndUploadToFirebase(
              directUrl,
              `music_tracks/${Date.now()}_${fileName}`,
              mimeType
            );
            if (storageUrl) audioUrl = storageUrl;
          }
          if (waitMsg?.result?.message_id) {
            await deleteMessage(chatId, waitMsg.result.message_id);
          }
        }
        sData.audioUrl = audioUrl;
        sData.coverEmoji = sData.category === "focus" ? "🧠" : (sData.category === "relax" ? "🌊" : "⚡");
        sData.playCount = 0;
        sData.id = `track_${Date.now()}`;
        sData.createdAt = FieldValue.serverTimestamp();

        await db.collection("music_tracks").doc(sData.id).set(sData);
        await clearSession(db, fromId);
        await sendMessage(chatId, `🎉 <b>Musiqa muvaffaqiyatli saqlandi!</b>\n\n🎶 <b>Nomi:</b> ${sData.title}\n🎙️ <b>Ijrochi:</b> ${sData.artist}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }

      // Audiobook creation
      if (session.step === "audiobook_title") {
        sData.title = text;
        await setSession(db, fromId, { step: "audiobook_author", data: sData });
        await sendMessage(chatId, "🎧 <b>(2/6) Kitob muallifi:</b>\n<i>(Masalan: Jeyms Klir)</i>");
        return;
      } else if (session.step === "audiobook_author") {
        sData.author = text;
        await setSession(db, fromId, { step: "audiobook_narrator", data: sData });
        await sendMessage(chatId, "🎧 <b>(3/6) Suhxandon / Ovoz beruvchi:</b>\n<i>(Masalan: O‘zbekcha ovoz)</i>");
        return;
      } else if (session.step === "audiobook_narrator") {
        sData.narrator = text;
        await setSession(db, fromId, { step: "audiobook_duration", data: sData });
        await sendMessage(chatId, "🎧 <b>(4/6) Davomiyligi (daqiqa):</b>\n<i>(Masalan: 45)</i>");
        return;
      } else if (session.step === "audiobook_duration") {
        sData.durationMin = parseInt(text, 10) || 30;
        await setSession(db, fromId, { step: "audiobook_desc", data: sData });
        await sendMessage(chatId, "🎧 <b>(5/6) Qisqa tavsif yozing:</b>\n<i>(Masalan: Har kuni 1% yaxshilanish formulasi)</i>");
        return;
      } else if (session.step === "audiobook_desc") {
        sData.desc = text;
        sData.emoji = "🎧";
        await setSession(db, fromId, { step: "audiobook_file", data: sData });
        await sendMessage(chatId, "🎧 <b>(6/6) Audio faylni shu yerga yuboring YOKI audio havolasini yozing:</b>");
        return;
      } else if (session.step === "audiobook_file") {
        let audioUrl = text;
        if (message.audio || message.voice || message.document) {
          const waitMsg = await sendMessage(chatId, "⏳ <b>Audio kitob fayli Firebase Storage-ga yuklanmoqda... Iltimos kuting.</b>");
          const fileId = message.audio?.file_id || message.voice?.file_id || message.document?.file_id;
          const directUrl = await getTelegramFileUrl(fileId);
          if (directUrl) {
            const fileName = message.audio?.file_name || message.document?.file_name || `audiobook_${Date.now()}.mp3`;
            const mimeType = message.audio?.mime_type || message.document?.mime_type || "audio/mpeg";
            const storageUrl = await downloadAndUploadToFirebase(
              directUrl,
              `audiobooks/${Date.now()}_${fileName}`,
              mimeType
            );
            if (storageUrl) audioUrl = storageUrl;
          }
          if (waitMsg?.result?.message_id) {
            await deleteMessage(chatId, waitMsg.result.message_id);
          }
        }
        sData.audioUrl = audioUrl;
        sData.telegramUrl = "https://t.me/odat_fenix";
        sData.createdAt = FieldValue.serverTimestamp();

        await db.collection("audiobooks").add(sData);
        await clearSession(db, fromId);
        await sendMessage(chatId, `🎉 <b>Audio kitob muvaffaqiyatli saqlandi!</b>\n\n🎧 <b>Nomi:</b> ${sData.title}\n✍️ <b>Muallif:</b> ${sData.author}\n⏱️ <b>Davomiyligi:</b> ${sData.durationMin} daqiqa\n\nIlovadagi Audio kitoblar bo'limida real-vaqtda chiqdi! 🚀`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }

      // Gift creation
      if (session.step === "gift_title") {
        sData.title = text;
        await setSession(db, fromId, { step: "gift_type", data: sData });
        await sendMessage(chatId, "🎁 <b>(2/6) Mahsulot turi:</b>\n1. <code>gift</code> (Sovg'a)\n2. <code>coupon</code> (Kupon)");
        return;
      } else if (session.step === "gift_type") {
        sData.type = text.toLowerCase().includes("coupon") ? "coupon" : "gift";
        sData.requiresShipping = sData.type === "gift";
        await setSession(db, fromId, { step: "gift_points", data: sData });
        await sendMessage(chatId, "🎁 <b>(3/6) PTS narxi (Coins):</b>\n<i>(Masalan: 500 yoki 1000)</i>");
        return;
      } else if (session.step === "gift_points") {
        sData.pointsCost = parseInt(text, 10) || 100;
        await setSession(db, fromId, { step: "gift_desc", data: sData });
        await sendMessage(chatId, "🎁 <b>(4/6) Mahsulot tavsifi:</b>\n<i>(Masalan: ODAT sport idishi)</i>");
        return;
      } else if (session.step === "gift_desc") {
        sData.description = text;
        await setSession(db, fromId, { step: "gift_stock", data: sData });
        await sendMessage(chatId, "🎁 <b>(5/6) Ombordagi soni (stock):</b>\n<i>(Masalan: 50)</i>");
        return;
      } else if (session.step === "gift_stock") {
        sData.stock = parseInt(text, 10) || 10;
        await setSession(db, fromId, { step: "gift_image", data: sData });
        await sendMessage(chatId, "🎁 <b>(6/6) Mahsulot rasmini shu yerga yuboring YOKI rasm linkini yozing:</b>");
        return;
      } else if (session.step === "gift_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          const waitMsg = await sendMessage(chatId, "⏳ <b>Mahsulot rasmi Firebase Storage-ga yuklanmoqda... Iltimos kuting.</b>");
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) {
            const storageUrl = await downloadAndUploadToFirebase(
              directUrl,
              `shopItems/${Date.now()}_image.jpg`,
              "image/jpeg"
            );
            if (storageUrl) imageUrl = storageUrl;
          }
          if (waitMsg?.result?.message_id) {
            await deleteMessage(chatId, waitMsg.result.message_id);
          }
        }
        sData.imageUrl = imageUrl || "https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=400";
        sData.partnerName = "ODAT Rasmiy Do'koni";
        sData.isActive = true;
        sData.createdAt = FieldValue.serverTimestamp();

        await db.collection("shopItems").add(sData);
        await clearSession(db, fromId);
        await sendMessage(chatId, `🎉 <b>Mahsulot do'konga muvaffaqiyatli qo'shildi!</b>\n\n🛍️ <b>Nomi:</b> ${sData.title}\n⚡ <b>Narxi:</b> ${sData.pointsCost} PTS`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }

      // Coupon creation
      if (session.step === "coupon_title") {
        sData.title = text;
        sData.type = "coupon";
        sData.requiresShipping = false;
        await setSession(db, fromId, { step: "coupon_discount", data: sData });
        await sendMessage(chatId, "🎫 <b>(2/5) Chegirma matni:</b>\n<i>(Masalan: 30% OFF)</i>");
        return;
      } else if (session.step === "coupon_discount") {
        sData.discountText = text;
        await setSession(db, fromId, { step: "coupon_points", data: sData });
        await sendMessage(chatId, "🎫 <b>(3/5) PTS narxi:</b>\n<i>(Masalan: 200)</i>");
        return;
      } else if (session.step === "coupon_points") {
        sData.pointsCost = parseInt(text, 10) || 100;
        await setSession(db, fromId, { step: "coupon_desc", data: sData });
        await sendMessage(chatId, "🎫 <b>(4/5) Kupon tavsifi:</b>");
        return;
      } else if (session.step === "coupon_desc") {
        sData.description = text;
        await setSession(db, fromId, { step: "coupon_image", data: sData });
        await sendMessage(chatId, "🎫 <b>(5/5) Kupon rasmini yuboring yoki link yozing:</b>");
        return;
      } else if (session.step === "coupon_image") {
        let imageUrl = text;
        if (message.photo && message.photo.length > 0) {
          const photo = message.photo[message.photo.length - 1];
          const directUrl = await getTelegramFileUrl(photo.file_id);
          if (directUrl) imageUrl = directUrl;
        }
        sData.imageUrl = imageUrl || "https://images.unsplash.com/photo-1607083206869-4c7672e72a8a?w=400";
        sData.partnerName = "ODAT Hamkor Do'koni";
        sData.isActive = true;
        sData.createdAt = FieldValue.serverTimestamp();

        await db.collection("shopItems").add(sData);
        await clearSession(db, fromId);
        await sendMessage(chatId, `🎉 <b>Kupon muvaffaqiyatli yaratildi!</b>\n\n🎫 <b>Nomi:</b> ${sData.title}\n🏷️ <b>Chegirma:</b> ${sData.discountText}`, {
          reply_markup: getAdminReplyKeyboard()
        });
        return;
      }
    }

    // Direct file upload prompt
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

/**
 * Deletes ONLY players/users data, preserving all content (books, music, audiobooks, shopItems, admins).
 */
export async function cleanupPlayersDatabase(db) {
  const auth = getAuth();
  let usersDeleted = 0;
  let clansDeleted = 0;
  let proofsDeleted = 0;
  let loginsDeleted = 0;
  let tgUsersDeleted = 0;
  let authUsersDeleted = 0;

  // 1. Delete users and all subcollections
  const usersSnap = await db.collection("users").get();
  for (const doc of usersSnap.docs) {
    const subcollections = ["habits", "daily_quests", "focus_sessions", "notifications", "quests", "activity_logs", "badges", "points_history"];
    for (const sub of subcollections) {
      try {
        const subSnap = await doc.ref.collection(sub).get();
        for (const subDoc of subSnap.docs) {
          await subDoc.ref.delete();
        }
      } catch (_) {}
    }
    await doc.ref.delete();
    usersDeleted++;
  }

  // 2. Delete clans
  try {
    const clansSnap = await db.collection("clans").get();
    for (const doc of clansSnap.docs) {
      await doc.ref.delete();
      clansDeleted++;
    }
  } catch (_) {}

  // 3. Delete proofSessions
  try {
    const proofsSnap = await db.collection("proofSessions").get();
    for (const doc of proofsSnap.docs) {
      await doc.ref.delete();
      proofsDeleted++;
    }
  } catch (_) {}

  // 4. Delete loginRequests
  try {
    const loginsSnap = await db.collection("loginRequests").get();
    for (const doc of loginsSnap.docs) {
      await doc.ref.delete();
      loginsDeleted++;
    }
  } catch (_) {}

  // 5. Delete telegramUsers
  try {
    const tgSnap = await db.collection("telegramUsers").get();
    for (const doc of tgSnap.docs) {
      await doc.ref.delete();
      tgUsersDeleted++;
    }
  } catch (_) {}

  // 6. Delete bug_reports
  try {
    const bugSnap = await db.collection("bug_reports").get();
    for (const doc of bugSnap.docs) {
      await doc.ref.delete();
    }
  } catch (_) {}

  // 7. Delete Firebase Authentication users
  try {
    let nextPageToken;
    do {
      const listUsersResult = await auth.listUsers(100, nextPageToken);
      const uidsToDelete = listUsersResult.users.map((u) => u.uid);
      if (uidsToDelete.length > 0) {
        const deleteResult = await auth.deleteUsers(uidsToDelete);
        authUsersDeleted += deleteResult.successCount;
      }
      nextPageToken = listUsersResult.pageToken;
    } while (nextPageToken);
  } catch (err) {
    console.error("Auth users cleanup error:", err.message);
  }

  return {
    usersDeleted,
    clansDeleted,
    proofsDeleted,
    loginsDeleted,
    tgUsersDeleted,
    authUsersDeleted,
  };
}
