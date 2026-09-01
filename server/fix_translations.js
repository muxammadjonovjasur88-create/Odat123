const fs = require('fs');

const uzPath = 'assets/translations/uz.json';
const ruPath = 'assets/translations/ru.json';
const enPath = 'assets/translations/en.json';

const uz = JSON.parse(fs.readFileSync(uzPath, 'utf8'));
const ru = JSON.parse(fs.readFileSync(ruPath, 'utf8'));
const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));

// Specific translations for the identified missing keys
const translations = {
  'lobby.member_count.few': {
    uz: '{} aʼzo',
    ru: '{} участника',
    en: '{} members'
  },
  'lobby.member_count.many': {
    uz: '{} aʼzolar',
    ru: '{} участников',
    en: '{} members'
  },
  'leaderboard.global_leaderboard': {
    uz: 'Global Reyting',
    ru: 'Глобальный рейтинг',
    en: 'Global Leaderboard'
  },
  'progress.see_top_players': {
    uz: 'Eng yaxshi o‘yinchilarni ko‘rish',
    ru: 'Посмотреть лучших игроков',
    en: 'See Top Players'
  },
  'addgoal.focus_mode': {
    uz: 'Fokus rejimi',
    ru: 'Режим фокуса',
    en: 'Focus Mode'
  },
  'perm.manage_desc': {
    uz: 'Barcha fayllarni boshqarish va zaxiralash uchun ruxsat.',
    ru: 'Разрешение на управление файлами и резервное копирование.',
    en: 'Permission to manage files and backups.'
  },
  'perm.notification_title': {
    uz: 'Bildirishnomalar',
    ru: 'Уведомления',
    en: 'Notifications'
  },
  'perm.notification_desc': {
    uz: 'Vazifalar, eslatmalar va janglar haqida xabardor bo‘lish.',
    ru: 'Оповещения о задачах, напоминаниях и битвах.',
    en: 'Alerts for tasks, reminders, and battles.'
  },
  'perm.exact_alarm_title': {
    uz: 'Aniq Budilnik',
    ru: 'Точный Будильник',
    en: 'Exact Alarm'
  },
  'perm.exact_alarm_desc': {
    uz: 'Eslatmalarni o‘z vaqtida aniq jiringlashini ta’minlaydi.',
    ru: 'Гарантирует срабатывание будильника точно в срок.',
    en: 'Ensures alarms ring precisely on time.'
  },
  'perm.battery_title': {
    uz: 'Batareya optimallashuvi',
    ru: 'Оптимизация батареи',
    en: 'Battery Optimization'
  },
  'perm.battery_desc': {
    uz: 'Ilova fonda to‘xtab qolmasligi va eslatmalar o‘z vaqtida ishlashi uchun.',
    ru: 'Чтобы приложение не закрывалось в фоне и напоминания работали.',
    en: 'Prevents the app from sleeping in background so reminders trigger reliably.'
  },
  'perm.audio_title': {
    uz: 'Audio fayllar',
    ru: 'Аудиофайлы',
    en: 'Audio Files'
  },
  'perm.audio_desc': {
    uz: 'Budilnik va signallar uchun o‘z musiqangizni tanlash uchun.',
    ru: 'Для выбора своей музыки для будильника и сигналов.',
    en: 'To select custom music for alarms and notifications.'
  }
};

function setValue(obj, path, val) {
  const parts = path.split('.');
  let curr = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (!curr[parts[i]] || typeof curr[parts[i]] !== 'object') {
      curr[parts[i]] = {};
    }
    curr = curr[parts[i]];
  }
  curr[parts[parts.length - 1]] = val;
}

for (const [key, tr] of Object.entries(translations)) {
  if (tr.uz) setValue(uz, key, tr.uz);
  if (tr.ru) setValue(ru, key, tr.ru);
  if (tr.en) setValue(en, key, tr.en);
}

// Sort JSON keys recursively
function sortObject(obj) {
  if (typeof obj !== 'object' || obj === null || Array.isArray(obj)) return obj;
  const sorted = {};
  for (const key of Object.keys(obj).sort()) {
    sorted[key] = sortObject(obj[key]);
  }
  return sorted;
}

fs.writeFileSync(uzPath, JSON.stringify(sortObject(uz), null, 2) + '\n');
fs.writeFileSync(ruPath, JSON.stringify(sortObject(ru), null, 2) + '\n');
fs.writeFileSync(enPath, JSON.stringify(sortObject(en), null, 2) + '\n');

console.log('Translations synced and sorted successfully!');
