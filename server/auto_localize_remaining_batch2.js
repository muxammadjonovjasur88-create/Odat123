const fs = require('fs');

const extraUz = {
  common: {
    cancel: "Bekor qilish",
    delete: "O‘chirish",
    exit: "Chiqish"
  },
  knowledge: {
    listen_telegram: "Telegramda Tinglash (@odat_fenix)",
    accuracy: "Aniqlik"
  },
  running: {
    stop_running_title: "Yugurishni to‘xtatmoqchimisiz?",
    stop_running_desc: "Yugurish to‘xtatilsa joriy ochilgan marshrut saqlanmaydi."
  }
};

const extraRu = {
  common: {
    cancel: "Отмена",
    delete: "Удалить",
    exit: "Выход"
  },
  knowledge: {
    listen_telegram: "Слушать в Telegram (@odat_fenix)",
    accuracy: "Точность"
  },
  running: {
    stop_running_title: "Хотите остановить пробежку?",
    stop_running_desc: "Если остановить пробежку, текущий маршрут не сохранится."
  }
};

const extraEn = {
  common: {
    cancel: "Cancel",
    delete: "Delete",
    exit: "Exit"
  },
  knowledge: {
    listen_telegram: "Listen on Telegram (@odat_fenix)",
    accuracy: "Accuracy"
  },
  running: {
    stop_running_title: "Do you want to stop running?",
    stop_running_desc: "If stopped now, the current open route will not be saved."
  }
};

function deepMerge(target, source) {
  for (const k of Object.keys(source)) {
    if (source[k] instanceof Object && !Array.isArray(source[k])) {
      target[k] = target[k] || {};
      deepMerge(target[k], source[k]);
    } else {
      target[k] = source[k];
    }
  }
}

const locales = [
  { code: 'uz', extra: extraUz },
  { code: 'ru', extra: extraRu },
  { code: 'en', extra: extraEn },
  { code: 'uz_CR', extra: extraUz }
];

for (const loc of locales) {
  const p = `assets/translations/${loc.code}.json`;
  if (fs.existsSync(p)) {
    const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
    deepMerge(raw, loc.extra);
    fs.writeFileSync(p, JSON.stringify(raw, null, 2), 'utf8');
    console.log(`Injected batch 2 keys into ${p}`);
  }
}

const replacements = [
  { target: "'Diqqat'", repl: "'clan.attention'.tr()" },
  { target: "'Tushunarli'", repl: "'clan.understood'.tr()" },
  { target: "'Telegramda Tinglash (@odat_fenix)'", repl: "'knowledge.listen_telegram'.tr()" },
  { target: "'Aniqlik'", repl: "'knowledge.accuracy'.tr()" },
  { target: "'Bekor qilish'", repl: "'common.cancel'.tr()" },
  { target: "'O‘zgartirish'", repl: "'profile.change'.tr()" },
  { target: "'Takrorlash:'", repl: "'reminders.repeat_label'.tr()" },
  { target: "'O‘chirish'", repl: "'common.delete'.tr()" },
  { target: "'Yugurishni to‘xtatmoqchimisiz?'", repl: "'running.stop_running_title'.tr()" },
  { target: "'Yugurish to‘xtatilsa joriy ochilgan marshrut saqlanmaydi.'", repl: "'running.stop_running_desc'.tr()" },
  { target: "'Chiqish'", repl: "'common.exit'.tr()" }
];

const targetFiles = [
  'lib/features/clan/presentation/screens/clan_detail_screen.dart',
  'lib/features/knowledge/presentation/screens/audiobooks_screen.dart',
  'lib/features/knowledge/presentation/screens/subject_quiz_screen.dart',
  'lib/features/profile/presentation/widgets/inventory_modal.dart',
  'lib/features/reminders/presentation/screens/add_reminder_screen.dart',
  'lib/features/reminders/presentation/widgets/reminder_card.dart',
  'lib/features/running/presentation/screens/running_screen.dart'
];

for (const file of targetFiles) {
  if (!fs.existsSync(file)) continue;
  let content = fs.readFileSync(file, 'utf8');
  let orig = content;
  for (const r of replacements) {
    if (content.includes(r.target)) {
      if (!content.includes('package:easy_localization/easy_localization.dart')) {
        content = "import 'package:easy_localization/easy_localization.dart';\n" + content;
      }
      content = content.split(r.target).join(r.repl);
    }
  }
  if (content !== orig) {
    fs.writeFileSync(file, content, 'utf8');
    console.log(`Updated ${file}`);
  }
}
