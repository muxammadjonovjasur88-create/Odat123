const fs = require('fs');
const path = require('path');

const translationsDir = 'D:\\odat123\\Flowa\\assets\\translations';

const keysUz = {
  "parent_home": {
    "screen_time": "Ekran Vaqti",
    "study": "O'qish",
    "discipline": "Intizom",
    "tasks_count": "{completed}/{total} vazifa",
    "no_child_title": "Farzand ulanmagan",
    "no_child_subtitle": "Farzandingizga ODAT ilovasini\\no'rnating va ulaning",
    "btn_add_child": "Farzand Qo'shish",
    "extra_time_req": "Qo'shimcha Vaqt So'rovi",
    "btn_decline": "Rad etish",
    "btn_allow_mins": "+{mins} daqiqa ruxsat",
    "no_goals_yet": "Hali maqsad belgilanmagan",
    "status_pending": "Kutilmoqda",
    "status_accepted": "Qabul qilindi",
    "status_completed": "Bajarildi",
    "status_declined": "Rad etildi",
    "open_full_map": "To'liq jonli xaritani ochish ➔",
    "no_gps_title": "GPS ma'lumoti yo'q",
    "no_gps_subtitle": "Farzand qurilmasi ulanmagan",
    "alert_on_arrival": "Kelganda xabar",
    "alert_on_departure": "Ketganda xabar",
    "no_app_time_title": "Ilova vaqti yo'q",
    "no_app_time_subtitle": "Farzand ulanganida qaysi ilovada\\nqancha vaqt o'tirganini ko'rasiz",
    "time_spent_in_apps": "Ilovalarda sarflangan vaqt",
    "ai_consultant": "AI Maslahatchisi",
    "ask_about_child": "{name} haqida savol bering",
    "ask_about_child_fallback": "Farzandingiz haqida savol bering",
    "new_goal": "Yangi Maqsad Belgilash",
    "new_goal_subtitle": "Bola qabul qilsa → eslatma avtomatik qo'shiladi",
    "parent_settings": "OTA-ONA SOZLAMALARI",
    "select_language": "Til tanlash",
    "switch_personal": "Shaxsiy rejimga o'tish",
    "logout": "Chiqish",
    "action_gift": "Sovg'a",
    "action_ai": "AI Maslahat",
    "action_map": "Xarita",
    "action_goal": "Maqsad"
  },
  "parent_location": {
    "live_gps": "JONLI GPS",
    "coordinates": "Koordinatalar",
    "arrived": "Yetib keldi",
    "departed": "Chiqdi",
    "arrived_at": "Kelganda",
    "departed_at": "Chiqganda",
    "today_distance": "Bugungi umumiy masofa",
    "offline_notice": "Qurilma o'chirilgan yoki aloqasiz paytlarda soxta marshrut chizilmaydi, faqat real GPS nuqtalari ko'rsatiladi.",
    "gps_coordinate": "GPS koordinatasi",
    "child": "Farzand"
  }
};

const keysRu = {
  "parent_home": {
    "screen_time": "Экранное время",
    "study": "Учеба",
    "discipline": "Дисциплина",
    "tasks_count": "{completed}/{total} задач",
    "no_child_title": "Ребенок не подключен",
    "no_child_subtitle": "Установите приложение ODAT\\nвашему ребенку и подключите",
    "btn_add_child": "Добавить Ребенка",
    "extra_time_req": "Запрос доп. времени",
    "btn_decline": "Отклонить",
    "btn_allow_mins": "+{mins} мин. разрешить",
    "no_goals_yet": "Цели пока не установлены",
    "status_pending": "Ожидается",
    "status_accepted": "Принято",
    "status_completed": "Выполнено",
    "status_declined": "Отклонено",
    "open_full_map": "Открыть полную карту ➔",
    "no_gps_title": "Нет данных GPS",
    "no_gps_subtitle": "Устройство ребенка не подключено",
    "alert_on_arrival": "Уведомлять о прибытии",
    "alert_on_departure": "Уведомлять об убытии",
    "no_app_time_title": "Нет данных о приложениях",
    "no_app_time_subtitle": "Когда ребенок будет подключен, вы\\nувидите время в приложениях",
    "time_spent_in_apps": "Время, проведенное в приложениях",
    "ai_consultant": "AI Консультант",
    "ask_about_child": "Задайте вопрос о {name}",
    "ask_about_child_fallback": "Задайте вопрос о вашем ребенке",
    "new_goal": "Установить новую цель",
    "new_goal_subtitle": "Если ребенок примет → напоминание добавится",
    "parent_settings": "НАСТРОЙКИ РОДИТЕЛЯ",
    "select_language": "Выбор языка",
    "switch_personal": "Перейти в личный режим",
    "logout": "Выйти",
    "action_gift": "Подарок",
    "action_ai": "AI Совет",
    "action_map": "Карта",
    "action_goal": "Цель"
  },
  "parent_location": {
    "live_gps": "ЖИВОЙ GPS",
    "coordinates": "Координаты",
    "arrived": "Прибыл(а)",
    "departed": "Ушел(а)",
    "arrived_at": "Прибытие",
    "departed_at": "Убытие",
    "today_distance": "Общее расстояние за сегодня",
    "offline_notice": "При отсутствии связи ложные маршруты не строятся, только реальные GPS точки.",
    "gps_coordinate": "Координата GPS",
    "child": "Ребенок"
  }
};

