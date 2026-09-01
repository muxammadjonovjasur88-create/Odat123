const fs = require('fs');

const extraKeysUz = {
  battle: {
    select_exercise: "Mashq turini tanlang:",
    match_duration: "Jang davomiyligi:",
    stake_pts: "Garov (PTS):",
    start_battle: "JANGNI BOSHLASH ⚔️",
    friend_request_sent: "🤝 Do‘stlik so‘rovi muvaffaqiyatli yuborildi!"
  },
  clan: {
    take_photo: "Kamera orqali rasm olish",
    choose_gallery: "Galereyadan tanlash",
    attention: "Diqqat",
    understood: "Tushunarli",
    clan_settings_mgmt: "Klan Sozlamalari & Boshqaruv",
    create_new_clan_btn: "➕ Yangi Klan Ochish"
  },
  profile: {
    user_not_found: "Foydalanuvchi topilmadi",
    change_name: "Ismni O‘zgartirish",
    cancel: "Bekor qilish",
    change: "O‘zgartirish",
    delete: "O‘chirish",
    all_rank_rewards_claimed: "Barcha erishilgan daraja mukofotlari allaqachon olingan! 🌟",
    social_reward_claimed: "Siz allaqachon ushbu tarmoq uchun +1500 PTS mukofotini olgansiz! ✅"
  },
  reminders: {
    start_time: "Boshlanish:",
    end_time: "Tugash vaqti:",
    repeat_goal: "Takror / Qaytarish maqsadi:",
    repeat_label: "Takrorlash:",
    cancel: "Bekor qilish",
    delete: "O‘chirish"
  },
  running: {
    pause: "PAUZA",
    finish: "YAKUNLASH",
    resume: "DAVOM ETISH",
    place_new_tower: "Yangi Minora O‘rnatish",
    your_power: "SIZNING KUCHINGIZ",
    defense_power: "HIMOYA KUCHI"
  },
  shop: {
    name_change_pass_added: "Nom O‘zgartirish Ruxsatnomasi inventaringizga qo‘shildi! 🎒",
    min_exchange_limit: "Minimal almashtirish miqdori: 1 Fenix Coin (10 PTS)",
    insufficient_fenix_coins: "Hisobingizda yetarli Fenix Coin mavjud emas!",
    exchange_error: "Almashtirishda xatolik yuz berdi"
  }
};

const extraKeysRu = {
  battle: {
    select_exercise: "Выберите упражнение:",
    match_duration: "Длительность боя:",
    stake_pts: "Ставка (PTS):",
    start_battle: "НАЧАТЬ БИТВУ ⚔️",
    friend_request_sent: "🤝 Запрос в друзья успешно отправлен!"
  },
  clan: {
    take_photo: "Сделать фото с камеры",
    choose_gallery: "Выбрать из галереи",
    attention: "Внимание",
    understood: "Понятно",
    clan_settings_mgmt: "Настройки клана и управление",
    create_new_clan_btn: "➕ Создать новый клан"
  },
  profile: {
    user_not_found: "Пользователь не найден",
    change_name: "Изменить имя",
    cancel: "Отмена",
    change: "Изменить",
    delete: "Удалить",
    all_rank_rewards_claimed: "Все награды за достигнутые ранги уже получены! 🌟",
    social_reward_claimed: "Вы уже получили награду +1500 PTS за эту соцсеть! ✅"
  },
  reminders: {
    start_time: "Начало:",
    end_time: "Время окончания:",
    repeat_goal: "Цель повторений:",
    repeat_label: "Повторение:",
    cancel: "Отмена",
    delete: "Удалить"
  },
  running: {
    pause: "ПАУЗА",
    finish: "ЗАВЕРШИТЬ",
    resume: "ПРОДОЛЖИТЬ",
    place_new_tower: "Установить новую башню",
    your_power: "ВАША СИЛА",
    defense_power: "СИЛА ЗАЩИТЫ"
  },
  shop: {
    name_change_pass_added: "Пропуск смены имени добавлен в инвентарь! 🎒",
    min_exchange_limit: "Мин. сумма обмена: 1 Fenix Coin (10 PTS)",
    insufficient_fenix_coins: "На балансе недостаточно Fenix Coins!",
    exchange_error: "Ошибка при обмене"
  }
};

const extraKeysEn = {
  battle: {
    select_exercise: "Select exercise:",
    match_duration: "Battle duration:",
    stake_pts: "Stake (PTS):",
    start_battle: "START BATTLE ⚔️",
    friend_request_sent: "🤝 Friend request sent successfully!"
  },
  clan: {
    take_photo: "Take photo with camera",
    choose_gallery: "Choose from gallery",
    attention: "Attention",
    understood: "Understood",
    clan_settings_mgmt: "Clan Settings & Management",
    create_new_clan_btn: "➕ Create New Clan"
  },
  profile: {
    user_not_found: "User not found",
    change_name: "Change Name",
    cancel: "Cancel",
    change: "Change",
    delete: "Delete",
    all_rank_rewards_claimed: "All rank rewards have already been claimed! 🌟",
    social_reward_claimed: "You have already claimed +1500 PTS for this network! ✅"
  },
  reminders: {
    start_time: "Start:",
    end_time: "End Time:",
    repeat_goal: "Repetition Target:",
    repeat_label: "Repeat:",
    cancel: "Cancel",
    delete: "Delete"
  },
  running: {
    pause: "PAUSE",
    finish: "FINISH",
    resume: "RESUME",
    place_new_tower: "Place New Defense Tower",
    your_power: "YOUR POWER",
    defense_power: "DEFENSE POWER"
  },
  shop: {
    name_change_pass_added: "Name Change Pass added to your inventory! 🎒",
    min_exchange_limit: "Minimum exchange: 1 Fenix Coin (10 PTS)",
    insufficient_fenix_coins: "Insufficient Fenix Coins in your account!",
    exchange_error: "Exchange failed"
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
  { code: 'uz', extra: extraKeysUz },
  { code: 'ru', extra: extraKeysRu },
  { code: 'en', extra: extraKeysEn },
  { code: 'uz_CR', extra: extraKeysUz }
];

for (const loc of locales) {
  const p = `assets/translations/${loc.code}.json`;
  if (fs.existsSync(p)) {
    const raw = JSON.parse(fs.readFileSync(p, 'utf8'));
    deepMerge(raw, loc.extra);
    fs.writeFileSync(p, JSON.stringify(raw, null, 2), 'utf8');
    console.log(`Injected extra keys into ${p}`);
  }
}
