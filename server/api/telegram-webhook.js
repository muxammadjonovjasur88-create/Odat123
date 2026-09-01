const { db, getAuth, FieldValue } = require('../utils/firebase');
const {
  sendTelegramMessage,
  sendTelegramMessageWithKeyboard,
  sendTelegramMessageWithWebAppButton,
  sendTelegramMessageWithInline,
  deleteTelegramMessage,
} = require('../utils/telegram');

const ADMIN_TELEGRAM_IDS = ["8774615237", "658069248"];

// Profanity / banned words dictionary
const BANNED_WORDS = [
  "harom", "jalap", "sik", "onangni", "itvachcha", "chmo", "dalbayob", "kot",
  "blyat", "suka", "xuy", "pizda", "ebat", "pidar", "fuck", "bitch", "asshole"
];

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  try {
    const token = process.env.TELEGRAM_BOT_TOKEN || "8855349705:AAGMa9cMyo62Fh8gThoC1xtuRyQwnwu6N4U";
    if (!token) {
      return res.status(500).send("No token configured");
    }

    const update = req.body;
    const message = update?.message;
    if (!message) {
      return res.status(200).send("ok");
    }

    const text = (message.text ?? "").trim();
    const chatId = String(message.chat?.id ?? "");
    const chatType = message.chat?.type || "private";
    const fromId = String(message.from?.id ?? chatId);
    const fromUser = message.from;
    const messageId = message.message_id;

    const isTelegramUserAdmin = async (id) => {
      if (!id) return false;
      const idStr = String(id);
      const envAdmins = (process.env.ADMIN_TELEGRAM_IDS || "8774615237,658069248")
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);
      if (ADMIN_TELEGRAM_IDS.includes(idStr) || envAdmins.includes(idStr)) return true;

      try {
        const adminDoc = await db.collection("admins").doc(idStr).get();
        if (adminDoc.exists && adminDoc.data()?.isActive !== false) return true;

        const querySnap = await db.collection("admins").where("telegramId", "==", idStr).limit(1).get();
        if (!querySnap.empty && querySnap.docs[0].data()?.isActive !== false) return true;
      } catch (_) {}

      return false;
    };

    // ──────────────────────────────────────────────────────────────────────────
    // 🛡️ 1. GURUH VA SUPERGURUH MODERATSIYASI (Group Moderation & Welcome)
    // ──────────────────────────────────────────────────────────────────────────
    if (chatType === "group" || chatType === "supergroup") {
      // 1.1 Yangi qo'shilgan a'zolarni kutib olish (Welcome Greeting)
      if (message.new_chat_members && message.new_chat_members.length > 0) {
        for (const newMember of message.new_chat_members) {
          if (newMember.is_bot && newMember.id === 8855349705) {
            await sendTelegramMessage(token, chatId, "👋 <b>Assalomu alaykum!</b>\nMen guruh xavfsizligini ta'minlovchi va yangi a'zolarni kutib oluvchi ODAT rasmiy botiman. Guruhda faqat rasm va do'stona xabarlar yozish mumkin. Reklama va havolalar avtomatik o'chiriladi. 🌿");
            continue;
          }
          if (newMember.is_bot) continue;

          const memberName = newMember.first_name || newMember.username || "Do'stimiz";
          const welcomeMsg = `🎉 <b>Xush kelibsiz, ${memberName}!</b>\n\n` +
            `🌿 <b>ODAT / Flowa</b> hamjamiyatiga xush kelibsiz!\n` +
            `Bu yerda biz har kuni yangi odatlar, sport, kitob mutolaasi va intizom orqali o'z maqsadlarimizga erishamiz. 🚀\n\n` +
            `📌 <b>Guruh qoidalari:</b>\n` +
            `• Reklama, begona havolalar (linklar) va kanal forwardlari qat'iyan taqiqlangan.\n` +
            `• Guruhda faqat oddiy xabarlar va bajarilgan vazifalarning isbot rasmlari qabul qilinadi. 🌿`;

          await sendTelegramMessage(token, chatId, welcomeMsg);
        }
        return res.status(200).send("ok");
      }

      // 1.2 Reklama / Linklar va Taqiqlangan xabarlarni tekshirish & O'chirish
      const senderIsAdmin = await isTelegramUserAdmin(fromId);
      if (!senderIsAdmin) {
        const fullContent = (message.text || message.caption || "").trim();
        const lowerText = fullContent.toLowerCase();

        // Check 1: URL / Link Regex in text or caption
        const hasLinkRegex = /(https?:\/\/[^\s]+)|(t\.me\/[^\s]+)|(telegram\.me\/[^\s]+)|(@[a-zA-Z0-9_]{4,})/i.test(fullContent);

        // Check 2: Telegram Link / Mention Entities (hidden hyperlinks)
        const entities = [...(message.entities || []), ...(message.caption_entities || [])];
        const hasLinkEntity = entities.some(e => ['url', 'text_link', 'mention'].includes(e.type));

        // Check 3: Forwarded messages from channels / other chats (reklama forwardlari)
        const isForwarded = Boolean(message.forward_from_chat || message.forward_from);

        // Check 4: Profanity / Odobsiz so'zlar
        const hasBannedWord = BANNED_WORDS.some(bw => lowerText.includes(bw));

        if (hasLinkRegex || hasLinkEntity || isForwarded || hasBannedWord) {
          await deleteTelegramMessage(token, chatId, messageId);

          const senderName = fromUser?.first_name || `@${fromUser?.username || 'Foydalanuvchi'}`;
          let warnReason = "reklama va begona havolalar";
          if (hasBannedWord) warnReason = "noo'rin/odobsiz so'zlar";
          else if (isForwarded) warnReason = "kanallardan xabar ulashish (forward)";

          const warnMsg = `⚠️ <b>Ogohlantirish!</b> ${senderName}, guruhimizda ${warnReason} taqiqlangan.\n` +
            `Faqat oddiy xabarlar va mashg'ulot isboti (rasmlar) yuborishingiz mumkin. 🌿`;

          await sendTelegramMessage(token, chatId, warnMsg);
          return res.status(200).send("ok");
        }
      }

      return res.status(200).send("ok");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 👑 2. ADMINISTRATOR BOSHQARUV PANELI (Real-Time Admin Panel)
    // ──────────────────────────────────────────────────────────────────────────
    const isAdmin = await isTelegramUserAdmin(fromId);

    if (isAdmin) {
      const adminKeyboard = [
        [{ text: "📊 Statistika" }, { text: "👥 Foydalanuvchilar" }],
        [{ text: "🤖 AI Tahlili" }, { text: "📢 Xabar Yuborish" }],
        [{ text: "📱 WebApp Panel" }],
      ];

      // Admin Start / Menu
      if (text === "/start" || text === "/admin" || text === "/menu" || text === "start") {
        const welcomeMsg = `👑 <b>Assalomu alaykum, Hurmatli Administrator!</b>\n\n` +
          `ODAT / Flowa boshqaruv paneliga xush kelibsiz.\n` +
          `Siz to'liq administratorlik huquqiga egasiz. Quyidagi menyudan foydalaning:`;

        await sendTelegramMessageWithKeyboard(token, chatId, welcomeMsg, adminKeyboard);
        return res.status(200).send("ok");
      }

      // 📊 Statistika
      if (text === "/stats" || text === "/statistika" || text === "📊 Statistika") {
        const usersSnap = await db.collection("users").get();
        const totalUsers = usersSnap.size;

        let premiumUsers = 0;
        let totalPoints = 0;
        let telegramVerified = 0;
        usersSnap.forEach((doc) => {
          const data = doc.data();
          if (data.isPremium) premiumUsers++;
          if (data.telegramQuestCompleted) telegramVerified++;
          totalPoints += (data.totalPoints || 0);
        });

        const clansSnap = await db.collection("clans").get();
        const totalClans = clansSnap.size;

        const statsMsg = `📊 <b>ODAT / Flowa — Real-Vaqt Admin Statistikasi</b> 🚀\n\n` +
          `👥 <b>Jami Foydalanuvchilar:</b> ${totalUsers} ta\n` +
          `💎 <b>Pro Premium A'zolar:</b> ${premiumUsers} ta\n` +
          `🛡️ <b>Mavjud Klanlar:</b> ${totalClans} ta\n` +
          `✈️ <b>Telegram Tasdiqlangan:</b> ${telegramVerified} ta\n` +
          `🏆 <b>Jami Jamlangan Ballar:</b> ${totalPoints.toLocaleString()} PTS\n\n` +
          `⚡ <i>Barcha ma'lumotlar Firebase Cloud bazasidan jonli olindi.</i>`;

        await sendTelegramMessage(token, chatId, statsMsg);
        return res.status(200).send("ok");
      }

      // 👥 Foydalanuvchilar
      if (text === "👥 Foydalanuvchilar" || text === "/users") {
        const usersSnap = await db.collection("users").orderBy("createdAt", "desc").limit(10).get();
        const totalCount = (await db.collection("users").get()).size;

        let userListText = `👥 <b>Foydalanuvchilar Nazorati</b> (Jami: ${totalCount} ta)\n\n` +
          `🌟 <b>Eng so'nggi ro'yxatdan o'tganlar:</b>\n\n`;

        let i = 1;
        usersSnap.forEach((doc) => {
          const d = doc.data();
          const name = d.displayName || d.name || "Noma'lum";
          const region = d.region || "Navoiy";
          const phone = d.phoneNumber ? ` (${d.phoneNumber})` : "";
          const pts = d.totalPoints || 0;
          const prem = d.isPremium ? "💎 Pro" : "Oddiy";
          userListText += `${i}. <b>${name}</b>${phone}\n   📍 ${region} | ⚡ ${pts} PTS | [${prem}]\n`;
          i++;
        });

        await sendTelegramMessage(token, chatId, userListText);
        return res.status(200).send("ok");
      }

      // 🤖 AI Tahlili
      if (text === "🤖 AI Tahlili" || text === "/ai_stats") {
        const aiSnap = await db.collection("aiAnalytics").orderBy("timestamp", "desc").limit(50).get();
        let booksCount = 0;
        let workoutCount = 0;
        let habitsCount = 0;
        const recentQueries = [];

        aiSnap.forEach((doc) => {
          const d = doc.data();
          if (d.category === "books") booksCount++;
          else if (d.category === "workout") workoutCount++;
          else if (d.category === "habits") habitsCount++;
          if (d.query && recentQueries.length < 5) recentQueries.push(`• "${d.query}"`);
        });

        const aiMsg = `🤖 <b>ODAT AI Yordamchi Tahlili</b> 🧠\n\n` +
          `📚 <b>Kitoblar & Kutubxona so'rovlari:</b> ${booksCount}\n` +
          `🏃 <b>Mashg'ulotlar & Sport:</b> ${workoutCount}\n` +
          `🎯 <b>Intizom & Odatiy Rejalar:</b> ${habitsCount}\n\n` +
          (recentQueries.length > 0 ? `🔥 <b>So'nggi savollar:</b>\n${recentQueries.join("\n")}\n\n` : "") +
          `💡 <i>AI foydalanuvchilar qiziqishlarini avtomatik tahlil qilib boradi.</i>`;

        await sendTelegramMessage(token, chatId, aiMsg);
        return res.status(200).send("ok");
      }

      // 📱 WebApp Panel
      if (text === "📱 WebApp Panel" || text === "📱 Admin Panel") {
        const webAppUrl = process.env.ADMIN_WEBAPP_URL || "https://flowa-4fca9.web.app";
        await sendTelegramMessageWithWebAppButton(
          token,
          chatId,
          "🛍️ <b>ODAT Admin WebApp Paneli</b>\n\nQuyidagi tugma orqali to'liq admin boshqaruv panelini ochishingiz mumkin.",
          "📱 WebApp Panelni Ochish",
          webAppUrl,
        );
        return res.status(200).send("ok");
      }

      // 📢 Xabar Yuborish
      if (text === "📢 Xabar Yuborish") {
        await sendTelegramMessage(
          token,
          chatId,
          "📢 <b>Barcha foydalanuvchilarga xabar yuborish:</b>\n\n" +
          "Format: <code>/broadcast Sizning xabaringiz</code>\n\n" +
          "Masalan: <code>/broadcast Bugun soat 20:00 da Yangi Boss Reydi Jangi bo'lib o'tadi! 🔥</code>"
        );
        return res.status(200).send("ok");
      }

      // /broadcast xabar
      if (text.startsWith("/broadcast ")) {
        const broadcastBody = text.replace("/broadcast ", "").trim();
        if (!broadcastBody) {
          await sendTelegramMessage(token, chatId, "Iltimos, xabar matnini kiriting: /broadcast Sizning xabaringiz");
          return res.status(200).send("ok");
        }

        const usersSnap = await db.collection("users").get();
        let sentCount = 0;

        const batchPromises = usersSnap.docs.map(async (userDoc) => {
          const uData = userDoc.data();
          if (uData.telegramChatId) {
            try {
              await sendTelegramMessage(token, uData.telegramChatId, `📢 <b>Dasturchidan Xabar:</b>\n\n${broadcastBody}`);
              sentCount++;
            } catch (_) {}
          }
        });

        await Promise.allSettled(batchPromises);
        await sendTelegramMessage(token, chatId, `✅ Xabar ${sentCount} ta foydalanuvchiga muvaffaqiyatli yetkazildi!`);
        return res.status(200).send("ok");
      }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 📱 3. TELEFON RAQAM ORQALI RO'YXATDAN O'TISH & AKKAUNTNI QAYTA TIKLASH
    // ──────────────────────────────────────────────────────────────────────────
    if (message.contact) {
      let rawPhone = message.contact.phone_number || "";
      if (!rawPhone.startsWith("+")) rawPhone = "+" + rawPhone;

      const firstName = message.contact.first_name || fromUser?.first_name || "Foydalanuvchi";
      const lastName = message.contact.last_name || fromUser?.last_name || "";
      const fullName = `${firstName} ${lastName}`.trim();

      // Check if user already exists by phone or telegramId
      let targetUid = null;
      let isExisting = false;
      let existingData = null;

      const userByPhoneSnap = await db.collection("users").where("phoneNumber", "==", rawPhone).limit(1).get();
      if (!userByPhoneSnap.empty) {
        targetUid = userByPhoneSnap.docs[0].id;
        existingData = userByPhoneSnap.docs[0].data();
        isExisting = true;
      } else {
        const userByTgSnap = await db.collection("users").where("telegramId", "==", fromId).limit(1).get();
        if (!userByTgSnap.empty) {
          targetUid = userByTgSnap.docs[0].id;
          existingData = userByTgSnap.docs[0].data();
          isExisting = true;
        }
      }

      if (isExisting && targetUid) {
        // AKKAUNTNI QAYTA TIKLASH (Account Recovery)
        await db.collection("users").doc(targetUid).set({
          telegramId: fromId,
          telegramChatId: chatId,
          phoneNumber: rawPhone,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        const authCode = Math.floor(100000 + Math.random() * 900000).toString();
        await db.collection("telegramAuthCodes").doc(authCode).set({
          code: authCode,
          uid: targetUid,
          phoneNumber: rawPhone,
          telegramId: fromId,
          chatId: chatId,
          createdAt: Date.now(),
          expiresAt: Date.now() + 10 * 60 * 1000,
          used: false,
        });

        const restoreMsg = `🎉 <b>Akkauntingiz Muvaffaqiyatli Qayta Tiklandi!</b>\n\n` +
          `👤 <b>Ism:</b> ${existingData?.name || fullName}\n` +
          `📱 <b>Telefon:</b> ${rawPhone}\n` +
          `⚡ <b>Mavjud Bal:</b> ${existingData?.totalPoints || 0} PTS\n` +
          `🔥 <b>Streak:</b> ${existingData?.streak || 0} kun\n\n` +
          `🔑 <b>Ilovaga kirish kodingiz:</b> <code>${authCode}</code>\n\n` +
          `Ushbu 6 xonali kodni Odat ilovasidagi Telegram orqali kirish bo'limiga kiriting. 🚀🌿`;

        await sendTelegramMessage(token, chatId, restoreMsg);
        return res.status(200).send("ok");
      } else {
        // YANGI FOYDALANUVCHINI RO'YXATGA OLISH (New Registration)
        let newUid = `tg_${fromId}`;
        try {
          const userRecord = await getAuth().createUser({
            displayName: fullName,
            phoneNumber: rawPhone,
          });
          newUid = userRecord.uid;
        } catch (_) {}

        const now = new Date();
        const yyyy = now.getFullYear();
        const startOfYear = new Date(yyyy, 0, 1);
        const weekNum = Math.ceil((((now.getTime() - startOfYear.getTime()) / 86400000) + startOfYear.getDay() + 1) / 7);
        const weekId = `${yyyy}-W${String(weekNum).padStart(2, "0")}`;

        await db.collection("users").doc(newUid).set({
          name: fullName,
          phoneNumber: rawPhone,
          telegramId: fromId,
          telegramChatId: chatId,
          avatar: "leaf",
          streak: 0,
          longestStreak: 0,
          totalPoints: 100, // +100 welcome bonus
          fenixCoins: 50,
          freezes: 2,
          isPremium: false,
          currentWeekId: weekId,
          createdAt: FieldValue.serverTimestamp(),
        }, { merge: true });

        const authCode = Math.floor(100000 + Math.random() * 900000).toString();
        await db.collection("telegramAuthCodes").doc(authCode).set({
          code: authCode,
          uid: newUid,
          phoneNumber: rawPhone,
          telegramId: fromId,
          chatId: chatId,
          createdAt: Date.now(),
          expiresAt: Date.now() + 10 * 60 * 1000,
          used: false,
        });

        const regSuccessMsg = `🎉 <b>Tabriklaymiz! Siz Odat tizimida ro'yxatdan o'tdingiz!</b>\n\n` +
          `👤 <b>Ism:</b> ${fullName}\n` +
          `📱 <b>Telefon:</b> ${rawPhone}\n` +
          `🎁 <b>Xush kelibsiz bonusi:</b> +100 PTS va +50 Coins berildi! ⚡\n\n` +
          `🔑 <b>Ilovaga kirish kodingiz:</b> <code>${authCode}</code>\n\n` +
          `Ushbu 6 xonali kodni ilovada Telegram orqali kirish joyiga kiriting. 🚀🌿`;

        await sendTelegramMessage(token, chatId, regSuccessMsg);
        return res.status(200).send("ok");
      }
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 👤 4. ODDIY FOYDALANUVCHILAR /START VA TELEGRAM OBUNA TEKSHIRUVI
    // ──────────────────────────────────────────────────────────────────────────
    if (text === "/start" || text === "start" || text.startsWith("/start")) {
      // 4.1 Kanal obunasini tekshirish (Group / Channel check)
      let isSubscribed = false;
      try {
        const checkRes = await fetch(`https://api.telegram.org/bot${token}/getChatMember?chat_id=@odat_fenix&user_id=${fromId}`);
        const checkJson = await checkRes.json();
        const st = checkJson?.result?.status;
        isSubscribed = st === "member" || st === "administrator" || st === "creator";
      } catch (_) {}

      const contactKeyboard = [
        [{ text: "📱 Telefon raqamni ulashish (Kirish / Tiklash)", request_contact: true }],
      ];

      const welcomeUserMsg = `🌿 <b>Assalomu alaykum va ODAT / Flowa ilovasiga xush kelibsiz!</b>\n\n` +
        `Bu bot orqali siz ilovaga tez va xavfsiz kirishingiz, yo'qolgan akkauntingizni qayta tiklashingiz va yangi vazifalardan xabardor bo'lishingiz mumkin.\n\n` +
        `📲 <b>Davom etish uchun quyidagi «📱 Telefon raqamni ulashish» tugmasini bosing:</b>`;

      const inlineButtons = [
        [{ text: "📢 Rasmiy Kanalga A'zo Bo'lish", url: "https://t.me/odat_fenix" }],
      ];

      await sendTelegramMessageWithInline(token, chatId, welcomeUserMsg, inlineButtons);
      await sendTelegramMessageWithKeyboard(token, chatId, "👇 Raqamingizni yuborish uchun pastdagi tugmani bosing:", contactKeyboard);
      return res.status(200).send("ok");
    }

    // ──────────────────────────────────────────────────────────────────────────
    // 5. YORDAMCHI /CODE YOKI /LOGIN
    // ──────────────────────────────────────────────────────────────────────────
    if (text === "/login" || text === "/code") {
      const code = Math.floor(100000 + Math.random() * 900000).toString();
      await db.collection("telegramAuthCodes").doc(code).set({
        code,
        telegramId: fromId,
        chatId: chatId,
        createdAt: Date.now(),
        expiresAt: Date.now() + 10 * 60 * 1000,
        used: false,
      });

      await sendTelegramMessage(
        token,
        chatId,
        `🔑 <b>Odat ilovasiga kirish kodingiz:</b> <code>${code}</code>\n\n` +
        `⏰ Bu kod <b>10 daqiqa</b> davomida amal qiladi. Uni ilovadagi Telegram oynasiga kiriting. 🌿`,
      );
      return res.status(200).send("ok");
    }

    res.status(200).send("ok");
  } catch (error) {
    console.error('Error handling telegram webhook:', error);
    res.status(500).send("Internal Error");
  }
};
