const fs = require('fs');

const uzPath = 'assets/translations/uz.json';
const ruPath = 'assets/translations/ru.json';
const enPath = 'assets/translations/en.json';

const uz = JSON.parse(fs.readFileSync(uzPath, 'utf8'));
const ru = JSON.parse(fs.readFileSync(ruPath, 'utf8'));
const en = JSON.parse(fs.readFileSync(enPath, 'utf8'));

const newTranslations = {
  // Common / Umumiy
  'common.cancel': { uz: 'Bekor qilish', ru: 'Отмена', en: 'Cancel' },
  'common.save': { uz: 'Saqlash', ru: 'Сохранить', en: 'Save' },
  'common.confirm': { uz: 'Tasdiqlash', ru: 'Подтвердить', en: 'Confirm' },
  'common.close': { uz: 'Yopish', ru: 'Закрыть', en: 'Close' },
  'common.retry': { uz: 'Qayta urinish', ru: 'Повторить', en: 'Retry' },
  'common.continue_btn': { uz: 'Davom etish', ru: 'Продолжить', en: 'Continue' },
  'common.exit': { uz: 'Chiqish', ru: 'Выход', en: 'Exit' },
  'common.ready': { uz: 'Tayyor', ru: 'Готово', en: 'Done' },
  'common.open': { uz: 'Ochish', ru: 'Открыть', en: 'Open' },
  'common.claim': { uz: 'Olish', ru: 'Забрать', en: 'Claim' },
  'common.add': { uz: 'Qo‘shish', ru: 'Добавить', en: 'Add' },
  'common.home': { uz: 'Bosh sahifa', ru: 'Главная', en: 'Home' },
  'common.previous': { uz: 'Oldingisi', ru: 'Предыдущий', en: 'Previous' },
  'common.later': { uz: 'Keyinroq', ru: 'Позже', en: 'Later' },
  'common.congrats': { uz: 'Tabriklaymiz!', ru: 'Поздравляем!', en: 'Congratulations!' },

  // Welcome / Splash
  'welcome.tagline': { uz: 'Odatlar bilan o‘zingizni kashf eting', ru: 'Откройте себя через полезные привычки', en: 'Discover yourself through habits' },
  'welcome.preparing': { uz: 'Siz uchun muhit tayyorlanmoqda...', ru: 'Подготавливаем ваше пространство...', en: 'Preparing your space...' },

  // Settings
  'settings.location_title': { uz: 'Joylashuv', ru: 'Местоположение', en: 'Location' },
  'settings.help_feedback': { uz: 'Yordam va taklif', ru: 'Помощь и отзывы', en: 'Help & Feedback' },
  'settings.help_feedback_sub': { uz: 'Fikr-mulohaza yoki muammo haqida yozing', ru: 'Напишите отзыв или сообщите о проблеме', en: 'Write feedback or report an issue' },
  'settings.feedback_sent': { uz: 'Xabaringiz yuborildi, rahmat!', ru: 'Ваше сообщение отправлено, спасибо!', en: 'Your message has been sent, thank you!' },
  'settings.telegram_connected': { uz: 'Telegram muvaffaqiyatli ulandi! ✅', ru: 'Telegram успешно подключен! ✅', en: 'Telegram successfully connected! ✅' },
  'settings.telegram_unlink': { uz: 'Telegram ulanishini uzish', ru: 'Отключить Telegram', en: 'Unlink Telegram' },
  'settings.telegram_unlink_btn': { uz: 'Uzish', ru: 'Отключить', en: 'Disconnect' },
  'settings.telegram_unlinked': { uz: 'Telegram ulanishi uzildi.', ru: 'Подключение к Telegram отключено.', en: 'Telegram disconnected.' },
  'settings.telegram_link_title': { uz: 'Telegram ulanish', ru: 'Подключение Telegram', en: 'Telegram Connection' },
  'settings.custom_sound_pick': { uz: 'Fayldan tanlash...', ru: 'Выбрать из файла...', en: 'Choose from file...' },

  // Quests & Daily Plan
  'quests.already_claimed': { uz: 'Siz bu topshiriq uchun +200 PTS mukofotni allaqachon olgansiz! ✅', ru: 'Вы уже получили +200 PTS за это задание! ✅', en: 'You have already claimed the +200 PTS reward for this quest! ✅' },
  'quests.go_to_bot': { uz: 'Botga O‘tish & Olish 🚀', ru: 'Перейти в бота и забрать 🚀', en: 'Go to Bot & Claim 🚀' },
  'quests.pts_reward_added': { uz: 'Tabriklaymiz! +200 PTS hisobingizga qo‘shildi! 🎉', ru: 'Поздравляем! +200 PTS добавлено на ваш баланс! 🎉', en: 'Congratulations! +200 PTS added to your account! 🎉' },

  // Deep focus
  'deep_focus.great_continue': { uz: 'Ajoyib! Davom etish', ru: 'Отлично! Продолжить', en: 'Awesome! Continue' },
  'deep_focus.strict_mode_warning': { uz: '🔒 Qat‘iy Intizom rejimi faol! Belgilangan vaqt tugamaguncha ilovadan chiqib bo‘lmaydi.', ru: '🔒 Строгий режим активен! Нельзя выйти из приложения до окончания времени.', en: '🔒 Strict Discipline mode active! Cannot exit the app until time ends.' },
  'deep_focus.emergency_call': { uz: 'Favqulodda Qo‘ng‘iroq', ru: 'Экстренный вызов', en: 'Emergency Call' },

  // Vision
  'vision.stop_confirm_title': { uz: 'Mashg‘ulotni to‘xtatmoqchimisiz?', ru: 'Прервать тренировку?', en: 'Stop the workout?' },
  'vision.stop_confirm_body': { uz: 'Hozirgi AI Vision mashg‘uloti yakunlanadi.', ru: 'Текущая тренировка AI Vision завершится.', en: 'Current AI Vision workout will end.' },

  // Friends & Chat
  'friends.take_photo': { uz: 'Kameradan suratga olish', ru: 'Сделать фото с камеры', en: 'Take photo from camera' },
  'friends.pick_gallery': { uz: 'Galereyadan tanlash', ru: 'Выбрать из галереи', en: 'Choose from gallery' },
  'friends.pts_points': { uz: '⚡ PTS Ballar', ru: '⚡ Баллы PTS', en: '⚡ PTS Points' },
  'friends.fenix_coins': { uz: '🪙 Fenix Coin', ru: '🪙 Монеты Fenix', en: '🪙 Fenix Coins' },
  'friends.select_gift_amount': { uz: 'Sovg‘a miqdorini tanlang:', ru: 'Выберите количество подарка:', en: 'Select gift amount:' },
  'friends.unfriend': { uz: 'Do‘stlardan o‘chirish', ru: 'Удалить из друзей', en: 'Remove from friends' },
  'friends.send_request': { uz: 'Do‘stlashishni taklif qilish', ru: 'Предложить дружбу', en: 'Send friend request' },
  'friends.challenge_1v1': { uz: '1v1 Jangga chaqirish ⚔️', ru: 'Вызвать на дуэль 1v1 ⚔️', en: 'Challenge to 1v1 Battle ⚔️' },
  'friends.search_invite': { uz: 'Do‘stlarni Qidirish & Taklif', ru: 'Поиск и приглашение друзей', en: 'Search & Invite Friends' },

  // Gamification & Wheel
  'gamification.spinning': { uz: 'AYLANMOQDA...', ru: 'ВРАЩАЕТСЯ...', en: 'SPINNING...' },
  'gamification.clock_tampered': { uz: '⚠️ Qurilma vaqti o‘zgartirilgan! Aniq tarmoq vaqtini o‘rnating.', ru: '⚠️ Время на устройстве изменено! Установите точное сетевое время.', en: '⚠️ Device time was tampered! Please set automatic network time.' },

  // Knowledge & Quiz
  'knowledge.total_points': { uz: 'Jamlangan Ball', ru: 'Набранные баллы', en: 'Total Points' },
  'knowledge.fenix_tangalar': { uz: 'Fenix Tangalar', ru: 'Монеты Fenix', en: 'Fenix Coins' },
  'knowledge.retry_quiz': { uz: 'Qayta Sinash 🔄', ru: 'Попробовать снова 🔄', en: 'Retry Quiz 🔄' },

  // Leaderboard & Clan
  'leaderboard.create_first_clan': { uz: 'Birinchi Klanini Yaratish', ru: 'Создать первый клан', en: 'Create First Clan' },
  'clan.save_changes': { uz: 'Saqlash ✨', ru: 'Сохранить ✨', en: 'Save ✨' },

  // Library
  'library.book_not_found': { uz: 'Kitob topilmadi', ru: 'Книга не найдена', en: 'Book not found' },
  'library.start_quiz': { uz: 'Testni boshlash', ru: 'Начать тест', en: 'Start Quiz' },

  // Music
  'music.track_price': { uz: 'Trek Narxi', ru: 'Цена трека', en: 'Track Price' },
  'music.your_balance': { uz: 'Sizning Balansingiz', ru: 'Ваш баланс', en: 'Your Balance' },

  // News
  'news.empty_category': { uz: 'Ushbu toifada yangiliklar topilmadi', ru: 'В этой категории новостей нет', en: 'No news found in this category' },
  'news.read_full': { uz: 'Batafsil manbada o‘qish', ru: 'Читать в источнике', en: 'Read full article' },

  // Profile & Bug Bounty
  'profile.bug_empty_err': { uz: 'Iltimos, topilgan xatolik haqida yozing!', ru: 'Пожалуйста, опишите найденную ошибку!', en: 'Please describe the bug!' },
  'profile.send_bug_report': { uz: 'HISOBOTNI YUBORISH (+4000 PTS) 🚀', ru: 'ОТПРАВИТЬ ОТЧЕТ (+4000 PTS) 🚀', en: 'SUBMIT REPORT (+4000 PTS) 🚀' },
  'profile.user_not_found': { uz: 'Foydalanuvchi aniqlanmadi', ru: 'Пользователь не определен', en: 'User not identified' },
  'profile.no_bugs_yet': { uz: 'Siz hali bug hisoboti yubormagansiz', ru: 'Вы еще не отправляли отчетов об ошибках', en: 'You haven’t submitted any bug reports yet' },

  // Random proof
  'proof.answer_saved': { uz: 'Javobingiz muvaffaqiyatli saqlandi!', ru: 'Ваш ответ успешно сохранен!', en: 'Your response was saved successfully!' },
  'proof.not_signed_in': { uz: 'Foydalanuvchi tizimga kirmagan', ru: 'Пользователь не авторизован', en: 'User not signed in' },

  // Referral
  'referral.enter_friend_code': { uz: 'Do‘st kodini kiritish', ru: 'Ввести код друга', en: 'Enter friend code' },
  'referral.reward_success': { uz: '🎉 Tabriklaymiz! +50 PTS hisobingizga qo‘shildi!', ru: '🎉 Поздравляем! +50 PTS начислено на ваш баланс!', en: '🎉 Congratulations! +50 PTS added to your account!' },
  'referral.your_code_label': { uz: 'Sizning shaxsiy referal kodingiz:', ru: 'Ваш личный реферальный код:', en: 'Your personal referral code:' },
  'referral.enter_code_btn': { uz: 'Do‘st kodini kiritish (+50 PTS)', ru: 'Ввести код друга (+50 PTS)', en: 'Enter friend code (+50 PTS)' },
  'referral.share_friends': { uz: 'Do‘stlarga ulashish', ru: 'Поделиться с друзьями', en: 'Share with friends' },

  // Shop
  'shop.confirm_buy': { uz: 'Ha, sotib olish', ru: 'Да, купить', en: 'Yes, purchase' },
  'shop.promo_copied': { uz: 'Promo kod nusxalandi!', ru: 'Промокод скопирован!', en: 'Promo code copied!' },
  'shop.freeze_bought': { uz: '❄️ 1 ta Streak Muzlatgich sotib olindi! Streakingiz xavfsiz.', ru: '❄️ 1 Заморозка серии куплена! Ваша серия в безопасности.', en: '❄️ 1 Streak Freeze purchased! Your streak is protected.' },
  'shop.invalid_promo': { uz: 'Noto‘g‘ri yoki muddati o‘tgan promo-kod!', ru: 'Неверный или просроченный промокод!', en: 'Invalid or expired promo code!' },

  // Sign In
  'signin.agree_and_accept': { uz: 'ROZIMAN VA QABUL QILAMAN ✅', ru: 'СОГЛАСЕН И ПРИНИМАЮ ✅', en: 'I AGREE AND ACCEPT ✅' }
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

for (const [key, tr] of Object.entries(newTranslations)) {
  if (tr.uz) setValue(uz, key, tr.uz);
  if (tr.ru) setValue(ru, key, tr.ru);
  if (tr.en) setValue(en, key, tr.en);
}

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

console.log('Successfully injected all new translation keys!');
