const fs = require('fs');
const path = require('path');

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
let fixed = 0;

for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  let original = content;

  // Replace const Text('...'.tr() -> Text('...'.tr()
  content = content.replace(/const\s+Text\(([^)]+\.tr\([^)]*\))/g, 'Text($1');
  // Also const SizedBox or const whatever containing .tr()
  content = content.replace(/const\s+([A-Za-z0-9_]+)\(([^)]+\.tr\([^)]*\))/g, '$1($2');

  if (content !== original) {
    fs.writeFileSync(file, content, 'utf8');
    console.log(`Fixed const .tr() in ${file}`);
    fixed++;
  }
}

console.log(`Fixed ${fixed} files.`);
