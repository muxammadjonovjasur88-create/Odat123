const fs = require('fs');
const path = require('path');

const translationsDir = 'D:\\odat123\\Flowa\\assets\\translations';

const newKeysUz = {
  "shop": {
    "my_purchases": "Mening xaridlarim",
    "my_coupons": "Kuponlarim",
    "purchase_history": "Xaridlar tarixi",
    "no_coupons_yet": "Hali hech qanday kuponingiz yo'q.",
    "buy_gifts_from_shop": "Do'kondan sovg'alar yoki chegirmalar xarid qiling.",
    "go_to_shop": "Do'konga o'tish",
    "purchase_history_empty": "Xaridlar tarixi bo'sh."
  }
};

const newKeysRu = {
  "shop": {
    "my_purchases": "Мои покупки",
    "my_coupons": "Мои купоны",
    "purchase_history": "История покупок",
    "no_coupons_yet": "У вас пока нет купонов.",
    "buy_gifts_from_shop": "Покупайте подарки или скидки в магазине.",
    "go_to_shop": "Перейти в магазин",
    "purchase_history_empty": "История покупок пуста."
  }
};

const newKeysEn = {
  "shop": {
    "my_purchases": "My Purchases",
    "my_coupons": "My Coupons",
    "purchase_history": "Purchase History",
    "no_coupons_yet": "You have no coupons yet.",
    "buy_gifts_from_shop": "Buy gifts or discounts from the shop.",
    "go_to_shop": "Go to Shop",
    "purchase_history_empty": "Purchase history is empty."
  }
};

function mergeObj(target, source) {
  for (const key of Object.keys(source)) {
    if (typeof source[key] === 'object' && target[key]) {
      if (!target[key]) target[key] = {};
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

console.log("Translation JSON files updated successfully with shop keys.");
