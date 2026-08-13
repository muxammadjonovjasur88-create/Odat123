const { db, getAuth, FieldValue } = require('../utils/firebase');
const { sendTelegramMessage, sendTelegramMessageWithWebAppButton } = require('../utils/telegram');

module.exports = async function handler(req, res) {
  if (req.method !== "POST") {
    return res.status(405).send("Method Not Allowed");
  }

  try {
    const token = process.env.TELEGRAM_BOT_TOKEN;
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
    const fromId = String(message.from?.id ?? chatId);

    // /admin buyrug'ini tekshiramiz
    if (text === "/admin" || text.startsWith("/admin")) {
      const isTelegramUserAdmin = async (id) => {
        if (!id) return false;
        const idStr = String(id);
        const envAdmins = (process.env.ADMIN_TELEGRAM_IDS || "8774615237").split(",").map((s) => s.trim()).filter(Boolean);
        if (envAdmins.includes(idStr)) return true;

        const adminDoc = await db.collection("admins").doc(idStr).get();
        if (adminDoc.exists && adminDoc.data()?.isActive !== false) return true;

        const querySnap = await db.collection("admins").where("telegramId", "==", idStr).limit(1).get();
        if (!querySnap.empty && querySnap.docs[0].data()?.isActive !== false) return true;

        return false;
      };

      const isAdmin = await isTelegramUserAdmin(fromId);
      if (!isAdmin) {
        await sendTelegramMessage(token, chatId, "❌ Bu buyruq faqat administratorlar uchun.");
        return res.status(200).send("ok");
      }

      const webAppUrl = process.env.ADMIN_WEBAPP_URL || "https://flowa-4fca9.web.app";
      await sendTelegramMessageWithWebAppButton(
        token,
        chatId,
        "🛍️ <b>Odat Admin Paneliga xush kelibsiz!</b>\n\n" +
        "Quyidagi tugma orqali Do'kon mahsulotlari va sovg'a buyurtmalarini boshqarishingiz mumkin.",
        "📱 Admin Panelni ochish",
        webAppUrl,
      );
      return res.status(200).send("ok");
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
          token,
          chatId,
          "❌ <b>Kirish so'rovi topilmadi.</b>\n\nIltimos, Odat ilovasiga qaytib, qayta urinib ko'ring. 🌿",
        );
        return res.status(200).send("ok");
      }

      const reqData = reqDoc.data() || {};
      if (reqData.status !== "pending") {
        await sendTelegramMessage(
          token,
          chatId,
          "❌ <b>Bu kirish so'rovi allaqachon ishlatilgan yoki bekor qilingan.</b> 🌿",
        );
        return res.status(200).send("ok");
      }

      if (Date.now() > (reqData.expiresAt || 0)) {
        await reqRef.update({ status: "expired" });
        await sendTelegramMessage(
          token,
          chatId,
          "⏰ <b>Kirish so'rovi vaqti tugagan (5 daqiqa).</b>\n\nIlovadan yangi so'rov yuboring. 🌿",
        );
        return res.status(200).send("ok");
      }

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
        await db.collection("users").doc(targetUid).set({
          telegramId: fromId,
          telegramChatId: chatId,
        }, { merge: true });
      } else {
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

      const customToken = await getAuth().createCustomToken(targetUid);

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

      await sendTelegramMessage(token, chatId, successMsg);
      return res.status(200).send("ok");
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
        token,
        chatId,
        `🔑 <b>Odat ilovasiga kirish kodingiz:</b> <code>${code}</code>\n\n` +
        `⏰ Bu kod <b>5 daqiqa</b> davomida amal qiladi.\n` +
        `Ushbu kodni Odat ilovasidagi Telegram kirish oynasiga kiritib tizimga kiring. 🌿`,
      );
      return res.status(200).send("ok");
    }

    if (!uid) {
      await sendTelegramMessage(
        token,
        chatId,
        "❌ Kod topilmadi. Iltimos, Odat ilovasidan to'liq kodni nusxalab yuboring.",
      );
      return res.status(200).send("ok");
    }

    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      await sendTelegramMessage(
        token,
        chatId,
        "❌ Foydalanuvchi topilmadi. Iltimos, kod to'g'riligini tekshiring.",
      );
      return res.status(200).send("ok");
    }

    await db.collection("users").doc(uid).update({telegramChatId: chatId});

    const name = userDoc.data()?.name ?? "Foydalanuvchi";
    await sendTelegramMessage(
      token,
      chatId,
      `✅ Muvaffaqiyatli ulandi, ${name}!\n\n` +
      "Endi do'stlaringiz isbot yuborganida yoki o'tkazib yuborganida bu yerda xabar olasiz. 🌿",
    );

    res.status(200).send("ok");
  } catch (error) {
    console.error('Error handling telegram webhook:', error);
    res.status(500).send("Internal Error");
  }
};
