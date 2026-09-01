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

async function sendTelegramMessageWithKeyboard(token, chatId, text, keyboard) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
      reply_markup: {
        keyboard: keyboard,
        resize_keyboard: true,
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

async function deleteTelegramMessage(token, chatId, messageId) {
  const url = `https://api.telegram.org/bot${token}/deleteMessage`;
  try {
    await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        message_id: messageId,
      }),
    });
  } catch (_) {}
}

async function sendTelegramMessageWithInline(token, chatId, text, inlineKeyboard) {
  const url = `https://api.telegram.org/bot${token}/sendMessage`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text: text,
      parse_mode: "HTML",
      reply_markup: {
        inline_keyboard: inlineKeyboard,
      },
    }),
  });
  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Telegram API ${res.status}: ${detail}`);
  }
  return res.json();
}

module.exports = {
  sendTelegramMessage,
  sendTelegramMessageWithKeyboard,
  sendTelegramMessageWithWebAppButton,
  sendTelegramMessageWithInline,
  deleteTelegramMessage,
};

