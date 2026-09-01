const fs = require('fs');
const path = require('path');

const translationsDir = 'D:\\odat123\\Flowa\\assets\\translations';

const newKeysUz = {
  "family": {
    "no_wallet_data": "Hamyon ma'lumoti yo'q",
    "wallet_load_error": "Hamyon ma'lumotlarini yuklashda xatolik"
  }
};

const newKeysRu = {
  "family": {
    "no_wallet_data": "Нет данных кошелька",
    "wallet_load_error": "Ошибка при загрузке данных кошелька"
  }
};

const newKeysEn = {
  "family": {
    "no_wallet_data": "No wallet data",
    "wallet_load_error": "Error loading wallet data"
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

console.log("Translation JSON files updated successfully.");
