const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, '..', 'lib');

function scanFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  const relPath = path.relative(path.join(__dirname, '..'), filePath).replace(/\\/g, '/');

  lines.forEach((line, idx) => {
    // Check for Text('...' or Text("..." without .tr()
    const textMatch = line.match(/(?:const\s+)?Text\s*\(\s*['"]([^'"]+)['"]/);
    if (textMatch) {
      const str = textMatch[1];
      // Ignore pure emojis or single symbols or technical keys
      if (/[a-zA-Z\u0400-\u04FF\u0100-\u017F]/.test(str) && !line.includes('.tr(') && !line.includes('.tr()') && !str.includes('$') && !/^[A-Z0-9_]+$/.test(str)) {
        console.log(`${relPath}:${idx + 1} -> "${str}"`);
      }
    }
  });
}

function walk(dir) {
  const files = fs.readdirSync(dir);
  for (const f of files) {
    const full = path.join(dir, f);
    if (fs.statSync(full).isDirectory()) {
      walk(full);
    } else if (f.endsWith('.dart')) {
      scanFile(full);
    }
  }
}

walk(libDir);
