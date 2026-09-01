const fs = require('fs');
const path = require('path');

const uz = JSON.parse(fs.readFileSync('assets/translations/uz.json', 'utf8'));
const ru = JSON.parse(fs.readFileSync('assets/translations/ru.json', 'utf8'));
const en = JSON.parse(fs.readFileSync('assets/translations/en.json', 'utf8'));

function getFlatKeys(obj, prefix = '') {
  let keys = {};
  for (const k of Object.keys(obj)) {
    const full = prefix ? `${prefix}.${k}` : k;
    if (typeof obj[k] === 'object' && obj[k] !== null && !Array.isArray(obj[k])) {
      Object.assign(keys, getFlatKeys(obj[k], full));
    } else {
      keys[full] = obj[k];
    }
  }
  return keys;
}

const uzFlat = getFlatKeys(uz);
const ruFlat = getFlatKeys(ru);
const enFlat = getFlatKeys(en);

// 1. Find all '...'.tr() in Dart files
function scanDir(dir, fileList = []) {
  const files = fs.readdirSync(dir);
  for (const file of files) {
    const p = path.join(dir, file);
    if (fs.statSync(p).isDirectory()) {
      if (file !== '.dart_tool' && file !== 'build') {
        scanDir(p, fileList);
      }
    } else if (file.endsWith('.dart')) {
      fileList.push(p);
    }
  }
  return fileList;
}

const dartFiles = scanDir('lib');
const usedTrKeys = new Set();
const trRegex = /['"]([a-zA-Z0-9_]+(?:\.[a-zA-Z0-9_]+)+)['"]\.tr\(/g;

for (const file of dartFiles) {
  const content = fs.readFileSync(file, 'utf8');
  let match;
  while ((match = trRegex.exec(content)) !== null) {
    usedTrKeys.add(match[1]);
  }
}

console.log('Total .tr() keys used in code:', usedTrKeys.size);

const missingInUz = [...usedTrKeys].filter(k => !uzFlat[k]);
const missingInRu = [...usedTrKeys].filter(k => !ruFlat[k]);
const missingInEn = [...usedTrKeys].filter(k => !enFlat[k]);

console.log('Used keys missing in UZ:', missingInUz.length, missingInUz);
console.log('Used keys missing in RU:', missingInRu.length, missingInRu);
console.log('Used keys missing in EN:', missingInEn.length, missingInEn);
