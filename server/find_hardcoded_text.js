const fs = require('fs');
const path = require('path');

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
const hardcodedTexts = [];

// Match Text('something') or Text("something") where something has letters and doesn't end with .tr()
const textRegex = /Text\(\s*(?:const\s+)?['"]([^'"]{3,})['"](?!\.tr)/g;

for (const file of dartFiles) {
  const content = fs.readFileSync(file, 'utf8');
  const relPath = path.relative('lib', file).replace(/\\/g, '/');
  
  // Skip tests, generated, theme tokens, debug files
  if (relPath.includes('firebase_options') || relPath.includes('app_theme') || relPath.includes('app_colors')) continue;

  const lines = content.split('\n');
  lines.forEach((line, idx) => {
    // Ignore comments, logs, debugPrint, keys
    if (line.trim().startsWith('//') || line.includes('print(') || line.includes('debugPrint(') || line.includes('Key(')) return;

    let match;
    const lineRegex = /Text\(\s*(?:const\s+)?['"]([^'"\$\{\}]{3,})['"]\s*[,|\)]/g;
    while ((match = lineRegex.exec(line)) !== null) {
      const val = match[1].trim();
      // Filter out non-words like single icons, numbers, formatters
      if (/^[0-9\s:.,+\-%/()#_]+$/.test(val)) continue;
      if (val.length < 3) continue;
      if (val.startsWith('http') || val.startsWith('assets/')) continue;
      
      hardcodedTexts.push({
        file: relPath,
        line: idx + 1,
        text: val,
        raw: line.trim()
      });
    }
  });
}

console.log(`Found ${hardcodedTexts.length} hardcoded Text instances:`);

// Group by feature
const byFeature = {};
for (const item of hardcodedTexts) {
  const feature = item.file.split('/')[1] || item.file;
  if (!byFeature[feature]) byFeature[feature] = [];
  byFeature[feature].push(item);
}

for (const [feat, items] of Object.entries(byFeature)) {
  console.log(`\n=== Feature: ${feat} (${items.length} items) ===`);
  items.slice(0, 8).forEach(it => console.log(`  [${it.file}:${it.line}] "${it.text}"`));
  if (items.length > 8) console.log(`  ... and ${items.length - 8} more`);
}
