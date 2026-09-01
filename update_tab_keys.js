const fs = require('fs');
const path = require('path');

const translationsDir = 'D:\\odat123\\Flowa\\assets\\translations';

const newKeysUz = {
  "parent_home": {
    "tab_main": "Asosiy",
    "tab_map": "Xarita",
    "tab_report": "Hisobot",
    "tab_goal": "Maqsad",
    "app_bar_subtitle": "Farzand ulanmagan",
    "tooltip_add_child": "Farzand qo'shish"
  }
};

const newKeysRu = {
  "parent_home": {
    "tab_main": "Главная",
    "tab_map": "Карта",
    "tab_report": "Отчет",
    "tab_goal": "Цель",
    "app_bar_subtitle": "Ребенок не подключен",
    "tooltip_add_child": "Добавить ребенка"
  }
};

const newKeysEn = {
  "parent_home": {
    "tab_main": "Home",
    "tab_map": "Map",
    "tab_report": "Report",
    "tab_goal": "Goal",
    "app_bar_subtitle": "Child not connected",
    "tooltip_add_child": "Add child"
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

updateFile('uz.json', newKeysUz);
updateFile('uz.fixed.json', newKeysUz);
updateFile('ru.json', newKeysRu);
updateFile('en.json', newKeysEn);

console.log("Translation JSON files updated successfully with new tab keys.");
