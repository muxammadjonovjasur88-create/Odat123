const fs = require('fs');

const uz = JSON.parse(fs.readFileSync('assets/translations/uz.json', 'utf8'));
const ru = JSON.parse(fs.readFileSync('assets/translations/ru.json', 'utf8'));
const en = JSON.parse(fs.readFileSync('assets/translations/en.json', 'utf8'));

function getKeys(obj, prefix) {
  prefix = prefix || '';
  let keys = [];
  for (const k of Object.keys(obj)) {
    const full = prefix ? prefix + '.' + k : k;
    if (typeof obj[k] === 'object' && obj[k] !== null && !Array.isArray(obj[k])) {
      keys = keys.concat(getKeys(obj[k], full));
    } else {
      keys.push(full);
    }
  }
  return keys;
}

const uzKeys = new Set(getKeys(uz));
const ruKeys = new Set(getKeys(ru));
const enKeys = new Set(getKeys(en));

const allKeys = new Set([...uzKeys, ...ruKeys, ...enKeys]);

console.log('Total unique keys:', allKeys.size);
console.log('UZ keys count:', uzKeys.size);
console.log('RU keys count:', ruKeys.size);
console.log('EN keys count:', enKeys.size);

const missingInUz = [...allKeys].filter(k => !uzKeys.has(k));
const missingInRu = [...allKeys].filter(k => !ruKeys.has(k));
const missingInEn = [...allKeys].filter(k => !enKeys.has(k));

console.log('Missing in UZ count:', missingInUz.length, missingInUz);
console.log('Missing in RU count:', missingInRu.length, missingInRu);
console.log('Missing in EN count:', missingInEn.length, missingInEn);
