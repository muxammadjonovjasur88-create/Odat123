const fs = require('fs');

const file1 = 'D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_home_screen.dart';
let content1 = fs.readFileSync(file1, 'utf8');

// Use replaceAll with strings instead of regex to avoid escaping issues
content1 = content1.replaceAll("'Sovg\\'a'", "'parent_home.action_gift'.tr()");
content1 = content1.replaceAll("'AI Maslahat'", "'parent_home.action_ai'.tr()");
content1 = content1.replaceAll("'Xarita'", "'parent_home.action_map'.tr()");
content1 = content1.replaceAll("'Maqsad'", "'parent_home.action_goal'.tr()");

content1 = content1.replaceAll("'Ekran Vaqti'", "'parent_home.screen_time'.tr()");
content1 = content1.replaceAll("'O\\'qish'", "'parent_home.study'.tr()");
content1 = content1.replaceAll("'Intizom'", "'parent_home.discipline'.tr()");

content1 = content1.replaceAll("'${child.todayTasksCompleted}/${child.todayTasksTotal} vazifa'", "'parent_home.tasks_count'.tr(namedArgs: {'completed': '${child.todayTasksCompleted}', 'total': '${child.todayTasksTotal}'})");

content1 = content1.replaceAll("'Farzand ulanmagan'", "'parent_home.no_child_title'.tr()");
content1 = content1.replaceAll("'Farzandingizga ODAT ilovasini\\no\\'rnating va ulaning'", "'parent_home.no_child_subtitle'.tr().replaceAll('\\\\n', '\\n')");
content1 = content1.replaceAll("'Farzand Qo\\'shish'", "'parent_home.btn_add_child'.tr()");

content1 = content1.replaceAll("'Qo\\'shimcha Vaqt So\\'rovi'", "'parent_home.extra_time_req'.tr()");
content1 = content1.replaceAll("'Rad etish'", "'parent_home.btn_decline'.tr()");
content1 = content1.replaceAll("'+${request.requestedMinutes} daqiqa ruxsat'", "'parent_home.btn_allow_mins'.tr(namedArgs: {'mins': '${request.requestedMinutes}'})");

content1 = content1.replaceAll("'Hali maqsad belgilanmagan'", "'parent_home.no_goals_yet'.tr()");

content1 = content1.replaceAll("'Kutilmoqda'", "'parent_home.status_pending'.tr()");
content1 = content1.replaceAll("'Qabul qilindi'", "'parent_home.status_accepted'.tr()");
content1 = content1.replaceAll("'Bajarildi'", "'parent_home.status_completed'.tr()");
content1 = content1.replaceAll("'Rad etildi'", "'parent_home.status_declined'.tr()");

content1 = content1.replaceAll("'To‘liq jonli xaritani ochish ➔'", "'parent_home.open_full_map'.tr()");

content1 = content1.replaceAll("'GPS ma\\'lumoti yo\\'q'", "'parent_home.no_gps_title'.tr()");
content1 = content1.replaceAll("'Farzand qurilmasi ulanmagan'", "'parent_home.no_gps_subtitle'.tr()");

content1 = content1.replaceAll("'Kelganda xabar'", "'parent_home.alert_on_arrival'.tr()");
content1 = content1.replaceAll("'Ketganda xabar'", "'parent_home.alert_on_departure'.tr()");

content1 = content1.replaceAll("'Ilova vaqti yo\\'q'", "'parent_home.no_app_time_title'.tr()");
content1 = content1.replaceAll("'Farzand ulanganida qaysi ilovada\\nqancha vaqt o\\'tirganini ko\\'rasiz'", "'parent_home.no_app_time_subtitle'.tr().replaceAll('\\\\n', '\\n')");
content1 = content1.replaceAll("'Ilovalarda sarflangan vaqt'", "'parent_home.time_spent_in_apps'.tr()");

content1 = content1.replaceAll("'AI Maslahatchisi'", "'parent_home.ai_consultant'.tr()");
content1 = content1.replaceAll("'$childName haqida savol bering'", "'parent_home.ask_about_child'.tr(namedArgs: {'name': childName})");
content1 = content1.replaceAll("'Farzandingiz haqida savol bering'", "'parent_home.ask_about_child_fallback'.tr()");

content1 = content1.replaceAll("'Yangi Maqsad Belgilash'", "'parent_home.new_goal'.tr()");
content1 = content1.replaceAll("'Bola qabul qilsa → eslatma avtomatik qo\\'shiladi'", "'parent_home.new_goal_subtitle'.tr()");

content1 = content1.replaceAll("'OTA-ONA SOZLAMALARI'", "'parent_home.parent_settings'.tr()");
content1 = content1.replaceAll("'Til tanlash'", "'parent_home.select_language'.tr()");
content1 = content1.replaceAll("'Shaxsiy rejimga o\\'tish'", "'parent_home.switch_personal'.tr()");
content1 = content1.replaceAll("'Chiqish'", "'parent_home.logout'.tr()");

fs.writeFileSync(file1, content1, 'utf8');

const file2 = 'D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_location_screen.dart';
let content2 = fs.readFileSync(file2, 'utf8');

content2 = content2.replaceAll("'Joy qo\\'shish'", "'parent_home.btn_add_child'.tr()");
content2 = content2.replaceAll("'JONLI GPS'", "'parent_location.live_gps'.tr()");
content2 = content2.replaceAll("'Koordinatalar: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}'", "('parent_location.coordinates'.tr() + ': ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}')");
content2 = content2.replaceAll("'Kelganda'", "'parent_location.arrived_at'.tr()");
content2 = content2.replaceAll("'Chiqganda'", "'parent_location.departed_at'.tr()");
content2 = content2.replaceAll("'Bugungi umumiy masofa'", "'parent_location.today_distance'.tr()");
content2 = content2.replaceAll("'Qurilma o\\'chirilgan yoki aloqasiz paytlarda soxta marshrut chizilmaydi, faqat real GPS nuqtalari ko\\'rsatiladi.'", "'parent_location.offline_notice'.tr()");

// The complex ones
content2 = content2.replaceAll("'GPS koordinatasi (${pt.latitude.toStringAsFixed(3)}, ${pt.longitude.toStringAsFixed(3)})'", "('parent_location.gps_coordinate'.tr() + ' (${pt.latitude.toStringAsFixed(3)}, ${pt.longitude.toStringAsFixed(3)})')");
content2 = content2.replaceAll("'${ev.placeName} (${ev.isArrival ? \"Yetib keldi\" : \"Chiqdi\"})'", "('${ev.placeName} (' + (ev.isArrival ? 'parent_location.arrived'.tr() : 'parent_location.departed'.tr()) + ')')");

fs.writeFileSync(file2, content2, 'utf8');

console.log('Replaced strings in dart files');
