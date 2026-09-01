const fs = require('fs');
const path = require('path');

const uzPath = path.join(__dirname, '../assets/translations/uz.json');
const ruPath = path.join(__dirname, '../assets/translations/ru.json');
const enPath = path.join(__dirname, '../assets/translations/en.json');

const uz = JSON.parse(fs.readFileSync(uzPath, 'utf8'));
const ru = JSON.parse(fs.readFileSync(ruPath, 'utf8'));
const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));

function setNested(obj, keyPath, val) {
  const parts = keyPath.split('.');
  let curr = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (!curr[parts[i]]) curr[parts[i]] = {};
    curr = curr[parts[i]];
  }
  curr[parts[parts.length - 1]] = val;
}

const newKeys = {
  'battle.open_tag': {
    uz: 'OCHIQ',
    ru: 'ОТКРЫТО',
    en: 'OPEN'
  },
  'notifications.alarm_permission_title': {
    uz: 'Budilnik ruxsati',
    ru: 'Разрешение на будильник',
    en: 'Alarm Permission'
  },
  'notifications.alarm_permission_body': {
    uz: 'Vazifalar boshlanishidan oldin budilnik to‘g‘ri va o‘z vaqtida chalinishi uchun sozlamalardan "Alarmlar va eslatmalar" ruxsatini yoqing.',
    ru: 'Чтобы будильник звонил вовремя перед началом задач, включите разрешение "Будильники и напоминания" в настройках.',
    en: 'To ensure alarms ring accurately and on time before tasks begin, please enable "Alarms & Reminders" permission in Settings.'
  },
  'notifications.go_to_settings': {
    uz: 'Sozlamalarga o‘tish',
    ru: 'Перейти в настройки',
    en: 'Go to Settings'
  }
};

for (const [key, trans] of Object.entries(newKeys)) {
  setNested(uz, key, trans.uz);
  setNested(ru, key, trans.ru);
  setNested(en, key, trans.en);
}

fs.writeFileSync(uzPath, JSON.stringify(uz, null, 2), 'utf8');
fs.writeFileSync(ruPath, JSON.stringify(ru, null, 2), 'utf8');
fs.writeFileSync(enPath, JSON.stringify(en, null, 2), 'utf8');

console.log('Notifications keys successfully updated in uz.json, ru.json, en.json.');