const keysEn = {
  "parent_home": {
    "screen_time": "Screen Time",
    "study": "Study",
    "discipline": "Discipline",
    "tasks_count": "{completed}/{total} tasks",
    "no_child_title": "Child not connected",
    "no_child_subtitle": "Install ODAT on your child's\\ndevice and connect",
    "btn_add_child": "Add Child",
    "extra_time_req": "Extra Time Request",
    "btn_decline": "Decline",
    "btn_allow_mins": "Allow +{mins} mins",
    "no_goals_yet": "No goals set yet",
    "status_pending": "Pending",
    "status_accepted": "Accepted",
    "status_completed": "Completed",
    "status_declined": "Declined",
    "open_full_map": "Open full live map ➔",
    "no_gps_title": "No GPS data",
    "no_gps_subtitle": "Child device not connected",
    "alert_on_arrival": "Alert on arrival",
    "alert_on_departure": "Alert on departure",
    "no_app_time_title": "No App Time Data",
    "no_app_time_subtitle": "Once connected, you will see\\nthe time spent in apps here",
    "time_spent_in_apps": "Time spent in apps",
    "ai_consultant": "AI Consultant",
    "ask_about_child": "Ask about {name}",
    "ask_about_child_fallback": "Ask about your child",
    "new_goal": "Set New Goal",
    "new_goal_subtitle": "If child accepts → reminder is added",
    "parent_settings": "PARENT SETTINGS",
    "select_language": "Select Language",
    "switch_personal": "Switch to Personal Mode",
    "logout": "Log Out",
    "action_gift": "Gift",
    "action_ai": "AI Advice",
    "action_map": "Map",
    "action_goal": "Goal"
  },
  "parent_location": {
    "live_gps": "LIVE GPS",
    "coordinates": "Coordinates",
    "arrived": "Arrived",
    "departed": "Departed",
    "arrived_at": "On Arrival",
    "departed_at": "On Departure",
    "today_distance": "Total distance today",
    "offline_notice": "When offline, fake routes are not drawn, only real GPS points are shown.",
    "gps_coordinate": "GPS Coordinate",
    "child": "Child"
  }
};

function mergeObj(target, source) {
  for (const key of Object.keys(source)) {
    if (typeof source[key] === 'object' && target[key]) {
      mergeObj(target[key], source[key]);
    } else {
      target[key] = source[key];
    }
  }
}

const updateFile = (filename, newObj) => {
  const filePath = path.join(translationsDir, filename);
  if (!fs.existsSync(filePath)) return;
  
  const content = fs.readFileSync(filePath, 'utf8');
  let json = JSON.parse(content);
  
  mergeObj(json, newObj);
  
  fs.writeFileSync(filePath, JSON.stringify(json, null, 2), 'utf8');
  console.log(`Updated ${filename}`);
};

updateFile('uz.json', keysUz);
updateFile('uz.fixed.json', keysUz);
updateFile('ru.json', keysRu);
updateFile('en.json', keysEn);

console.log("Translation JSON files updated successfully.");
