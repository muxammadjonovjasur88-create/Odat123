const fs = require('fs');
const path = require('path');

const replacements = [
  { target: "'Mashq turini tanlang:'", repl: "'battle.select_exercise'.tr()" },
  { target: "'Jang davomiyligi:'", repl: "'battle.match_duration'.tr()" },
  { target: "'Garov (PTS):'", repl: "'battle.stake_pts'.tr()" },
  { target: "'JANGNI BOSHLASH ⚔️'", repl: "'battle.start_battle'.tr()" },
  { target: "'🤝 Do‘stlik so‘rovi muvaffaqiyatli yuborildi!'", repl: "'battle.friend_request_sent'.tr()" },
  { target: "'Kamera orqali rasm olish'", repl: "'clan.take_photo'.tr()" },
  { target: "'Galereyadan tanlash'", repl: "'clan.choose_gallery'.tr()" },
  { target: "'Klan Sozlamalari & Boshqaruv'", repl: "'clan.clan_settings_mgmt'.tr()" },
  { target: "'➕ Yangi Klan Ochish'", repl: "'clan.create_new_clan_btn'.tr()" },
  { target: "'Foydalanuvchi topilmadi'", repl: "'profile.user_not_found'.tr()" },
  { target: "'Ismni O‘zgartirish'", repl: "'profile.change_name'.tr()" },
  { target: "'Barcha erishilgan daraja mukofotlari allaqachon olingan! 🌟'", repl: "'profile.all_rank_rewards_claimed'.tr()" },
  { target: "'Siz allaqachon ushbu tarmoq uchun +1500 PTS mukofotini olgansiz! ✅'", repl: "'profile.social_reward_claimed'.tr()" },
  { target: "'Boshlanish:'", repl: "'reminders.start_time'.tr()" },
  { target: "'Tugash vaqti:'", repl: "'reminders.end_time'.tr()" },
  { target: "'Takror / Qaytarish maqsadi:'", repl: "'reminders.repeat_goal'.tr()" },
  { target: "'PAUZA'", repl: "'running.pause'.tr()" },
  { target: "'YAKUNLASH'", repl: "'running.finish'.tr()" },
  { target: "'DAVOM ETISH'", repl: "'running.resume'.tr()" },
  { target: "'Yangi Minora O‘rnatish'", repl: "'running.place_new_tower'.tr()" },
  { target: "'SIZNING KUCHINGIZ'", repl: "'running.your_power'.tr()" },
  { target: "'HIMOYA KUCHI'", repl: "'running.defense_power'.tr()" },
  { target: "'Nom O‘zgartirish Ruxsatnomasi inventaringizga qo‘shildi! 🎒'", repl: "'shop.name_change_pass_added'.tr()" },
  { target: "'Minimal almashtirish miqdori: 1 Fenix Coin (10 PTS)'", repl: "'shop.min_exchange_limit'.tr()" },
  { target: "'Hisobingizda yetarli Fenix Coin mavjud emas!'", repl: "'shop.insufficient_fenix_coins'.tr()" },
  { target: "'Almashtirishda xatolik yuz berdi'", repl: "'shop.exchange_error'.tr()" }
];

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(file));
    } else if (file.endsWith('.dart')) {
      results.push(file);
    }
  });
  return results;
}

const files = walk('lib');
let totalModified = 0;

for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;

  for (const r of replacements) {
    if (content.includes(r.target)) {
      // If file doesn't import easy_localization, add it if needed
      if (!content.includes('package:easy_localization/easy_localization.dart')) {
        content = "import 'package:easy_localization/easy_localization.dart';\n" + content;
      }
      content = content.split(r.target).join(r.repl);
    }
    // Also check double-quoted variant
    const doubleTarget = r.target.replace(/^'|'$/g, '"');
    if (content.includes(doubleTarget)) {
      if (!content.includes('package:easy_localization/easy_localization.dart')) {
        content = "import 'package:easy_localization/easy_localization.dart';\n" + content;
      }
      content = content.split(doubleTarget).join(r.repl);
    }
  }

  if (content !== original) {
    fs.writeFileSync(file, content, 'utf8');
    console.log(`Updated ${file}`);
    totalModified++;
  }
}

console.log(`Total Dart files modified: ${totalModified}`);
