const fs = require('fs');

function deepMerge(target, source) {
  for (const key of Object.keys(source)) {
    if (source[key] instanceof Object && key in target && target[key] instanceof Object) {
      Object.assign(source[key], deepMerge(target[key], source[key]));
    }
  }
  Object.assign(target || {}, source);
  return target;
}

// Function to safely parse JSON strings that might have duplicate keys in raw text by regex or AST
function parseAndMerge(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  // Simple JSON.parse in JS will take the last occurrence of duplicate keys,
  // so let's check specifically for multiple "ai_assistant" occurrences
  const regex = /"ai_assistant"\s*:\s*\{([^}]+)\}/g;
  let matches = [];
  let m;
  while ((m = regex.exec(content)) !== null) {
    try {
      const parsed = JSON.parse(`{${m[1]}}`);
      matches.push(parsed);
    } catch (_) {}
  }

  const base = JSON.parse(content);
  if (matches.length > 1) {
    base.ai_assistant = base.ai_assistant || {};
    for (const piece of matches) {
      Object.assign(base.ai_assistant, piece);
    }
  }
  return base;
}

const locales = ['uz', 'ru', 'en', 'uz_CR'];
const data = {};

for (const loc of locales) {
  const p = `assets/translations/${loc}.json`;
  if (fs.existsSync(p)) {
    data[loc] = parseAndMerge(p);
  }
}

// Ensure ai_assistant in all locales has all keys
const aiUz = {
  title: "ODAT AI Yordamchi",
  subtitle: "Kunlik reja & Ovozli buyruqlar",
  welcome: "Assalomu alaykum! Men ODAT shaxsiy AI yordamchingizman. 🎙️ Ovozli buyruq bering yoki yozing. Reja tuzish, odat shakllantirish yoki eslatma qo‘yishda yordam beraman!",
  thinking: "AI o‘ylamoqda...",
  input_hint: "Vazifa yoki savol yozing...",
  voice_badge: "Ovozli buyruq",
  voice_listening: "Tinglanmoqda... Gapiring",
  voice_limit_reached: "Bugungi ovozli xabarlar limitingiz tugadi",
  mic_permission_denied: "Mikrofon ruxsati berilmadi."
};

const aiRu = {
  title: "ODAT AI Помощник",
  subtitle: "Дневной план и голосовые команды",
  welcome: "Здравствуйте! Я ваш персональный ИИ-помощник ODAT. 🎙️ Отправьте голосовое сообщение или напишите. Помогу составить план, выработать привычку или поставить напоминание!",
  thinking: "ИИ думает...",
  input_hint: "Напишите задачу или вопрос...",
  voice_badge: "Голосовая команда",
  voice_listening: "Слушаю... Говорите",
  voice_limit_reached: "Лимит голосовых сообщений на сегодня исчерпан",
  mic_permission_denied: "Разрешение на микрофон не предоставлено."
};

const aiEn = {
  title: "ODAT AI Assistant",
  subtitle: "Daily planning & Voice commands",
  welcome: "Hello! I am your personal ODAT AI assistant. 🎙️ Send a voice message or type. I'll help you plan, build habits, or set reminders!",
  thinking: "AI is thinking...",
  input_hint: "Type a task or question...",
  voice_badge: "Voice command",
  voice_listening: "Listening... Speak now",
  voice_limit_reached: "Daily voice message limit reached",
  mic_permission_denied: "Microphone permission was not granted."
};

const aiUzCr = {
  title: "ODAT AI Ёрдамчи",
  subtitle: "Кунлик режа & Овозли буйруқлар",
  welcome: "Ассалому алайкум! Мен ODAT шахсий AI ёрдамчингизман. 🎙️ Овозли буйруқ беринг ёки ёзинг. Режа тузиш, одат шакллантириш ёки эслатма қўйишда ёрдам бераман!",
  thinking: "AI ўйламоқда...",
  input_hint: "Вазифа ёки савол ёзинг...",
  voice_badge: "Овозли буйруқ",
  voice_listening: "Тингланмоқда... Гапиринг",
  voice_limit_reached: "Бугунги овозли хабарлар лимитингиз тугади",
  mic_permission_denied: "Микрофон рухсати берилмади."
};

data['uz'].ai_assistant = aiUz;
data['ru'].ai_assistant = aiRu;
if (data['en']) data['en'].ai_assistant = aiEn;
if (data['uz_CR']) data['uz_CR'].ai_assistant = aiUzCr;

// Also ensure missing reminders keys in EN
if (data['en'] && !data['en'].reminders) data['en'].reminders = {};
if (data['en']) {
  data['en'].reminders = Object.assign({
    new_goal: "New Goal",
    tab_active: "Active",
    tab_past: "Past",
    tab_completed: "Completed",
    empty_active_title: "No Active Goals",
    empty_active_sub: "Create a new goal to start your journey",
    empty_past_title: "No Past Goals",
    empty_past_sub: "Past due goals will appear here",
    empty_completed_title: "No Completed Goals",
    empty_completed_sub: "Completed goals will be archived here"
  }, data['en'].reminders || {});
}

for (const loc of locales) {
  if (data[loc]) {
    fs.writeFileSync(`assets/translations/${loc}.json`, JSON.stringify(data[loc], null, 2), 'utf8');
    console.log(`Updated assets/translations/${loc}.json`);
  }
}
