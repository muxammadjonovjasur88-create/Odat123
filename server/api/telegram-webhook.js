const { db } = require('../utils/firebase');
const { sendTelegramMessage } = require('../utils/telegram');

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

    if (!text.startsWith("/start")) {
      await sendTelegramMessage(
        token,
        chatId,
        "Salom! 👋 Flowa ilovasidan kod kiriting:\nSozlamalar → Tasodifiy Isbot → Telegram ulanishi",
      );
      return res.status(200).send("ok");
    }

    const parts = text.split(" ");
    const uid = parts[1]?.trim() ?? "";

    if (!uid) {
      await sendTelegramMessage(
        token,
        chatId,
        "❌ Kod topilmadi. Iltimos, Flowa ilovasidan to'liq kodni nusxalab yuboring.",
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
