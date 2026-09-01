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

const keys = {
  'inbox.message_deleted': {
    uz: 'Xabar o‘chirildi',
    ru: 'Сообщение удалено',
    en: 'Message deleted'
  },
  'common.error': {
    uz: 'Xatolik: {args_0}',
    ru: 'Ошибка: {args_0}',
    en: 'Error: {args_0}'
  },
  'settings.telegram_unlink_confirm': {
    uz: 'Telegramdan ulanishni uzmoqchimisiz? Do‘stlar sizning isbot natijalaringiz haqida Telegram xabar olmaydi.',
    ru: 'Вы хотите отключить Telegram? Друзья не будут получать уведомления о ваших доказательствах.',
    en: 'Do you want to unlink Telegram? Friends will no longer receive updates about your proofs.'
  },
  'shop.insufficient_points': {
    uz: 'Ochkolaringiz yetarli emas! Sizda: {current}, talab qilinadi: {required}',
    ru: 'Недостаточно баллов! У вас: {current}, требуется: {required}',
    en: 'Insufficient points! You have: {current}, required: {required}'
  },
  'shop.purchase_coupon': {
    uz: 'Kuponni xarid qilish',
    ru: 'Покупка купона',
    en: 'Purchase Coupon'
  },
  'shop.confirm_purchase': {
    uz: '{title} kuponini {points} ochkoga sotib olishni tasdiqlaysizmi?',
    ru: 'Подтверждаете покупку купона {title} за {points} баллов?',
    en: 'Confirm purchase of {title} coupon for {points} points?'
  },
  'shop.buy_button': {
    uz: 'Ha, sotib olish',
    ru: 'Да, купить',
    en: 'Yes, purchase'
  },
  'shop.purchase_success': {
    uz: 'Xarid muvaffaqiyatli!',
    ru: 'Покупка успешна!',
    en: 'Purchase successful!'
  },
  'shop.promo_code_label': {
    uz: 'Sizning promo kodingiz:',
    ru: 'Ваш промокод:',
    en: 'Your promo code:'
  },
  'shop.view_in_my_purchases': {
    uz: 'Ushbu kodni "Mening xaridlarim" bo‘limida istalgan vaqtda ko‘rishingiz mumkin.',
    ru: 'Вы можете просмотреть этот код в разделе "Мои покупки" в любое время.',
    en: 'You can view this code in "My Purchases" section at any time.'
  },
  'common.understood': {
    uz: 'Tushunarli',
    ru: 'Понятно',
    en: 'Understood'
  }
};

for (const [key, trans] of Object.entries(keys)) {
  setNested(uz, key, trans.uz);
  setNested(ru, key, trans.ru);
  setNested(en, key, trans.en);
}

fs.writeFileSync(uzPath, JSON.stringify(uz, null, 2), 'utf8');
fs.writeFileSync(ruPath, JSON.stringify(ru, null, 2), 'utf8');
fs.writeFileSync(enPath, JSON.stringify(en, null, 2), 'utf8');

console.log('All 11 missing keys injected successfully.');
