const fs = require('fs');

function removeConst(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  // Remove const before Text( if there is .tr() inside it (rough regex)
  // Actually, let's just globally replace "const Text(" with "Text(" if the file is known to have tr() issues, but wait, some Text don't have tr().
  // Even better: replace `const Text('` with `Text('` for lines that we modified.
  
  // Just use regex to find `const ` in front of widgets that contain `.tr()`
  // For example: `const Text('parent_home.no_child_title'.tr()`
  content = content.replace(/const\s+Text\(([^)]*?)\.tr\(\)/g, 'Text($1.tr()');
  content = content.replace(/const\s+Text\(([\s\S]*?)\.tr\(\)/g, 'Text($1.tr()');
  
  // Some places it's `const Text('...'.tr(), ...)` -> this matches
  
  // Check if we have `const Row` or `const Column` or `const Center` that wrap `.tr()`
  // Since we know the errors are because of const, we can just replace all `const ` with empty string on the exact lines reported, OR globally for `Text(` if it contains `tr()`.
  
  // Let's replace 'const Text(' with 'Text(' globally if it's followed by anything and then '.tr()'
  content = content.replace(/const\s+Text([\s\S]*?)\.tr/g, 'Text$1.tr');
  content = content.replace(/const\s+Text\(/g, 'Text('); // Just remove all const Text( ? No, that's bad for performance. But parent_home is simple enough, wait.
  
  fs.writeFileSync(filePath, content, 'utf8');
}

// Let's just write a more precise script using the exact line numbers from the error log!
function removeConstFromLine(filePath, lines) {
  let content = fs.readFileSync(filePath, 'utf8');
  let linesArr = content.split('\n');
  for (let lineNum of lines) {
    let idx = lineNum - 1;
    if (idx >= 0 && idx < linesArr.length) {
      linesArr[idx] = linesArr[idx].replace(/const\s+/, '');
    }
  }
  fs.writeFileSync(filePath, linesArr.join('\n'), 'utf8');
}

removeConstFromLine('D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_home_screen.dart', 
  [1100, 1106, 1114, 1190, 1218, 1314, 1553, 1660, 1751, 1764, 1889, 2019, 2179, 2329, 2492, 2518]
);

removeConstFromLine('D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_location_screen.dart', 
  [626, 635, 722, 744]
);

removeConstFromLine('D:\\odat123\\Flowa\\lib\\features\\parent_mode\\presentation\\screens\\parent_wallet_screen.dart', 
  [42, 83]
);

console.log('Done fixing consts');
