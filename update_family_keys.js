const fs = require('fs');
const path = require('path');

const translationsDir = 'D:\\odat123\\Flowa\\assets\\translations';

const newFamilyKeysUz = {
  "family": {
    "location_title": "Joylashuv",
    "live_map_tab": "Jonli Xarita",
    "route_history_tab": "Marshrut Tarixi",
    "safe_places_heading": "Xavfsiz Hududlar",
    "add_place": "Joy qo'shish",
    "today_places_timeline": "Bugungi Harakatlar",
    "verified_route_points": "Tasdiqlangan marshrut nuqtalari",
    "connected_child_gps": "Jonli GPS va Xavfsiz Hududlar"
  }
};

const newFamilyKeysRu = {
  "family": {
    "location_title": "Локация",
    "live_map_tab": "Живая Карта",
    "route_history_tab": "История Маршрутов",
    "safe_places_heading": "Безопасные Зоны",
    "add_place": "Добавить место",
    "today_places_timeline": "Сегодняшние события",
    "verified_route_points": "Подтвержденные точки маршрута",
    "connected_child_gps": "Живой GPS и Безопасные Зоны"
  }
};

const newFamilyKeysEn = {
  "family": {
    "location_title": "Location",
    "live_map_tab": "Live Map",
    "route_history_tab": "Route History",
    "safe_places_heading": "Safe Zones",
    "add_place": "Add Place",
    "today_places_timeline": "Today's Timeline",
    "verified_route_points": "Verified route points",
    "connected_child_gps": "Live GPS & Safe Zones"
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

updateFile('uz.json', newFamilyKeysUz);
updateFile('uz.fixed.json', newFamilyKeysUz);
updateFile('ru.json', newFamilyKeysRu);
updateFile('en.json', newFamilyKeysEn);

console.log("Translation JSON files updated successfully with new family keys.");
